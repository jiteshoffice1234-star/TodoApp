const fs = require('fs');
const cssPath = 'C:\\Users\\Dell\\Desktop\\ANDRIUD\\TodoApp\\src\\styles.css';
let css = fs.readFileSync(cssPath, 'utf8');

// Remove multi-select bar section
css = css.replace(/\/\* ===== MULTI-SELECT BAR ===== \*\/[\s\S]*?(?=\/\* =====)/, '');

// Remove todo-card.selected (but keep tag-option.selected and cal-cell.selected)
css = css.replace(/\.todo-card\.selected\s*\{[^}]*\}/g, '');

// Remove todo-select-check
css = css.replace(/\.todo-select-check\s*\{[^}]*\}/g, '');

fs.writeFileSync(cssPath, css);
console.log('Multi-select CSS removed!');
