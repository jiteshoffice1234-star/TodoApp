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
});
