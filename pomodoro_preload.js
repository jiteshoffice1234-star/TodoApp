const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('pomodoroApi', {
  onState: (callback) => {
    ipcRenderer.on('pomodoro:set-state', (_, state) => callback(state));
  },
  onTheme: (callback) => {
    ipcRenderer.on('pomodoro:set-theme', (_, theme) => callback(theme));
  },
  closePomodoro: () => {
    ipcRenderer.invoke('pomodoro:close');
  },
  sendCommand: (command) => {
    ipcRenderer.invoke('pomodoro:command', command);
  },
  getSettings: () => {
    return ipcRenderer.invoke('pomodoro:get-settings');
  },
  saveSettings: (settings) => {
    ipcRenderer.invoke('pomodoro:save-settings', settings);
  },
});
