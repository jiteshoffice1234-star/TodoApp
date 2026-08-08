const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getData: () => ipcRenderer.invoke('get-data'),
  saveData: (data) => ipcRenderer.invoke('save-data', data),
  confirmDelete: (message) => ipcRenderer.invoke('confirm-delete', message),
  sendNotification: (title, body) => ipcRenderer.invoke('send-notification', title, body),
  getDataPath: () => ipcRenderer.invoke('get-data-path'),
  openPip: () => ipcRenderer.invoke('pip:open'),
  closePip: () => ipcRenderer.invoke('pip:close'),
  updatePip: (html) => ipcRenderer.invoke('pip:update', html),
  updatePipTheme: (theme) => ipcRenderer.invoke('pip:theme', theme),
  getPipState: () => ipcRenderer.invoke('pip:state'),
  onPipSync: (callback) => ipcRenderer.on('pip:sync', callback),
  onPipClosedByPip: (callback) => ipcRenderer.on('pip:closed-by-pip', callback),
  // Pomodoro floating window
  openPomodoro: () => ipcRenderer.invoke('pomodoro:open'),
  closePomodoro: () => ipcRenderer.invoke('pomodoro:close'),
  getPomodoroState: () => ipcRenderer.invoke('pomodoro:state'),
  onPomodoroSync: (callback) => ipcRenderer.on('pomodoro:sync', (_, state) => callback(state)),
  onPomodoroClosedByWindow: (callback) => ipcRenderer.on('pomodoro:closed-by-window', callback),
  setPomodoroTodo: (todoId, title) => ipcRenderer.invoke('pomodoro:set-todo', todoId, title),
});
