const { app, BrowserWindow, ipcMain, protocol, Menu } = require('electron');
const fs = require('node:fs/promises');
const path = require('node:path');

protocol.registerSchemesAsPrivileged([{
  scheme: 'dtw', privileges: { standard: true, secure: true, supportFetchAPI: true },
}]);

const origin = 'dtw://game';
const allowedFiles = new Set(['index.html', 'style.css', 'ui.mjs', 'model.mjs', 'i18n.mjs', 'sound.mjs']);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json', '.png': 'image/png',
  '.wav': 'audio/wav', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
const dimensions = [[1280, 720], [1440, 900], [1600, 900]];

app.setAppUserModelId('com.doesthiswork.game');
app.whenReady().then(() => {
  protocol.handle('dtw', async request => {
    const url = new URL(request.url);
    if (request.method !== 'GET' || url.hostname !== 'game' || url.username || url.password || url.port) {
      return new Response(null, { status: 404 });
    }
    let asset;
    try { asset = decodeURIComponent(url.pathname).slice(1); }
    catch { return new Response(null, { status: 400 }); }
    if (!(allowedFiles.has(asset) || /^assets\/(?:[\w.-]+\/)*[\w.-]+$/.test(asset)) ||
      asset.split('/').some(segment => segment === '..' || segment === '.')) {
      return new Response(null, { status: 404 });
    }
    try {
      const data = await fs.readFile(path.join(__dirname, asset));
      return new Response(data, { headers: { 'Content-Type': types[path.extname(asset)] ?? 'application/octet-stream' } });
    } catch {
      return new Response(null, { status: 404 });
    }
  });

  const window = new BrowserWindow({
    title: 'Does This Work?', width: 1280, height: 760, minWidth: 1050, minHeight: 665,
    backgroundColor: '#f7efe3', icon: path.join(__dirname, 'assets', 'art', 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), sandbox: true,
      contextIsolation: true, nodeIntegration: false, spellcheck: false },
  });
  Menu.setApplicationMenu(null);
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', event => event.preventDefault());
  window.webContents.session.setPermissionRequestHandler((_, __, callback) => callback(false));
  const trusted = event => event.sender === window.webContents && event.senderFrame?.url === origin + '/index.html';

  ipcMain.on('game:fullscreen', (event, enabled) => {
    if (trusted(event) && typeof enabled === 'boolean') window.setFullScreen(enabled);
  });
  ipcMain.on('game:size', (event, mode) => {
    if (trusted(event) && Number.isInteger(mode) && dimensions[mode] && !window.isFullScreen()) {
      window.setContentSize(...dimensions[mode]);
      window.center();
    }
  });
  ipcMain.on('game:quit', event => { if (trusted(event)) window.close(); });
  window.on('enter-full-screen', () => window.webContents.send('game:fullscreen-change', true));
  window.on('leave-full-screen', () => window.webContents.send('game:fullscreen-change', false));
  window.loadURL(origin + '/index.html');
});

app.on('window-all-closed', () => app.quit());
