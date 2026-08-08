// electron-builder afterPack hook: reliably applies the custom icon to the
// unpacked app exe. electron-builder's built-in icon step silently fails on
// some setups, leaving the default Electron atom icon; rcedit always works.
const path = require('path');
const { execFileSync } = require('child_process');

exports.default = async function afterPack(context) {
  const { appOutDir, packager } = context;
  const productName = packager.appInfo.productFilename; // e.g. "Todo App"
  const exePath = path.join(appOutDir, `${productName}.exe`);
  const iconPath = path.join(packager.projectDir, 'resources', 'icons', 'icon.ico');

  // Locate the rcedit binary bundled with the project's rcedit package.
  const rceditCandidates = [
    path.join(packager.projectDir, 'node_modules', 'rcedit', 'bin', process.arch === 'x64' ? 'rcedit-x64.exe' : 'rcedit-ia32.exe'),
    path.join(packager.projectDir, 'node_modules', 'rcedit', 'bin', 'rcedit.exe'),
  ];
  const rcedit = rceditCandidates.find(p => require('fs').existsSync(p));
  if (!rcedit) {
    console.warn('[apply-icon] rcedit not found, skipping icon patch');
    return;
  }

  try {
    execFileSync(rcedit, [exePath, '--set-icon', iconPath], { stdio: 'pipe' });
    console.log(`[apply-icon] ✓ icon applied to ${path.basename(exePath)}`);
  } catch (e) {
    console.error('[apply-icon] failed to patch icon:', e.message);
  }
};
