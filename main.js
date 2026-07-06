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
  return { todos: [], tags: [], nextTodoId: 1, nextTagId: 1, deletedTodos: [] };
}

function saveData(data) {
  try {
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error saving data:', e);
  }
}

function checkDueDates(data) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayStr = today.toISOString().split('T')[0];
  let notifications = [];

  for (const todo of data.todos) {
    if (todo.completed || !todo.dueDate) continue;
    if (todo.dueDate === todayStr) {
      notifications.push(`📅 "${todo.title}" is due today!`);
    } else if (todo.dueDate < todayStr) {
      const overdue = Math.floor((today.getTime() - new Date(todo.dueDate).getTime()) / 86400000);
      notifications.push(`⚠️ "${todo.title}" is ${overdue} day${overdue > 1 ? 's' : ''} overdue!`);
    }
  }
  return notifications;
}

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 700,
    minWidth: 500,
    minHeight: 400,
    frame: true,
    title: 'Todo App',
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
    const notices = checkDueDates(data);
    for (const msg of notices) {
      new Notification({ title: 'Todo App', body: msg }).show();
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
  if (process.platform !== 'darwin') app.quit();
});

ipcMain.handle('get-data', () => loadData());
ipcMain.handle('save-data', (_, data) => { saveData(data); return true; });

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
