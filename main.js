const { app, BrowserWindow, ipcMain, dialog, Notification } = require('electron');
const path = require('path');
const fs = require('fs');

const DATA_DIR = app.getPath('userData');
const DATA_FILE = path.join(DATA_DIR, 'todos.json');

function loadData() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      return JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'));
    }
  } catch (e) {
    console.error('Error loading data:', e);
  }
  return { todos: [], tags: [], nextTodoId: 1, nextTagId: 1, deletedTodos: [], settings: {} };
}

function saveData(data) {
  try {
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error saving data:', e);
  }
}
function saveSetting(key, value) {
  const d = loadData();
  if (!d.settings) d.settings = {};
  d.settings[key] = value;
  saveData(d);
}
function getSetting(key) {
  const d = loadData();
  return d.settings ? d.settings[key] : undefined;
}

// Process recurring todos
let mainWindow;
let pipWindow = null;
let cachedPipHtml = '';
let pomodoroWindow = null;

// Pomodoro state (managed in main process so it survives window focus changes)
let pomoState = {
  remainingSeconds: 25 * 60,
  totalSeconds: 25 * 60,
  isRunning: false,
  isBreak: false,
  isStopped: true,
  sessionCount: 0,
  currentTodoId: null,
  todoTitle: null,
};
let pomoInterval = null;

function startPomoTimer() {
  if (pomoInterval) clearInterval(pomoInterval);
  pomoState.isRunning = true;
  pomoInterval = setInterval(() => {
    if (pomoState.remainingSeconds > 0) {
      pomoState.remainingSeconds--;
      sendPomodoroState();
    } else {
      pomoComplete();
    }
  }, 1000);
}

function pomoComplete() {
  if (pomoInterval) clearInterval(pomoInterval);
  pomoState.isRunning = false;
  pomoState.isStopped = true; // Mark as stopped so picker shows again
  saveSetting('pomodoroSavedDuration', null);

  if (!pomoState.isBreak) {
    pomoState.sessionCount++;
    // If skip breaks is enabled, go directly to next focus session
    if (pomoState.skipBreaks) {
      const mins = Math.round(pomoState.totalSeconds / 60);
      pomoState.isBreak = false;
      pomoState.remainingSeconds = mins * 60;
      pomoState.totalSeconds = mins * 60;
    } else {
      // Switch to break
      if (pomoState.sessionCount % 4 === 0) {
        pomoState.isBreak = true;
        pomoState.remainingSeconds = 15 * 60;
        pomoState.totalSeconds = 15 * 60;
      } else {
        pomoState.isBreak = true;
        pomoState.remainingSeconds = 5 * 60;
        pomoState.totalSeconds = 5 * 60;
      }
    }
  } else {
    // Switch back to work (same duration as before)
    const mins = Math.round(pomoState.totalSeconds / 60);
    pomoState.isBreak = false;
    pomoState.remainingSeconds = mins * 60;
    pomoState.totalSeconds = mins * 60;
  }

  sendPomodoroState();
  sendPomodoroNotification();
}

function sendPomodoroNotification() {
  const title = 'Pomodoro';
  const body = pomoState.isBreak ? 'Break time! 🍅' : 'Focus time! 🎯';
  try { new Notification({ title, body }).show(); } catch(e) {}
}

function sendPomodoroState() {
  if (pomodoroWindow && !pomodoroWindow.isDestroyed()) {
    try { pomodoroWindow.webContents.send('pomodoro:set-state', pomoState); } catch(e) {}
  }
  // Also sync to main window
  if (mainWindow && !mainWindow.isDestroyed()) {
    try { mainWindow.webContents.send('pomodoro:sync', pomoState); } catch(e) {}
  }
}

function openPipWindow() {
  if (pipWindow && !pipWindow.isDestroyed()) { pipWindow.focus(); return true; }
  pipWindow = new BrowserWindow({
    width: 500, height: 44, minWidth: 150, minHeight: 30, resizable: true, frame: false, alwaysOnTop: true,
    skipTaskbar: true, backgroundColor: '#1a1a1a',
    webPreferences: {
      preload: path.join(__dirname, 'pip_preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  pipWindow.loadFile(path.join(__dirname, 'src', 'pip.html'));
  pipWindow.setAlwaysOnTop(true, 'screen-saver');

  // Always re-send the latest cached content once the page finishes loading,
  // so a freshly created PiP window never starts blank.
  pipWindow.webContents.once('did-finish-load', () => {
    if (pipWindow && !pipWindow.isDestroyed() && cachedPipHtml !== '') {
      try { pipWindow.webContents.send('pip:set-content', cachedPipHtml); } catch(e) {}
    }
  });

  // Clean up pip state once page is ready; send any cached content
  pipWindow.on('closed', () => {
    pipWindow = null;
    saveSetting('pipActive', false);
    // Notify main window so it knows PiP closed
    if (mainWindow && !mainWindow.isDestroyed()) {
      try { mainWindow.webContents.send('pip:closed-by-pip'); } catch(e) {}
    }
  });
  return true;
}

// Queue messages sent while PiP is still loading, then flush on load
let pipPendingMessages = [];
let pipLoadHandlerAttached = false;

function sendToPip(channel, ...args) {
  if (!pipWindow || pipWindow.isDestroyed()) return;
  try {
    if (pipWindow.webContents.isLoading() || pipWindow.webContents.isWaitingForResponse()) {
      pipPendingMessages.push({ channel, args });
      if (!pipLoadHandlerAttached) {
        pipLoadHandlerAttached = true;
        pipWindow.webContents.once('did-finish-load', () => {
          pipLoadHandlerAttached = false;
          const msgs = pipPendingMessages.slice();
          pipPendingMessages = [];
          for (const m of msgs) {
            if (pipWindow && !pipWindow.isDestroyed()) {
              try { pipWindow.webContents.send(m.channel, ...m.args); } catch(e) {}
            }
          }
        });
      }
    } else {
      pipWindow.webContents.send(channel, ...args);
    }
  } catch(e) {
    // If webContents is not available, queue for retry
    pipPendingMessages.push({ channel, args });
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 750,
    minWidth: 500,
    minHeight: 400,
    frame: true,
    title: 'Todo App',
    icon: path.join(__dirname, 'resources', 'icons', 'icon.png'),
    backgroundColor: '#1e1e1e',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));
  mainWindow.setMenuBarVisibility(false);

  mainWindow.once('ready-to-show', () => {
    // Defer PiP and Pomodoro auto-restore so the main window paints first
    setTimeout(() => {
      if (mainWindow.isDestroyed()) return;
      if (getSetting('pipActive') && (!pipWindow || pipWindow.isDestroyed())) {
        openPipWindow();
      }
      if (getSetting('pomodoroActive') && (!pomodoroWindow || pomodoroWindow.isDestroyed())) {
        openPomodoroWindow();
      }
    }, 500);
  });

  mainWindow.on('close', (e) => {
    if (pipWindow && !pipWindow.isDestroyed() || pomodoroWindow && !pomodoroWindow.isDestroyed()) {
      e.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('show', () => {
    if (pipWindow && !pipWindow.isDestroyed()) {
      mainWindow.webContents.send('pip:sync');
    }
    if (pomodoroWindow && !pomodoroWindow.isDestroyed()) {
      mainWindow.webContents.send('pomodoro:sync', pomoState);
    }
  });
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  // If PiP or Pomodoro is still open, don't quit
  if (pipWindow && !pipWindow.isDestroyed()) return;
  if (pomodoroWindow && !pomodoroWindow.isDestroyed()) return;
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers
ipcMain.handle('get-data', () => loadData());
ipcMain.handle('save-data', (_, data) => {
  if (!data || typeof data !== 'object') return false;
  if (!Array.isArray(data.todos) || !Array.isArray(data.tags)) return false;
  if (typeof data.nextTodoId !== 'number' || typeof data.nextTagId !== 'number') return false;
  saveData(data); return true;
});

ipcMain.handle('confirm-delete', (_, message) => {
  return dialog.showMessageBoxSync(mainWindow, {
    type: 'question',
    buttons: ['Cancel', 'Delete'],
    defaultId: 1,
    title: 'Confirm',
    message: message,
  });
});

ipcMain.handle('send-notification', (_, title, body) => {
  new Notification({ title, body }).show();
});

ipcMain.handle('get-data-path', () => DATA_DIR);

// PiP window
ipcMain.handle('pip:open', () => {
  const ok = openPipWindow();
  if (ok) saveSetting('pipActive', true);
  return ok;
});

ipcMain.handle('pip:close', () => {
  if (pipWindow && !pipWindow.isDestroyed()) { pipWindow.close(); pipWindow = null; }
  saveSetting('pipActive', false);
  // Notify main window so it can update its PiP state
  if (mainWindow && !mainWindow.isDestroyed()) {
    try { mainWindow.webContents.send('pip:closed-by-pip'); } catch(e) {}
  }
  return true;
});

ipcMain.handle('pip:update', (_, html) => {
  cachedPipHtml = html;
  sendToPip('pip:set-content', html);
  return true;
});

ipcMain.handle('pip:theme', (_, theme) => {
  sendToPip('pip:set-theme', theme);
  return true;
});

ipcMain.handle('pip:state', () => getSetting('pipActive'));

ipcMain.handle('pip:drag-move', (_, x, y) => {
  if (pipWindow && !pipWindow.isDestroyed()) pipWindow.setPosition(Math.round(x), Math.round(y));
  return true;
});

// --- Pomodoro floating window ---
function openPomodoroWindow() {
  if (pomodoroWindow && !pomodoroWindow.isDestroyed()) { pomodoroWindow.focus(); return true; }
  pomodoroWindow = new BrowserWindow({
    width: 320, height: 320, minWidth: 280, minHeight: 280,
    resizable: false, frame: false, alwaysOnTop: true,
    skipTaskbar: true, backgroundColor: '#00000000', transparent: true,
    webPreferences: {
      preload: path.join(__dirname, 'pomodoro_preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  pomodoroWindow.loadFile(path.join(__dirname, 'src', 'pomodoro.html'));
  pomodoroWindow.setAlwaysOnTop(true, 'screen-saver');

  pomodoroWindow.webContents.once('did-finish-load', () => {
    if (pomodoroWindow && !pomodoroWindow.isDestroyed()) {
      try {
        pomodoroWindow.webContents.send('pomodoro:set-state', pomoState);
        pomodoroWindow.webContents.send('pomodoro:set-theme', currentTheme);
      } catch(e) {}
    }
  });

  pomodoroWindow.on('closed', () => {
    pomodoroWindow = null;
    saveSetting('pomodoroActive', false);
    if (mainWindow && !mainWindow.isDestroyed()) {
      try { mainWindow.webContents.send('pomodoro:closed-by-window'); } catch(e) {}
    }
  });
  return true;
}

let currentTheme = 'light';

ipcMain.handle('pomodoro:open', () => {
  const ok = openPomodoroWindow();
  if (ok) saveSetting('pomodoroActive', true);
  return ok;
});

ipcMain.handle('pomodoro:close', () => {
  if (pomodoroWindow && !pomodoroWindow.isDestroyed()) { pomodoroWindow.close(); pomodoroWindow = null; }
  saveSetting('pomodoroActive', false);
  if (mainWindow && !mainWindow.isDestroyed()) {
    try { mainWindow.webContents.send('pomodoro:closed-by-window'); } catch(e) {}
  }
  return true;
});

ipcMain.handle('pomodoro:command', (_, command) => {
  // Handle 'start:X' or 'start:X:Y' commands for custom durations with skip breaks flag
  if (command.startsWith('start:')) {
    const parts = command.split(':');
    const mins = parseInt(parts[1]) || 25;
    const skipBreaks = parts[2] === '1';
    if (pomoInterval) clearInterval(pomoInterval);
    pomoState.isBreak = false;
    pomoState.isStopped = false;
    pomoState.remainingSeconds = mins * 60;
    pomoState.totalSeconds = mins * 60;
    pomoState.skipBreaks = skipBreaks;
    saveSetting('pomodoroSavedDuration', mins);
    startPomoTimer();
    sendPomodoroState();
    return true;
  }

  switch (command) {
    case 'toggle':
      if (pomoState.isRunning) {
        if (pomoInterval) clearInterval(pomoInterval);
        pomoState.isRunning = false;
      } else {
        pomoState.isStopped = false;
        startPomoTimer();
      }
      break;
    case 'reset':
      if (pomoInterval) clearInterval(pomoInterval);
      pomoState.isRunning = false;
      pomoState.isBreak = false;
      pomoState.remainingSeconds = pomoState.totalSeconds;
      break;
    case 'stop':
      if (pomoInterval) clearInterval(pomoInterval);
      pomoState.isRunning = false;
      pomoState.isStopped = true;
      pomoState.isBreak = false;
      pomoState.remainingSeconds = 25 * 60;
      pomoState.totalSeconds = 25 * 60;
      saveSetting('pomodoroSavedDuration', null);
      break;
    case 'skip':
      if (pomoInterval) clearInterval(pomoInterval);
      pomoState.isRunning = false;
      pomoComplete();
      break;
  }
  sendPomodoroState();
  return true;
});

ipcMain.handle('pomodoro:state', () => {
  return { active: getSetting('pomodoroActive'), ...pomoState };
});

ipcMain.handle('pomodoro:get-settings', () => {
  const settings = getSetting('pomodoroSettings') || {};
  settings.savedDuration = getSetting('pomodoroSavedDuration');
  settings.isStopped = pomoState.isStopped;
  return settings;
});

ipcMain.handle('pomodoro:save-settings', (_, settings) => {
  saveSetting('pomodoroSettings', settings);
  return true;
});

ipcMain.handle('pomodoro:resize', (_, width, height) => {
  if (pomodoroWindow && !pomodoroWindow.isDestroyed()) {
    pomodoroWindow.setSize(width, height);
  }
  return true;
});

ipcMain.handle('pomodoro:set-todo', (_, todoId, title) => {
  pomoState.currentTodoId = todoId;
  pomoState.todoTitle = title;
  sendPomodoroState();
  return true;
});

ipcMain.handle('pomodoro:sync-state', () => pomoState);



