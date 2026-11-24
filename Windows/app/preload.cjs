const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('desktopGame', {
  fullscreen: enabled => ipcRenderer.send('game:fullscreen', enabled),
  size: mode => ipcRenderer.send('game:size', mode),
  quit: () => ipcRenderer.send('game:quit'),
  onFullscreen: callback => ipcRenderer.on('game:fullscreen-change', (_, enabled) => callback(enabled)),
});
