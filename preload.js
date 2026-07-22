const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getData: () => ipcRenderer.invoke('get-data'),
  saveData: (data) => ipcRenderer.invoke('save-data', data),
  confirmDelete: (message) => ipcRenderer.invoke('confirm-delete', message),
  sendNotification: (title, body) => ipcRenderer.invoke('send-notification', title, body),
  getDataPath: () => ipcRenderer.invoke('get-data-path'),
});
