import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(__dirname, 'src');
const PORT = 3000;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
};

// Browser shim for Electron preload APIs – injects mock implementations
// using localStorage so the app actually renders and persists data.
const PRELOAD_SHIM = `
<script>
// ========== Electron API Browser Shim ==========
(function() {
  const STORAGE_KEY = 'todoapp_data';
  const sampleTodos = [
    { id: 1, title: 'Welcome to Todo App!', description: 'This is a **demo** running in your browser.\\n\\nFeatures available:\\n- _Markdown_ descriptions\\n- __Rich text__ editing\\n- - [ ] Checklists', completed: false, priority: 'medium', createdAt: Date.now() - 86400000 * 2, dueDate: new Date(Date.now() + 86400000).toISOString().split('T')[0], tagIds: [1], pinned: true, status: 'todo', subtasks: [{ id: 'st1', title: 'Try clicking around', done: false }, { id: 'st2', title: 'Toggle dark mode 🌙', done: true }], recurring: { type: 'none', interval: 1 }, sortOrder: 0 },
    { id: 2, title: 'Quick Add Demo', description: 'Try typing in the quick add bar above:\\n\\n- \\"Buy milk tomorrow #shopping high\\"\\n- \\"Meeting mon low\\"\\n- \\"#ideas Brainstorm session\\"', completed: false, priority: 'low', createdAt: Date.now() - 86400000, tagIds: [2], pinned: false, status: 'todo', subtasks: [], recurring: { type: 'none', interval: 1 }, sortOrder: 0 },
    { id: 3, title: 'Board View is here!', description: 'Click the **📋** button to switch views\\n\\nTry the **Board** view to drag tasks between columns', completed: false, priority: 'medium', createdAt: Date.now() - 86400000 * 3, dueDate: new Date(Date.now() + 86400000 * 2).toISOString().split('T')[0], tagIds: [1, 3], pinned: false, status: 'in_progress', subtasks: [{ id: 'st3', title: 'Click 📋 to cycle views', done: true }], recurring: { type: 'none', interval: 1 }, sortOrder: 0 },
    { id: 4, title: 'Check your stats!', description: 'Cycle to **Dashboard** view to see:\\n- Weekly stats\\n- Focus time\\n- Activity chart', completed: false, priority: 'high', createdAt: Date.now() - 86400000 * 4, tagIds: [3], pinned: false, status: 'todo', subtasks: [], recurring: { type: 'none', interval: 1 }, sortOrder: 0 },
    { id: 5, title: 'Completed task example', description: 'This one is already done. Nice! 🎉', completed: true, priority: 'low', createdAt: Date.now() - 86400000 * 5, updatedAt: Date.now() - 86400000 * 1.5, tagIds: [], pinned: false, status: 'done', subtasks: [], recurring: { type: 'none', interval: 1 }, sortOrder: 0 },
  ];
  const sampleTags = [
    { id: 1, name: 'getting-started', color: '#6200EE' },
    { id: 2, name: 'demo', color: '#1E88E5' },
    { id: 3, name: 'features', color: '#43A047' },
  ];
  const sampleFocusSessions = [
    { id: 1, todoId: 3, startedAt: Date.now() - 3600000 * 2, durationMinutes: 25, completed: true },
    { id: 2, todoId: 1, startedAt: Date.now() - 3600000 * 5, durationMinutes: 25, completed: true },
  ];
  const sampleMoodEntries = [
    { timestamp: Date.now() - 86400000 * 0.5, rating: 4 },
    { timestamp: Date.now() - 86400000 * 1.5, rating: 3 },
    { timestamp: Date.now() - 86400000 * 2.5, rating: 5 },
  ];
  function getDefaultData() {
    return {
      todos: sampleTodos,
      tags: sampleTags,
      nextTodoId: 100,
      nextTagId: 100,
      deletedTodos: [],
      settings: { focusGoalMinutes: 60 },
      smartLists: [],
      focusSessions: sampleFocusSessions,
      moodEntries: sampleMoodEntries,
    };
  }
  function loadData() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        // Merge with defaults to ensure all fields exist
        const def = getDefaultData();
        return { ...def, ...parsed };
      }
    } catch(e) {}
    return getDefaultData();
  }
  function saveData(data) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch(e) {
      console.warn('localStorage save failed:', e);
    }
  }

  // Build the mock API
  const api = {
    getData: () => Promise.resolve(loadData()),
    saveData: (data) => { saveData(data); return Promise.resolve(); },
    sendNotification: (title, body) => console.log('[NOTIFICATION]', title, body),
    openPip: () => {
      console.log('[PiP] Open requested (browser: not available)');
      // Show a Desktop-only badge on the PiP button
      const btn = document.getElementById('pipBtn');
      if (btn) {
        btn.style.position = 'relative';
        let badge = btn.querySelector('.pip-badge');
        if (!badge) {
          badge = document.createElement('span');
          badge.className = 'pip-badge';
          badge.textContent = 'Desktop';
          Object.assign(badge.style, {
            position: 'absolute', top: '-6px', right: '-6px',
            background: '#ff4444', color: '#fff', fontSize: '8px',
            padding: '1px 4px', borderRadius: '8px', fontWeight: '700',
            letterSpacing: '0.3px', whiteSpace: 'nowrap',
            animation: 'pipBadgePop 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)',
          });
          btn.appendChild(badge);
          setTimeout(() => { if (badge.parentNode) badge.remove(); }, 4000);
        }
      }
      return Promise.resolve(false);
    },
    closePip: () => Promise.resolve(),
    updatePip: () => Promise.resolve(),
    updatePipTheme: () => Promise.resolve(),
    getPipState: () => Promise.resolve(false),
    onPipSync: (cb) => { window.__pipSyncCb = cb; },
    onPipClosedByPip: (cb) => { window.__pipClosedCb = cb; },
    // Floating Pomodoro (browser: no-op mocks)
    openPomodoro: () => Promise.resolve(false),
    closePomodoro: () => Promise.resolve(),
    getPomodoroState: () => Promise.resolve({ active: false, isStopped: true, remainingSeconds: 25 * 60, totalSeconds: 25 * 60, isRunning: false, isBreak: false, sessionCount: 0 }),
    onPomodoroSync: (cb) => { window.__pomoSyncCb = cb; },
    onPomodoroClosedByWindow: (cb) => { window.__pomoClosedCb = cb; },
    setPomodoroTodo: () => Promise.resolve(),
  };
  // Pomodoro shim for the floating timer page
  window.pomodoroApi = {
    onState: (cb) => { window.__pomoStateCb = cb; setTimeout(() => cb({ remainingSeconds: 25 * 60, totalSeconds: 25 * 60, isRunning: false, isBreak: false, isStopped: true, sessionCount: 2 }), 100); },
    onTheme: (cb) => { window.__pomoThemeCb = cb; },
    closePomodoro: () => console.log('[Pomo] close'),
    sendCommand: (cmd) => console.log('[Pomo] command:', cmd),
    resizeWindow: (w, h) => Promise.resolve(),
    getSettings: () => Promise.resolve({ pomodoroMinutes: 25, skipBreaks: false }),
    saveSettings: (s) => Promise.resolve(),
  };
  window.api = api;
  console.log('[Shim] Electron API shim loaded with localStorage persistence ✓');
  // Inject a small style rule for the PiP badge pop animation
  const style = document.createElement('style');
  style.textContent = '@keyframes pipBadgePop { 0% { transform: scale(0); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }';
  document.head.appendChild(style);
})();
</script>
`;

const server = http.createServer((req, res) => {
  // Normalize URL: default to index.html
  let url = req.url.split('?')[0];
  if (url === '/' || url === '') url = '/index.html';
  
  const filePath = path.join(SRC, url);
  
  // Security: ensure resolved path is within SRC
  const resolved = path.resolve(filePath);
  if (!resolved.startsWith(SRC)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404);
        res.end('Not Found');
      } else {
        res.writeHead(500);
        res.end('Internal Server Error');
      }
      return;
    }

    // For HTML files, inject the preload shim before the closing </head>
    if (ext === '.html') {
      let html = data.toString('utf-8');
      html = html.replace('</head>', PRELOAD_SHIM + '\n</head>');
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(html);
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(data);
    }
  });
});

server.listen(PORT, () => {
  console.log(`✓ Todo App dev server running at http://localhost:${PORT}`);
  console.log(`  Serving static files from: ${SRC}`);
});
