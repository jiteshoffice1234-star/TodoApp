// clean_features.js - Remove orphaned timeline, dashboard, mood, focus, subtask code
const fs = require('fs');
const path = require('path');

const appJsPath = path.join(__dirname, 'src', 'app.js');
let lines = fs.readFileSync(appJsPath, 'utf-8').split('\n');

console.log('Total lines:', lines.length);

// Find and remove orphaned getTimelineEvents body (lines 637 to line ending with "return events;")
// Find the start: "// ===== DASHBOARD =====" at line ~637
let startIdx = -1;
let endIdx = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].trim() === '// ===== DASHBOARD =====' && startIdx === -1) {
    startIdx = i;
  }
}

// Now find the SECOND "// ===== DASHBOARD =====" (the real one with computeWeeklyStats)
let secondDashboard = -1;
let firstFound = false;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].trim() === '// ===== DASHBOARD =====') {
    if (!firstFound) { firstFound = true; continue; }
    secondDashboard = i;
    break;
  }
}

// Remove from first DASHBOARD comment to just before the second DASHBOARD comment
if (startIdx >= 0 && secondDashboard >= 0) {
  console.log(`Removing orphaned timeline/dashboard code: lines ${startIdx + 1} to ${secondDashboard}`);
  lines.splice(startIdx, secondDashboard - startIdx);
}

// Now find the REAL DASHBOARD section (computeWeeklyStats through renderDashboard)
let dashStart = -1;
let dashEnd = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].trim() === '// ===== DASHBOARD =====' && dashStart === -1) {
    dashStart = i;
  }
  if (dashStart >= 0 && lines[i].trim() === '// ===== MOOD TRACKER =====') {
    dashEnd = i;
    break;
  }
}

// Remove dashboard section
if (dashStart >= 0 && dashEnd >= 0) {
  console.log(`Removing DASHBOARD: lines ${dashStart + 1} to ${dashEnd}`);
  lines.splice(dashStart, dashEnd - dashStart);
}

// Now find and remove MOOD TRACKER section
let moodStart = -1;
let moodEnd = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].trim() === '// ===== MOOD TRACKER =====') {
    moodStart = i;
  }
  if (moodStart >= 0 && lines[i].trim() === '// --- Calendar ---') {
    moodEnd = i;
    break;
  }
}
if (moodStart >= 0 && moodEnd >= 0) {
  console.log(`Removing MOOD TRACKER: lines ${moodStart + 1} to ${moodEnd}`);
  lines.splice(moodStart, moodEnd - moodStart);
}

// Find and remove Focus Mode section (saveFocusSession through selectFocusTodo)
let focusStart = -1;
let focusEnd = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('// --- Focus Mode ---')) {
    focusStart = i;
  }
  if (focusStart >= 0 && lines[i].includes('// --- Pomodoro ---')) {
    focusEnd = i;
    break;
  }
}
if (focusStart >= 0 && focusEnd >= 0) {
  console.log(`Removing FOCUS MODE: lines ${focusStart + 1} to ${focusEnd}`);
  lines.splice(focusStart, focusEnd - focusStart);
}

// Find and remove renderPomoTodoSelector and renderFocusStats
let ptsStart = -1;
let ptsEnd = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('function renderPomoTodoSelector()')) {
    ptsStart = i;
  }
  if (ptsStart >= 0 && lines[i].includes('// --- Subtasks ---')) {
    ptsEnd = i;
    break;
  }
}
if (ptsStart >= 0 && ptsEnd >= 0) {
  console.log(`Removing POMO_TODO_SELECTOR + FOCUS_STATS: lines ${ptsStart + 1} to ${ptsEnd}`);
  lines.splice(ptsStart, ptsEnd - ptsStart);
}

// Find and remove Subtasks section
let subStart = -1;
let subEnd = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('// --- Subtasks ---')) {
    subStart = i;
  }
  if (subStart >= 0 && lines[i].includes('// --- Markdown helpers ---')) {
    subEnd = i;
    break;
  }
}
if (subStart >= 0 && subEnd >= 0) {
  console.log(`Removing SUBTASKS: lines ${subStart + 1} to ${subEnd}`);
  lines.splice(subStart, subEnd - subStart);
}

// Clean up: remove renderPomoTodoSelector and renderFocusStats calls from openPomodoro
let code = lines.join('\n');
code = code.replace(/  renderPomoSessions\(\);\n  renderPomoTodoSelector\(\);\n  renderFocusStats\(\);\n  updatePomoDisplay\(\);/, '  renderPomoSessions();\n  updatePomoDisplay();');

// Remove saveFocusSession call from pomoComplete
code = code.replace(/    \/\/ Save focus session\n    if \(focusTodoId\) \{\n      saveFocusSession\(focusTodoId, Math.round\(pomoTotal \/ 60\)\);\n    \}\n/, '');

// Remove renderFocusStats call from pomoComplete
code = code.replace(/  renderPomoSessions\(\);\n  updatePomoDisplay\(\);\n  renderFocusStats\(\);\n  window\.api\.sendNotification/, '  renderPomoSessions();\n  updatePomoDisplay();\n  window.api.sendNotification');

// Remove focusTodoId variable
code = code.replace(/let focusTodoId = null;\n/g, '');

// Clean up recurring/subtask in renderTodos
code = code.replace(/    \/\/ Recurring badge\n    let recurHtml = '';\n    if \(todo\.recurring && todo\.recurring\.type !== 'none'\) \{\n      recurHtml = `<span class="todo-recur-badge">🔄 \$\{todo\.recurring\.type\}<\/span>`;\n    \}\n/g, '');
code = code.replace(/    \/\/ Subtasks\n    let subtaskHtml = '';\n    if \(todo\.subtasks && todo\.subtasks\.length > 0\) \{[\s\S]*?<\/div>`;\n    \}\n/g, '');

// Remove subtask/recurring references from renderTodos output
code = code.replace(/          \$\{recurHtml\}\$\{remindHtml\}\n/, '');

// Remove subtaskHtml from renderTodos output
code = code.replace(/        \$\{tagRow\}\$\{desc\}\$\{dueHtml\}\$\{subtaskHtml\}\n/, '        ${tagRow}${desc}${dueHtml}\n');

// Remove openAmbientSounds reference
code = code.replace(/      openAmbientSounds\(\);\n/g, '');

// Clean up multiple blank lines
code = code.replace(/\n{4,}/g, '\n\n\n');

fs.writeFileSync(appJsPath, code, 'utf-8');
console.log('Done! Final size:', code.length, 'chars');
