const { app, BrowserWindow, ipcMain, dialog, Notification } = require('electron');
const path = require('path');
const fs = require('fs');
const { autoUpdater } = require('electron-updater');

// --- Auto Updater Configuration ---
// Provider config is read from package.json's "build.publish" section
autoUpdater.autoDownload = false;
autoUpdater.autoInstallOnAppQuit = true;

let updateState = {
  status: 'idle', // idle | checking | available | not-available | downloading | downloaded | error
  info: null,
  progress: null,
  error: null,
};
let _updateCheckInProgress = false; // Prevents concurrent checkForUpdates() calls

function sendUpdateEvent(channel, data) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    try { mainWindow.webContents.send('update:' + channel, data); } catch(e) {}
  }
}

// Auto-updater events
autoUpdater.on('checking-for-update', () => {
  updateState = { status: 'checking', info: null, progress: null, error: null };
  sendUpdateEvent('status', updateState);
});

autoUpdater.on('update-available', (info) => {
  updateState = { status: 'available', info, progress: null, error: null };
  sendUpdateEvent('status', updateState);
});

autoUpdater.on('update-not-available', (info) => {
  updateState = { status: 'not-available', info, progress: null, error: null };
  sendUpdateEvent('status', updateState);
});

autoUpdater.on('download-progress', (progress) => {
  updateState = { ...updateState, status: 'downloading', progress };
  sendUpdateEvent('progress', progress);
});

autoUpdater.on('update-downloaded', (info) => {
  updateState = { status: 'downloaded', info, progress: null, error: null };
  sendUpdateEvent('status', updateState);
});

autoUpdater.on('error', (err) => {
  updateState = { status: 'error', info: null, progress: null, error: err.message || String(err) };
  sendUpdateEvent('status', updateState);
});

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
function processRecurring(data) {
  const today = new Date().toISOString().split('T')[0];
  const newTodos = [];

  for (const todo of data.todos) {
    if (!todo.completed || !todo.recurring || todo.recurring.type === 'none') continue;

    const lastCompleted = todo.updatedAt || Date.now();
    const nextDate = getNextRecurringDate(todo.recurring, todo.dueDate || today);

    if (nextDate && !data.todos.some(t => t.recurringParentId === todo.id && t.dueDate === nextDate)) {
      newTodos.push({
        id: data.nextTodoId++,
        title: todo.title,
        description: todo.description,
        completed: false,
        priority: todo.priority,
        dueDate: nextDate,
        tagIds: [...(todo.tagIds || [])],
        pinned: false,
        subtasks: (todo.subtasks || []).map(s => ({ ...s, done: false })),
        recurring: { ...todo.recurring },
        recurringParentId: todo.id,
        reminderAt: null,
        reminderFired: false,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
    }
  }
  data.todos.push(...newTodos);
  return newTodos.length;
}

function getNextRecurringDate(recurring, baseDate) {
  if (!recurring || recurring.type === 'none') return null;
  const base = new Date(baseDate + 'T00:00:00');
  const interval = recurring.interval || 1;

  switch (recurring.type) {
    case 'daily':
      base.setDate(base.getDate() + interval);
      break;
    case 'weekly':
      base.setDate(base.getDate() + 7 * interval);
      break;
    case 'monthly':
      base.setMonth(base.getMonth() + interval);
      break;
    case 'yearly':
      base.setFullYear(base.getFullYear() + interval);
      break;
    default:
      return null;
  }

  if (recurring.endDate && base > new Date(recurring.endDate)) return null;
  return base.toISOString().split('T')[0];
}

let mainWindow;
let pipWindow = null;
let cachedPipHtml = '';

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
    const data = loadData();
    processRecurring(data);
    saveData(data);
    // Notifications are handled by the renderer process (app.js) to avoid duplicates
    // Defer PiP auto-restore so the main window paints first (faster morning startup)
    setTimeout(() => {
      if (mainWindow.isDestroyed()) return; // Don't create PiP if main window already closed
      if (getSetting('pipActive') && (!pipWindow || pipWindow.isDestroyed())) {
        openPipWindow();
      }
    }, 500);
  });

  mainWindow.on('close', (e) => {
    if (pipWindow && !pipWindow.isDestroyed()) {
      e.preventDefault();
      // Keep PiP alive but hide the main window to system tray
      mainWindow.hide();
    }
  });

  mainWindow.on('show', () => {
    if (pipWindow && !pipWindow.isDestroyed()) {
      mainWindow.webContents.send('pip:sync');
    }
  });
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
  // Deferred auto-update check — let the app paint first
  setTimeout(() => {
    if (_updateCheckInProgress) return; // Don't stack with user-initiated check
    try { autoUpdater.checkForUpdates(); } catch(e) { console.error('Update check failed:', e); }
  }, 5000);
});

app.on('window-all-closed', () => {
  // If PiP is still open, don't quit — wait for it to close
  if (pipWindow && !pipWindow.isDestroyed()) return;
  if (process.platform !== 'darwin') {
    // Final safety net: force quit if main window hidden + PiP closed
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


// --- Update IPC handlers ---
ipcMain.handle('update:check', async () => {
  if (_updateCheckInProgress) return false; // Already checking — don't stack
  _updateCheckInProgress = true;
  try {
    await autoUpdater.checkForUpdates();
    return true;
  } catch(e) {
    return false;
  } finally {
    _updateCheckInProgress = false;
  }
});

ipcMain.handle('update:get-status', () => updateState);

ipcMain.handle('update:start-download', () => {
  if (updateState.status === 'available') {
    autoUpdater.autoDownload = true;
    autoUpdater.downloadUpdate();
    return true;
  }
  return false;
});

ipcMain.handle('update:quit-and-install', () => {
  if (updateState.status === 'downloaded') {
    autoUpdater.autoInstallOnAppQuit = true;
    setImmediate(() => autoUpdater.quitAndInstall());
    return true;
  }
  return false;
});
