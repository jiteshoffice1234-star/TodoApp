const fs = require('fs');
const cssPath = 'C:\\Users\\Dell\\Desktop\\ANDRIUD\\TodoApp\\src\\styles.css';
let css = fs.readFileSync(cssPath, 'utf8');

// Remove all pomodoro-related CSS
const pomoCssStart = css.indexOf('/* ===== POMODORO ===== */');
const pomoCssEnd = css.indexOf('/* ===== TAGS MANAGEMENT ===== */');

if (pomoCssStart !== -1 && pomoCssEnd !== -1) {
  css = css.substring(0, pomoCssStart) + css.substring(pomoCssEnd);
}

// Also remove any standalone pomo classes
css = css.replace(/\.pomodoro-content\s*\{[^}]*\}/g, '');

fs.writeFileSync(cssPath, css);
console.log('Pomodoro CSS removed!');
