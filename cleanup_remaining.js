const fs = require('fs');
const path = 'C:\\Users\\Dell\\Desktop\\ANDRIUD\\TodoApp\\src\\app.js';
let code = fs.readFileSync(path, 'utf8');

// Remove window assignments for removed features
code = code.replace(/window\.initDragDrop = initDragDrop;\r?\n/g, '');
code = code.replace(/window\.openSettings = openSettings;.*?window\.closeSettings = closeSettings;\r?\n/g, '');
code = code.replace(/window\.manualCheckUpdates = manualCheckUpdates;\r?\n/g, '');
code = code.replace(/window\.startUpdateDownload = startUpdateDownload;\r?\n/g, '');
code = code.replace(/window\.quitAndInstall = quitAndInstall;\r?\n/g, '');

// Remove the entire Settings & Updates section
const settingsStart = code.indexOf('// --- Settings & Updates ---');
if (settingsStart !== -1) {
  code = code.substring(0, settingsStart) + 'init();\n';
}

fs.writeFileSync(path, code);
console.log('Cleaned up remaining code!');
