const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('pipApi', {
  onContent: (callback) => { ipcRenderer.on('pip:set-content', (_, html) => callback(html)); },
  onTheme: (callback) => { ipcRenderer.on('pip:set-theme', (_, theme) => callback(theme)); },
});
