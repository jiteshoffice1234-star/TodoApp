const COLORS = [
  '#E53935', '#FB8C00', '#FDD835', '#43A047', '#1E88E5',
  '#8E24AA', '#FF4081', '#00ACC1', '#6D4C41', '#546E7A', '#6200EE'
];

let data = { todos: [], tags: [], nextTodoId: 1, nextTagId: 1, deletedTodos: [], settings: {}, smartLists: [] };
let currentFilter = 'all';
let searchQuery = '';
let editingTodoId = null;
let selectedPriority = 'medium';
let selectedTagColor = COLORS[0];
let currentTheme = 'light';
let activeSmartListId = null;

const THEMES = [
  { id: 'light', icon: '☀️', label: 'Light' },
  { id: 'dark', icon: '🌙', label: 'Dark' },
  { id: 'neobrutalism', icon: '💥', label: 'Neo' },
  { id: 'glass', icon: '🪟', label: 'Glass' },
  { id: 'minimal', icon: '⚪', label: 'Minimal' },
  { id: 'clay', icon: '🏺', label: 'Clay' },
];
const VIEWS = ['list', 'calendar'];
const VIEW_LABELS = { list: '📋 List', calendar: '📅 Calendar' };
let currentView = 'list';
let multiSelectMode = false;
let selectedIds = new Set();
let notifiedTodos = new Set();
let calYear, calMonth;


// Pomodoro
let pomoRunning = false;
let pomoIsBreak = false;
let pomoSeconds = 25 * 60;
let pomoTotal = 25 * 60;
let pomoInterval = null;
let pomoSessions = 0;

// --- Init ---
async function init() {
  const raw = await window.api.getData();
  data = {
    todos: raw.todos || [],
    tags: raw.tags || [],
    nextTodoId: raw.nextTodoId || 1,
    nextTagId: raw.nextTagId || 1,
    deletedTodos: raw.deletedTodos || [],
    settings: raw.settings || {},
    smartLists: raw.smartLists || [],
  };
  for (const t of data.todos) {
    if (t.tagIds === undefined) t.tagIds = [];
    if (t.pinned === undefined) t.pinned = false;
    if (t.reminderAt === undefined) t.reminderAt = null;
    if (t.reminderFired === undefined) t.reminderFired = false;
    if (t.sortOrder === undefined) t.sortOrder = 0;
  }
  const now = new Date();
  calYear = now.getFullYear();
  calMonth = now.getMonth();
  data._selectedCalDay = now.toISOString().split('T')[0];
  loadTheme();
  renderAll();
  bindEvents();
  initDragDrop();
  checkDueNotifications();
  setInterval(checkDueNotifications, 60000);
  // Re-sync PiP when main window is shown again — let interval handle the push
  window.api.onPipSync(() => {
    if (pipActive) {
      _lastPipHtml = null; // sentinel forces next interval push even if content is empty
      if (!pipInterval) startPipInterval();
    }
  });
  // Clean up PiP state when closed via drag-to-cancel in pip window
  window.api.onPipClosedByPip(() => {
    pipActive = false;
    if (pipInterval) { clearInterval(pipInterval); pipInterval = null; }
    document.getElementById('pipBtn').textContent = '📺';
    document.getElementById('pipBtn').title = 'Pop Out Ticker';
  });
  // Auto-restore PiP if it was active before
  restorePipState();

  // Floating Pomodoro
  window.api.onPomodoroClosedByWindow(() => {
    pomodoroActive = false;
    const btn = document.getElementById('pomoFloatBtn');
    if (btn) { btn.textContent = '⏱️'; btn.title = 'Floating Pomodoro'; }
  });
  window.api.onPomodoroSync((state) => {
    // Sync pomodoro state from main process
    if (typeof window._syncPomodoroState === 'function') {
      window._syncPomodoroState(state);
    }
  });
  restorePomodoroState();

  // Ticker hover pause — pause JS-driven scroll on hover, resume on leave
  const tickerWindow = document.querySelector('.ticker-window');
  if (tickerWindow) {
    tickerWindow.addEventListener('mouseenter', () => { _tickerPaused = true; });
    tickerWindow.addEventListener('mouseleave', () => { _tickerPaused = false; });
  }

  // Setup update listeners
  setupUpdateListeners();

  // Initialize Lottie animation for auto-updater UI
  initUpdateAnimation();

  // Sync with main process's current update state (handles race where
  // initial 5-second auto-check completed before listeners were registered)
  if (typeof window.api.getUpdateStatus === 'function') {
    window.api.getUpdateStatus().then((state) => {
      if (state && state.status !== 'idle') {
        _updateState = state;
        refreshUpdateUI();
      }
    }).catch(() => {});
  }
}

function loadTheme() { currentTheme = localStorage.getItem('theme') || 'light'; applyTheme(); }
function applyTheme() {
  document.body.className = document.body.className.replace(/theme-\w+/g, '').trim();
  if (currentTheme !== 'light') document.body.classList.add('theme-' + currentTheme);
  const t = THEMES.find(x => x.id === currentTheme);
  document.getElementById('themeToggle').textContent = t ? t.icon : '☀️';
  document.getElementById('themeToggle').title = t ? t.label : 'Light';
  if (pipActive) window.api.updatePipTheme(currentTheme);
}
function toggleTheme() {
  const idx = THEMES.findIndex(t => t.id === currentTheme);
  const next = (idx + 1) % THEMES.length;
  currentTheme = THEMES[next].id;
  localStorage.setItem('theme', currentTheme);
  applyTheme();
  showToast(`Theme: ${THEMES[next].label}`, THEMES[next].icon);
}
async function persist() { await window.api.saveData(data); }

// --- Notifications ---
function checkDueNotifications() {
  const today = new Date().toISOString().split('T')[0];
  for (const todo of data.todos) {
    if (todo.completed || !todo.dueDate) continue;
    const notifKey = `${todo.id}_${todo.dueDate}`;
    if (notifiedTodos.has(notifKey)) continue;
    if (todo.dueDate === today) {
      window.api.sendNotification('Todo App', `"${todo.title}" is due today!`);
    } else if (todo.dueDate < today) {
      const overdue = Math.floor((new Date().getTime() - new Date(todo.dueDate).getTime()) / 86400000);
      if (overdue === 1) {
        window.api.sendNotification('Todo App', `"${todo.title}" is 1 day overdue!`);
      } else if (overdue > 1) {
        window.api.sendNotification('Todo App', `"${todo.title}" is ${overdue} days overdue!`);
      }
    } else {
      continue;
    }
    notifiedTodos.add(notifKey);
    if (todo.reminderAt && todo.reminderAt <= Date.now() && !todo.reminderFired) {
      window.api.sendNotification('Reminder', todo.title);
      todo.reminderFired = true;
      persist();
    }
  }
}

// --- Toast ---
function showToast(message, icon = '✓', duration = 3000, undoCallback = null) {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = 'toast';
  const textSpan = document.createElement('span');
  textSpan.textContent = `${icon} ${message}`;
  toast.appendChild(textSpan);
  if (undoCallback) {
    const undoBtn = document.createElement('button');
    undoBtn.className = 'toast-undo-btn';
    undoBtn.textContent = '↩ Undo';
    undoBtn.onclick = () => { undoCallback(); if (toast.parentNode) toast.remove(); };
    toast.appendChild(undoBtn);
    toast.style.animation = `toastIn 0.3s ease, toastOut 0.3s ease ${duration}ms forwards`;
  }
  container.appendChild(toast);
  setTimeout(() => { if (toast.parentNode) toast.remove(); }, duration + 300);
}

// --- Smart Lists ---
function getDefaultSmartLists() {
  return [
    { id: 'due-today', name: 'Due Today', icon: '📅', filter: 'due-today', search: '', tagIds: [], builtin: true },
    { id: 'high-priority', name: 'High Priority', icon: '🔴', filter: 'high-priority', search: '', tagIds: [], builtin: true },
    { id: 'pending', name: 'Pending', icon: '📋', filter: 'pending', search: '', tagIds: [], builtin: true },
  ];
}
function applySmartListById(id) {
  const defaults = getDefaultSmartLists();
  const user = (data.smartLists || []).filter(s => !s.builtin);
  const all = defaults.concat(user);
  const sl = all.find(s => s.id === id);
  if (sl) applySmartList(sl);
}
function applySmartList(sl) {
  activeSmartListId = sl.id;
  currentFilter = sl.filter || 'all';
  searchQuery = sl.search || '';
  document.getElementById('searchInput').value = searchQuery;
  document.getElementById('clearSearch').classList.toggle('hidden', !searchQuery);
  document.querySelectorAll('.filter-chip').forEach(c => c.classList.toggle('active', c.dataset.filter === currentFilter));
  renderSmartLists();
  renderTodos();
}
function saveCurrentViewAsSmartList() {
  const name = prompt('Name this smart list:');
  if (!name || !name.trim()) return;
  const sl = {
    id: 'sl_' + Date.now(),
    name: name.trim(),
    icon: '📌',
    filter: currentFilter,
    search: searchQuery,
    tagIds: [],
    builtin: false,
  };
  if (!data.smartLists) data.smartLists = [];
  data.smartLists.push(sl);
  applySmartList(sl);
  persist();
  showToast(`Smart List "${sl.name}" saved`, '📌');
}
function deleteSmartList(id) {
  const sl = (data.smartLists || []).find(s => s.id === id);
  if (!sl || sl.builtin) return;
  data.smartLists = data.smartLists.filter(s => s.id !== id);
  if (activeSmartListId === id) { activeSmartListId = null; currentFilter = 'all'; searchQuery = ''; document.getElementById('searchInput').value = ''; }
  renderSmartLists();
  persist();
  showToast(`"${sl.name}" deleted`, '🗑️');
}
function renderSmartLists() {
  const defaults = getDefaultSmartLists();
  const user = (data.smartLists || []).filter(s => !s.builtin);
  const all = defaults.concat(user);
  const container = document.getElementById('smartLists');
  if (!container) return;
  container.innerHTML = all.map(sl => {
    const active = activeSmartListId === sl.id ? 'active' : '';
    const delBtn = sl.builtin ? '' : `<button class="sl-del" onclick="event.stopPropagation();deleteSmartList('${sl.id}')" title="Delete">✕</button>`;
    return `<div class="sl-chip ${active}" data-sl-id="${sl.id}" onclick="applySmartListById('${sl.id}')">
      <span>${sl.icon} ${escapeHtml(sl.name)}</span>${delBtn}
    </div>`;
  }).join('');
}

// --- Render ---
function renderAll() {
  // Hide all view containers
  ['todoList','calendarView','emptyState'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
  });
  // Show current view
  const vi = document.getElementById('viewIndicator');
  if (vi) {
    vi.innerHTML = `<span class="vi-badge">${VIEW_LABELS[currentView]}</span>`;
  }
  switch (currentView) {
    case 'list': renderTodos(); break;
    case 'calendar': renderCalendar(); break;
    default: renderTodos();
  }
  renderTagSelector(); renderTagList(); updateMeta(); renderTicker(); renderSmartLists();
}

function cycleView() {
  const idx = VIEWS.indexOf(currentView);
  currentView = VIEWS[(idx + 1) % VIEWS.length];
  document.getElementById('viewToggle').textContent = VIEW_LABELS[currentView].split(' ')[0];
  renderAll();
  showToast(`View: ${VIEW_LABELS[currentView]}`, '🔄');
}

function getFilteredTodos() {
  let list = [...data.todos];
  if (searchQuery) {
    const q = searchQuery.toLowerCase();
    list = list.filter(t => t.title.toLowerCase().includes(q) || (t.description && t.description.toLowerCase().includes(q)));
  }
  if (currentFilter === 'pending') list = list.filter(t => !t.completed);
  if (currentFilter === 'done') list = list.filter(t => t.completed);
  if (currentFilter === 'due-today') {
    const today = new Date().toISOString().split('T')[0];
    list = list.filter(t => !t.completed && t.dueDate === today);
  }
  if (currentFilter === 'high-priority') {
    list = list.filter(t => !t.completed && t.priority === 'high');
  }
  list.sort((a, b) => {
    if (!!a.pinned !== !!b.pinned) return a.pinned ? -1 : 1;
    if (a.completed !== b.completed) return a.completed ? 1 : -1;
    const pOrder = { high: 0, medium: 1, low: 2 };
    if (pOrder[a.priority] !== pOrder[b.priority]) return pOrder[a.priority] - pOrder[b.priority];
    if (a.dueDate && b.dueDate) return a.dueDate.localeCompare(b.dueDate);
    if (a.dueDate) return -1;
    if (b.dueDate) return 1;
    return b.createdAt - a.createdAt;
  });
  return list;
}

// --- PiP Pop Out Ticker ---
let pipActive = false;
let pipInterval = null;
let _lastPipHtml = null; // Cache: null = never pushed, '' = empty content pushed, string = content pushed
let _pipStartupDeferred = false;

// --- Floating Pomodoro ---
let pomodoroActive = false;
let _pomodoroStartupDeferred = false;

// Ticker state (JS-driven scroll, same approach as PiP)
let _tickerRafId = null;
let _tickerPos = 0;
let _tickerContentWidth = 0;
let _tickerSpeed = 0; // px per frame, recalculated on every content update
let _tickerPaused = false;

const PIP_PRIORITY_ICONS = { high: '🔴', medium: '🟠', low: '🟢' };

function getTickerHTML() {
  const pending = data.todos.filter(t => !t.completed);
  if (!pending.length) {
    return ''; // empty string = main window shows nothing; PiP shows fallback
  }
  const items = pending.map(t => {
    const icon = PIP_PRIORITY_ICONS[t.priority] || '🎯';
    const title = escapeHtml(t.title);
    const overdue = t.dueDate && t.dueDate < new Date().toISOString().split('T')[0];
    const badge = overdue ? ' ⚠️' : '';
    return `<span class="ticker-item">${icon} ${title}${badge}</span>`;
  });
  // Single copy — consumers (main ticker + PiP) duplicate in the DOM to fill the viewport
  return items.join('');
}

// Only push to PiP when content actually changes (avoids resetting the scroll animation)
function pushPipContentIfChanged() {
  const html = getTickerHTML();
  if (html === _lastPipHtml) return; // No change — animation keeps scrolling smoothly
  _lastPipHtml = html;
  window.api.updatePip(html);
}

async function pipOpen() {
  const ok = await window.api.openPip();
  if (!ok) return false;
  pipActive = true;
  document.getElementById('pipBtn').textContent = '🔴';
  document.getElementById('pipBtn').title = 'Close Pop Out';
  await window.api.updatePipTheme(currentTheme);
  _lastPipHtml = null; // Reset cache with sentinel so first push always goes through
  pushPipContentIfChanged();
  startPipInterval();
  return true;
}

function startPipInterval() {
  if (pipInterval) clearInterval(pipInterval);
  // Check every 5 seconds, but only push when content actually changed
  pipInterval = setInterval(() => {
    if (!pipActive) return;
    pushPipContentIfChanged();
  }, 5000);
}

async function pipToggle() {
  if (pipActive) { await pipClose(); return; }
  const ok = await pipOpen();
  if (!ok) showToast('Failed to open PiP window', '⚠️');
}

async function pipClose() {
  pipActive = false;
  _lastPipHtml = '';
  _pipStartupDeferred = false; // Reset flag so PiP can be restored again later
  if (pipInterval) { clearInterval(pipInterval); pipInterval = null; }
  await window.api.closePip();
  document.getElementById('pipBtn').textContent = '📺';
  document.getElementById('pipBtn').title = 'Pop Out Ticker';
}

// Defer PiP restoration so the main UI can render first — no morning lag
async function restorePipState() {
  if (_pipStartupDeferred) return;
  _pipStartupDeferred = true;
  // Wait for UI to fully paint before opening PiP window
  await new Promise(r => setTimeout(r, 300));
  const wasActive = await window.api.getPipState();
  if (wasActive) {
    const ok = await pipOpen();
    if (ok) showToast('PiP reconnected', '📺');
  }
}

// --- Floating Pomodoro ---
async function pomodoroToggle() {
  if (pomodoroActive) {
    await window.api.closePomodoro();
    pomodoroActive = false;
    const btn = document.getElementById('pomoFloatBtn');
    if (btn) { btn.textContent = '⏱️'; btn.title = 'Floating Pomodoro'; }
    return;
  }
  const ok = await window.api.openPomodoro();
  if (ok) {
    pomodoroActive = true;
    const btn = document.getElementById('pomoFloatBtn');
    if (btn) { btn.textContent = '🔴'; btn.title = 'Close Floating Pomodoro'; }
  } else {
    showToast('Failed to open Pomodoro window', '⚠️');
  }
}

async function restorePomodoroState() {
  if (_pomodoroStartupDeferred) return;
  _pomodoroStartupDeferred = true;
  await new Promise(r => setTimeout(r, 400));
  const state = await window.api.getPomodoroState();
  if (state && state.active) {
    pomodoroActive = true;
    const btn = document.getElementById('pomoFloatBtn');
    if (btn) { btn.textContent = '🔴'; btn.title = 'Close Floating Pomodoro'; }
  }
}

// Sync pomodoro state from main process
window._syncPomodoroState = function(state) {
  // Update local pomodoro state if needed
  if (state && state.active !== undefined) {
    pomodoroActive = state.active;
    const btn = document.getElementById('pomoFloatBtn');
    if (btn) {
      btn.textContent = pomodoroActive ? '🔴' : '⏱️';
      btn.title = pomodoroActive ? 'Close Floating Pomodoro' : 'Floating Pomodoro';
    }
  }
};

function renderTicker() {
  const html = getTickerHTML();
  const ticker = document.getElementById('todoTicker');
  if (!ticker) return;

  // Save scroll ratio so we can restore position after content swap
  // (same approach as the PiP ticker - prevents visual jump on every todo change)
  const ratio = _tickerContentWidth > 0
    ? Math.min(0.99, Math.abs(_tickerPos) / _tickerContentWidth)
    : 0;

  if (html && html.trim()) {
    // Duplicate the single copy enough times to fill at least 2x the viewport
    // for a seamless loop regardless of item count.
    ticker.innerHTML = html;
    const singleW = ticker.scrollWidth || 1;
    const viewW = (ticker.parentElement && ticker.parentElement.clientWidth) || 400;
    const copies = Math.max(2, Math.ceil((viewW * 2) / singleW));
    if (copies > 1) ticker.innerHTML = html.repeat(copies);

    _tickerContentWidth = singleW;
    _tickerPos = -(ratio * _tickerContentWidth);
    if (Math.abs(_tickerPos) >= _tickerContentWidth) _tickerPos = 0;
    ticker.style.transform = 'translateX(' + _tickerPos + 'px)';

    // Speed for ~25s full cycle at 60fps
    _tickerSpeed = Math.max(0.3, Math.min(3.0, _tickerContentWidth / (25 * 60)));
    // Persistent loop — always reschedules itself, never freezes on content updates.
    _tickerRafId = _tickerRafId || requestAnimationFrame(function tickerLoop() {
      if (!_tickerPaused && _tickerContentWidth > 0) {
        _tickerPos -= _tickerSpeed;
        if (Math.abs(_tickerPos) >= _tickerContentWidth) {
          _tickerPos = 0;
        }
      }
      ticker.style.transform = 'translateX(' + _tickerPos + 'px)';
      _tickerRafId = requestAnimationFrame(tickerLoop);
    });
  } else {
    // Empty state — show static fallback, stop RAF loop
    ticker.innerHTML = '<span class="ticker-item">✅ All caught up — no pending tasks!</span>';
    ticker.style.transform = 'translateX(0)';
    _tickerPos = 0;
    _tickerContentWidth = 0;
    if (_tickerRafId) {
      cancelAnimationFrame(_tickerRafId);
      _tickerRafId = null;
    }
  }

  // Push to PiP immediately when content changes (not just on the 5s poll)
  if (pipActive) pushPipContentIfChanged();

  // Keep PiP interval running if PiP is active
  if (pipActive && !pipInterval) {
    startPipInterval();
  }
}

function updateMeta() {
  const total = data.todos.length;
  const pending = data.todos.filter(t => !t.completed).length;
  const done = data.todos.filter(t => t.completed).length;
  document.getElementById('todoCount').textContent = `${pending} pending`;
  document.getElementById('countAll').textContent = total;
  document.getElementById('countPending').textContent = pending;
  document.getElementById('countDone').textContent = done;
  document.getElementById('clearCompleted').classList.toggle('hidden', done === 0);
}

// --- Speed Dial ---
function toggleSpeedDial() {
  const dial = document.getElementById('speedDial');
  const actions = document.getElementById('speedDialActions');
  const backdrop = document.getElementById('speedDialBackdrop');
  const isOpen = !actions.classList.contains('hidden');
  if (!isOpen) {
    actions.classList.remove('hidden');
    backdrop.classList.remove('hidden');
    dial.classList.add('open');
    // Re-trigger animations by resetting display
    document.querySelectorAll('.sd-action').forEach((el, i) => {
      el.style.animation = 'none';
      el.offsetHeight; // force reflow
      el.style.animation = '';
    });
  } else {
    closeSpeedDial();
  }
}
function closeSpeedDial() {
  const dial = document.getElementById('speedDial');
  const actions = document.getElementById('speedDialActions');
  const backdrop = document.getElementById('speedDialBackdrop');
  actions.classList.add('hidden');
  backdrop.classList.add('hidden');
  dial.classList.remove('open');
}

function renderTodos() {
  const list = getFilteredTodos();
  const container = document.getElementById('todoList');
  const empty = document.getElementById('emptyState');
  document.getElementById('calendarView').classList.add('hidden');
  container.classList.remove('hidden');

  if (list.length === 0) {
    container.innerHTML = '';
    empty.classList.remove('hidden');
    document.getElementById('emptyTitle').textContent = searchQuery ? 'No results found' : 'No todos yet';
    document.getElementById('emptySubtitle').textContent = searchQuery ? 'Try a different search' : 'Click + to add your first todo';
    return;
  }
  empty.classList.add('hidden');

  container.innerHTML = list.map((todo, idx) => {
    const pinIcon = todo.pinned ? '📌' : '📍';
    const todoTags = (todo.tagIds || []).map(id => data.tags.find(t => t.id === id)).filter(Boolean);
    const tagDots = todoTags.slice(0, 4).map(t => `<span class="tag-dot" style="background:${t.color}"></span>`).join('');
    const moreTag = todoTags.length > 4 ? `<span class="tag-dot more">+${todoTags.length - 4}</span>` : '';
    const tagDotsHtml = (tagDots || moreTag) ? `<div class="tag-dots">${tagDots}${moreTag}</div>` : '';
    const tagBadges = todoTags.map(t => `<span class="todo-tag-badge" style="background:${t.color}">${escapeHtml(t.name)}</span>`).join('');
    const tagRow = tagBadges ? `<div class="todo-tags-row">${tagBadges}</div>` : '';
    const desc = todo.description ? `<div class="todo-desc">${mdToHtml(todo.description)}</div>` : '';

    let dueHtml = '';
    if (todo.dueDate) {
      const due = new Date(todo.dueDate + 'T23:59:59');
      const isOverdue = due < new Date() && !todo.completed;
      dueHtml = `<div class="todo-due ${isOverdue ? 'overdue' : 'normal'}">📅 ${formatDate(todo.dueDate)}</div>`;
    }

    // Recurring badge
    let recurHtml = '';
    if (todo.recurring && todo.recurring.type !== 'none') {
      recurHtml = `<span class="todo-recur-badge">🔄 ${todo.recurring.type}</span>`;
    }

    // Reminder badge
    let remindHtml = '';
    if (todo.reminderAt) {
      remindHtml = `<span class="todo-remind-badge">⏰</span>`;
    }

    // Subtasks
    let subtaskHtml = '';
    if (todo.subtasks && todo.subtasks.length > 0) {
      const doneCount = todo.subtasks.filter(s => s.done).length;
      const pct = Math.round((doneCount / todo.subtasks.length) * 100);
      subtaskHtml = `
        <div class="todo-subtask-progress">
          <span class="subtask-count">📋 ${doneCount}/${todo.subtasks.length}</span>
          <div class="subtask-bar"><div class="subtask-fill" style="width:${pct}%"></div></div>
        </div>`;
    }

    // Multi-select
    const selClass = selectedIds.has(todo.id) ? 'selected' : '';
    const selCheck = multiSelectMode ? `<div class="todo-select-check ${selClass}" onclick="event.stopPropagation();toggleSelect(${todo.id})">${selectedIds.has(todo.id) ? '☑️' : '⬜'}</div>` : '';

    // Drag handle
    const dragHandle = `<span class="drag-handle" draggable="true" data-id="${todo.id}">⋮⋮</span>`;

    return `
      <div class="todo-card ${todo.completed ? 'completed' : ''} ${todo.pinned ? 'pinned' : ''} ${selClass}" data-id="${todo.id}" style="animation-delay:${idx * 40}ms" onclick="${multiSelectMode ? `toggleSelect(${todo.id})` : `editTodo(${todo.id})`}">
        <div class="todo-row1">
          ${dragHandle}
          ${selCheck}
          <span class="pin-icon ${todo.pinned ? 'pinned' : ''}" onclick="event.stopPropagation();togglePin(${todo.id})" title="${todo.pinned ? 'Unpin' : 'Pin to top'}">${pinIcon}</span>
          <div class="todo-checkbox ${todo.completed ? 'checked' : ''}" onclick="event.stopPropagation();toggleTodo(${todo.id})"></div>
          ${tagDotsHtml}
          <span class="todo-title">${escapeHtml(todo.title)}</span>
          ${recurHtml}${remindHtml}
          <span class="priority-badge priority-${todo.priority}">${capitalize(todo.priority)}</span>
          <div class="todo-actions">
            <button class="todo-action-btn" onclick="event.stopPropagation();editTodo(${todo.id})" title="Edit">✏️</button>
            <button class="todo-action-btn delete" onclick="event.stopPropagation();deleteTodo(${todo.id})" title="Delete">🗑️</button>
          </div>
        </div>
        ${tagRow}${desc}${dueHtml}${subtaskHtml}
      </div>`;
  }).join('');
}

// --- Calendar ---
function renderCalendar() {
  document.getElementById('todoList').classList.add('hidden');
  document.getElementById('emptyState').classList.add('hidden');
  const cal = document.getElementById('calendarView');
  cal.classList.remove('hidden');

  const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  document.getElementById('calTitle').textContent = `${monthNames[calMonth]} ${calYear}`;

  const firstDay = new Date(calYear, calMonth, 1).getDay();
  const daysInMonth = new Date(calYear, calMonth + 1, 0).getDate();
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const selectedCalDay = data._selectedCalDay;

  const todosByDate = {};
  for (const t of data.todos) {
    if (t.dueDate) {
      if (!todosByDate[t.dueDate]) todosByDate[t.dueDate] = [];
      todosByDate[t.dueDate].push(t);
    }
  }

  let grid = '';
  for (let i = 0; i < firstDay; i++) grid += '<div class="cal-cell empty"></div>';
  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = `${calYear}-${String(calMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const isToday = dateStr === todayStr;
    const isSelected = dateStr === selectedCalDay;
    const hasTodos = todosByDate[dateStr] && todosByDate[dateStr].length > 0;
    const dotHtml = hasTodos ? `<span class="cal-dot"></span>` : '';
    grid += `<div class="cal-cell ${isToday ? 'today' : ''} ${isSelected ? 'selected' : ''}" onclick="selectCalDay('${dateStr}')">${d}${dotHtml}</div>`;
  }
  document.getElementById('calGrid').innerHTML = grid;

  if (selectedCalDay) {
    const dayTodos = todosByDate[selectedCalDay] || [];
    document.getElementById('calTodos').innerHTML = dayTodos.length === 0
      ? `<div class="cal-empty">No todos for ${formatDate(selectedCalDay)}</div>`
      : dayTodos.map(t => `
        <div class="cal-todo-item ${t.completed ? 'completed' : ''}" onclick="editTodo(${t.id})">
          <div class="todo-checkbox ${t.completed ? 'checked' : ''}" onclick="event.stopPropagation();toggleTodo(${t.id})"></div>
          <span class="cal-todo-title">${escapeHtml(t.title)}</span>
          <span class="priority-badge priority-${t.priority}">${capitalize(t.priority)}</span>
        </div>`).join('');
  } else {
    document.getElementById('calTodos').innerHTML = '<div class="cal-empty">Select a day to view todos</div>';
  }
}
function calPrev() { calMonth--; if (calMonth < 0) { calMonth = 11; calYear--; } renderCalendar(); }
function calNext() { calMonth++; if (calMonth > 11) { calMonth = 0; calYear++; } renderCalendar(); }
function selectCalDay(dateStr) { data._selectedCalDay = dateStr; renderCalendar(); }

// --- Pomodoro ---
function openPomodoro() {
  document.getElementById('pomodoroModal').classList.remove('hidden');
  renderPomoSessions();
  updatePomoDisplay();
}
function closePomodoro() {
  document.getElementById('pomodoroModal').classList.add('hidden');
}
function pomoToggle() {
  if (pomoRunning) { pomoPause(); } else { pomoStart(); }
}
function pomoStart() {
  if (pomoInterval) clearInterval(pomoInterval); // Prevent timer stacking
  pomoRunning = true;
  pomoInterval = setInterval(() => {
    if (pomoSeconds > 0) { pomoSeconds--; updatePomoDisplay(); }
    else { pomoComplete(); }
  }, 1000);
  updatePomoDisplay();
  document.getElementById('pomoPlayBtn').textContent = '⏸';
}
function pomoPause() {
  pomoRunning = false;
  clearInterval(pomoInterval);
  updatePomoDisplay();
  document.getElementById('pomoPlayBtn').textContent = '▶';
}
function pomoReset() {
  pomoPause();
  pomoSeconds = pomoIsBreak ? 5 * 60 : 25 * 60;
  pomoTotal = pomoSeconds;
  updatePomoDisplay();
}
function pomoSkip() { pomoPause(); pomoComplete(); }
function pomoComplete() {
  pomoPause();
  if (!pomoIsBreak) {
    pomoSessions++;
    if (pomoSessions % 4 === 0) { pomoIsBreak = true; pomoSeconds = 15 * 60; }
    else { pomoIsBreak = true; pomoSeconds = 5 * 60; }
  } else {
    pomoIsBreak = false;
    pomoSeconds = 25 * 60;
  }
  pomoTotal = pomoSeconds;
  renderPomoSessions();
  updatePomoDisplay();
  window.api.sendNotification('Pomodoro', pomoIsBreak ? 'Break time!' : 'Focus time!');
}
function updatePomoDisplay() {
  const min = Math.floor(pomoSeconds / 60);
  const sec = pomoSeconds % 60;
  document.getElementById('pomoTime').textContent = `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  document.getElementById('pomoLabel').textContent = pomoIsBreak ? 'Break Time' : 'Focus Time';
  const pct = pomoTotal > 0 ? ((pomoTotal - pomoSeconds) / pomoTotal) : 0;
  const circle = document.getElementById('pomoProgress');
  if (circle) {
    const circumference = 2 * Math.PI * 90;
    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = circumference * (1 - pct);
  }
}
function renderPomoSessions() {
  const el = document.getElementById('pomoSessions');
  el.innerHTML = Array.from({ length: 4 }, (_, i) =>
    `<span class="pomo-dot ${i < (pomoSessions % 4) ? 'filled' : ''}"></span>`
  ).join('') + `<span class="pomo-session-text">Session ${pomoSessions + 1}</span>`;
}
// --- Markdown helpers ---
function mdToHtml(text) {
  if (!text) return '';
  let html = escapeHtml(text);
  // Inline code
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  // Bold
  html = html.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
  // Italic
  html = html.replace(/_([^_]+)_/g, '<i>$1</i>');
  // Underline
  html = html.replace(/__(.+?)__/g, '<u>$1</u>');
  // Checklist items (must be before list items)
  html = html.replace(/^- \[x\] (.*)$/gim, '<label class="md-checklist"><input type="checkbox" checked disabled><span>$1</span></label>');
  html = html.replace(/^- \[ \] (.*)$/gim, '<label class="md-checklist"><input type="checkbox" disabled><span>$1</span></label>');
  // Bullet list items
  html = html.replace(/^• (.*)$/gim, '<li>$1</li>');
  html = html.replace(/^- (.*)$/gim, '<li>$1</li>');
  // Paragraphs (double newlines)
  html = html.split(/\n\n+/).map(p => {
    p = p.trim();
    if (!p) return '';
    if (p.startsWith('<') && (p.endsWith('>') || p.endsWith('</label>'))) return p;
    if (p.startsWith('<li>')) return '<ul>' + p.replace(/<\/li>(<li>)/g, '$1') + '</ul>';
    return '<p>' + p + '</p>';
  }).join('\n');
  // Single newlines within paragraphs
  html = html.replace(/<\/p>\n<p>/g, '</p>\n<p>');
  html = html.replace(/(?<!<\/[^>]*)\n(?!<)/g, '<br>');
  return html;
}

// --- Rich text helpers ---
function richBold() { wrapSelection('**', '**'); }
function richItalic() { wrapSelection('_', '_'); }
function richUnderline() { wrapSelection('__', '__'); }
function richList() {
  const ta = document.getElementById('todoDesc');
  const start = ta.selectionStart;
  ta.value = ta.value.substring(0, start) + '\n• ' + ta.value.substring(ta.selectionEnd);
  ta.selectionStart = ta.selectionEnd = start + 3;
  ta.focus();
}
function richCode() {
  wrapSelection('`', '`');
}
function richCheckbox() {
  const ta = document.getElementById('todoDesc');
  const start = ta.selectionStart;
  ta.value = ta.value.substring(0, start) + '- [ ] ' + ta.value.substring(ta.selectionEnd);
  ta.selectionStart = ta.selectionEnd = start + 6;
  ta.focus();
}
function wrapSelection(before, after) {
  const ta = document.getElementById('todoDesc');
  const start = ta.selectionStart;
  const end = ta.selectionEnd;
  const selected = ta.value.substring(start, end);
  ta.value = ta.value.substring(0, start) + before + selected + after + ta.value.substring(end);
  ta.selectionStart = start + before.length;
  ta.selectionEnd = end + before.length;
  ta.focus();
}
let mdPreviewActive = false;
function toggleMdPreview() {
  mdPreviewActive = !mdPreviewActive;
  const ta = document.getElementById('todoDesc');
  const preview = document.getElementById('mdPreview');
  const btn = document.getElementById('mdPreviewBtn');
  ta.classList.toggle('hidden', mdPreviewActive);
  preview.classList.toggle('hidden', !mdPreviewActive);
  if (mdPreviewActive) {
    preview.innerHTML = mdToHtml(ta.value);
  }
  btn.textContent = mdPreviewActive ? '✏️' : '👁️';
  btn.title = mdPreviewActive ? 'Edit' : 'Preview';
}
// Live preview update on input
function onDescInput() {
  if (mdPreviewActive) {
    document.getElementById('mdPreview').innerHTML = mdToHtml(document.getElementById('todoDesc').value);
  }
}

// --- Drag & Drop ---
let dragId = null;
let dragEl = null;
function initDragDrop() {
  const list = document.getElementById('todoList');
  list.addEventListener('dragstart', onDragStart);
  list.addEventListener('dragenter', onDragEnter);
  list.addEventListener('dragover', onDragOver);
  list.addEventListener('dragleave', onDragLeave);
  list.addEventListener('drop', onDrop);
  list.addEventListener('dragend', onDragEnd);
}
function onDragStart(e) {
  const handle = e.target.closest('.drag-handle');
  if (!handle) return;
  dragEl = handle.closest('.todo-card');
  if (!dragEl) return;
  dragId = Number(dragEl.dataset.id);
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setDragImage(dragEl, e.offsetX, e.offsetY);
  requestAnimationFrame(() => dragEl.classList.add('dragging'));
}
function onDragOver(e) {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
}
function onDragEnter(e) {
  const card = e.target.closest('.todo-card');
  if (!card || card === dragEl) return;
  card.classList.add('drag-over');
}
function onDragLeave(e) {
  const card = e.target.closest('.todo-card');
  if (!card) return;
  if (e.relatedTarget && card.contains(e.relatedTarget)) return;
  card.classList.remove('drag-over');
}
function onDrop(e) {
  const target = e.target.closest('.todo-card');
  if (!target) return;
  target.classList.remove('drag-over');
  const toId = Number(target.dataset.id);
  if (dragId === null || dragId === toId) return;
  const ids = data.todos.map(t => t.id);
  const fromIdx = ids.indexOf(dragId);
  const toIdx = ids.indexOf(toId);
  if (fromIdx === -1 || toIdx === -1) return;
  const [item] = data.todos.splice(fromIdx, 1);
  data.todos.splice(toIdx, 0, item);
  dragId = null; dragEl = null;
  persist();
  renderTodos();
}
function onDragEnd() {
  document.querySelectorAll('.drag-over').forEach(el => el.classList.remove('drag-over'));
  if (dragEl) dragEl.classList.remove('dragging');
  dragId = null; dragEl = null;
}

// ===== SMART QUICK ADD =====
function parseNaturalLanguage(text) {
  const result = { title: text, dueDate: null, priority: 'medium', tags: [] };
  let remaining = text;
  // Date patterns
  const datePatterns = [
    { regex: /\b(today)\b/i, offset: 0 },
    { regex: /\b(tomorrow)\b/i, offset: 1 },
    { regex: /\b(next week)\b/i, offset: 7 },
    { regex: /\b(monday|mon)\b/i, offset: (getNextWeekday(1) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(tuesday|tue)\b/i, offset: (getNextWeekday(2) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(wednesday|wed)\b/i, offset: (getNextWeekday(3) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(thursday|thu)\b/i, offset: (getNextWeekday(4) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(friday|fri)\b/i, offset: (getNextWeekday(5) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(saturday|sat)\b/i, offset: (getNextWeekday(6) - new Date().getDate() + 28) % 28 || 7 },
    { regex: /\b(sunday|sun)\b/i, offset: (getNextWeekday(0) - new Date().getDate() + 28) % 28 || 7 },
  ];
  for (const p of datePatterns) {
    const m = remaining.match(p.regex);
    if (m) {
      const d = new Date(); d.setDate(d.getDate() + (p.offset || 0));
      result.dueDate = d.toISOString().split('T')[0];
      remaining = remaining.replace(m[0], '').trim();
      break;
    }
  }
  const dateRegex = /\b(\d{1,2})[\/.-](\d{1,2})(?:[\/.-](\d{2,4}))?\b/;
  const dm = remaining.match(dateRegex);
  if (dm && !result.dueDate) {
    const month = parseInt(dm[1]) - 1; const day = parseInt(dm[2]);
    let year = dm[3] ? parseInt(dm[3]) : new Date().getFullYear();
    if (year < 100) year += 2000;
    const d = new Date(year, month, day);
    if (d > new Date()) { result.dueDate = d.toISOString().split('T')[0]; remaining = remaining.replace(dm[0], '').trim(); }
  }
  // Priority
  const priorityMatch = remaining.match(/\b(high|medium|low)\b/i);
  if (priorityMatch) {
    result.priority = priorityMatch[1].toLowerCase();
    remaining = remaining.replace(priorityMatch[0], '').trim();
  }
  // Tags (#hashtag)
  const tagRegex = /#(\w+)/g;
  let tagMatch;
  while ((tagMatch = tagRegex.exec(remaining)) !== null) {
    result.tags.push(tagMatch[1].toLowerCase());
  }
  remaining = remaining.replace(/#\w+/g, '').trim();
  result.title = remaining || result.title;
  return result;
}
function getNextWeekday(day) {
  const d = new Date();
  const current = d.getDay();
  const diff = (day - current + 7) % 7;
  return d.getDate() + (diff === 0 ? 7 : diff);
}
function updateQuickAddPreview() {
  const input = document.getElementById('quickAddInput');
  const preview = document.getElementById('quickAddPreview');
  const chips = document.getElementById('quickAddChips');
  const text = input.value.trim();
  if (!text) { preview.classList.add('hidden'); return; }
  const parsed = parseNaturalLanguage(text);
  let chipHtml = `<span class="qa-chip qa-chip-title">📝 ${escapeHtml(parsed.title)}</span>`;
  if (parsed.dueDate) chipHtml += `<span class="qa-chip qa-chip-date">📅 ${formatDate(parsed.dueDate)}</span>`;
  chipHtml += `<span class="qa-chip qa-chip-priority ${parsed.priority}">${parsed.priority === 'high' ? '🔴' : parsed.priority === 'medium' ? '🟠' : '🟢'} ${capitalize(parsed.priority)}</span>`;
  for (const tag of parsed.tags) {
    const existingTag = data.tags.find(t => t.name.toLowerCase() === tag);
    const color = existingTag ? existingTag.color : 'var(--primary)';
    chipHtml += `<span class="qa-chip qa-chip-tag" style="--tag-color:${color}">#${escapeHtml(tag)}</span>`;
  }
  chips.innerHTML = chipHtml;
  preview.classList.remove('hidden');
}
function quickAddTodo() {
  const input = document.getElementById('quickAddInput');
  const text = input.value.trim();
  if (!text) return;
  const parsed = parseNaturalLanguage(text);
  // Resolve tags - create new ones if they don't exist
  const tagIds = [];
  for (const tagName of parsed.tags) {
    let existing = data.tags.find(t => t.name.toLowerCase() === tagName);
    if (!existing) {
      existing = { id: data.nextTagId++, name: tagName, color: COLORS[data.tags.length % COLORS.length] };
      data.tags.push(existing);
    }
    tagIds.push(existing.id);
  }
  data.todos.push({
    id: data.nextTodoId++, title: parsed.title, description: '', completed: false,
    priority: parsed.priority, dueDate: parsed.dueDate, tagIds, pinned: false,
    subtasks: [], recurring: { type: 'none', interval: 1 }, reminderAt: null,
    reminderFired: false, createdAt: Date.now(), updatedAt: Date.now(), status: 'todo',
  });
  input.value = '';
  document.getElementById('quickAddPreview').classList.add('hidden');
  persist(); renderAll();
  showToast(`"${parsed.title}" added ✨`, '⚡');
}

// --- Actions ---
function toggleTodo(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  todo.completed = !todo.completed;
  todo.updatedAt = Date.now();
  persist(); renderAll();
  showToast(todo.completed ? `"${todo.title}" done!` : `"${todo.title}" reopened`, todo.completed ? '✅' : '🔄');
}

function togglePin(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  todo.pinned = !todo.pinned;
  persist(); renderTodos();
  showToast(todo.pinned ? `Pinned 📌` : `Unpinned`, '📌');
}

async function deleteTodo(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  const result = await window.api.confirmDelete(`Delete "${todo.title}"?`);
  if (result === 1) {
    const deleted = { ...todo };
    data.todos = data.todos.filter(t => t.id !== id);
    data.deletedTodos.unshift(deleted);
    if (data.deletedTodos.length > 5) data.deletedTodos.pop();
    persist(); renderAll();
    showToast(`"${todo.title}" deleted`, '🗑️', 4000, () => {
      data.todos.unshift(data.deletedTodos.shift());
      persist(); renderAll();
    });
  }
}

async function clearCompleted() {
  const count = data.todos.filter(t => t.completed).length;
  if (count === 0) return;
  const result = await window.api.confirmDelete(`Delete ${count} completed todos?`);
  if (result === 1) {
    const cleared = data.todos.filter(t => t.completed);
    data.todos = data.todos.filter(t => !t.completed);
    data.deletedTodos.unshift(...cleared);
    if (data.deletedTodos.length > 10) data.deletedTodos = data.deletedTodos.slice(0, 10);
    persist(); renderAll();
    showToast(`${count} todos cleared`, '🧹');
  }
}

function editTodo(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  if (multiSelectMode) { showToast('Exit multi-select mode to edit', '⚠️'); return; }
  editingTodoId = id;
  document.getElementById('modalTitle').textContent = '📝 Edit Todo';
  document.getElementById('saveBtn').textContent = '💾 Update';
  document.getElementById('todoTitle').value = todo.title;
  document.getElementById('todoDesc').value = todo.description || '';
  document.getElementById('todoDueDate').value = todo.dueDate || '';
  document.getElementById('todoPinned').checked = todo.pinned || false;

  selectedPriority = todo.priority;
  updatePriorityButtons();

  // Reminder
  const hasReminder = !!todo.reminderAt;
  document.getElementById('todoReminder').checked = hasReminder;
  document.getElementById('todoReminderTime').classList.toggle('hidden', !hasReminder);
  if (todo.reminderAt) {
    const d = new Date(todo.reminderAt);
    document.getElementById('todoReminderTime').value = d.toISOString().slice(0, 16);
    document.getElementById('reminderLabel').textContent = `Reminder: ${d.toLocaleString()}`;
  } else {
    document.getElementById('reminderLabel').textContent = 'No reminder set';
  }

  // Tags
  document.querySelectorAll('.tag-option').forEach(el => {
    const tid = parseInt(el.dataset.tagId);
    el.classList.toggle('selected', (todo.tagIds || []).includes(tid));
  });

  openModal('modal');
}

function openAddModal() {
  editingTodoId = null;
  document.getElementById('modalTitle').textContent = '✨ New Todo';
  document.getElementById('saveBtn').textContent = '➕ Add Todo';
  document.getElementById('todoTitle').value = '';
  document.getElementById('todoDesc').value = '';
  document.getElementById('todoDueDate').value = '';
  document.getElementById('todoPinned').checked = false;
  document.getElementById('todoReminder').checked = false;
  document.getElementById('todoReminderTime').classList.add('hidden');
  document.getElementById('reminderLabel').textContent = 'No reminder set';
  selectedPriority = 'medium';
  updatePriorityButtons();
  document.querySelectorAll('.tag-option').forEach(el => el.classList.remove('selected'));
  openModal('modal');
}

function openModal(id) { document.getElementById(id).classList.remove('hidden'); setTimeout(() => document.getElementById('todoTitle').focus(), 150); }
function closeModal() { document.getElementById('modal').classList.add('hidden'); editingTodoId = null; }
function closeTagModal() { document.getElementById('tagModal').classList.add('hidden'); }

function saveTodo() {
  const title = document.getElementById('todoTitle').value.trim();
  if (!title) {
    document.getElementById('todoTitle').style.borderColor = 'var(--error)';
    setTimeout(() => document.getElementById('todoTitle').style.borderColor = '', 1000);
    return;
  }
  const description = document.getElementById('todoDesc').value.trim();
  const dueDate = document.getElementById('todoDueDate').value || null;
  const pinned = document.getElementById('todoPinned').checked;
  const tagIds = Array.from(document.querySelectorAll('.tag-option.selected')).map(el => parseInt(el.dataset.tagId));

  const recurring = { type: 'none', interval: 1, endDate: null };

  // Reminder
  let reminderAt = null;
  if (document.getElementById('todoReminder').checked) {
    const rt = document.getElementById('todoReminderTime').value;
    if (rt) reminderAt = new Date(rt).getTime();
  }

  if (editingTodoId) {
    const todo = data.todos.find(t => t.id === editingTodoId);
    if (todo) {
      Object.assign(todo, {
        title, description, priority: selectedPriority, dueDate, tagIds, pinned,
        subtasks: [], recurring, reminderAt,
        reminderFired: false, updatedAt: Date.now()
      });
      showToast(`"${title}" updated`, '💾');
    }
  } else {
    data.todos.push({
      id: data.nextTodoId++, title, description, completed: false,
      priority: selectedPriority, dueDate, tagIds, pinned,        subtasks: [], recurring, reminderAt,
      reminderFired: false, createdAt: Date.now(), updatedAt: Date.now(),
    });
    showToast(`"${title}" added`, '✨');
  }
  persist(); renderAll(); closeModal();
}



// --- Multi-select ---
function toggleMultiSelect() {
  multiSelectMode = !multiSelectMode;
  selectedIds.clear();
  document.getElementById('multiSelectBar').classList.toggle('hidden', !multiSelectMode);
  document.getElementById('multiSelectBtn').classList.toggle('active', multiSelectMode);
  renderTodos();
}
function toggleSelect(id) {
  if (selectedIds.has(id)) selectedIds.delete(id); else selectedIds.add(id);
  document.getElementById('selectedCount').textContent = `${selectedIds.size} selected`;
  renderTodos();
}
function bulkClearSelection() { multiSelectMode = false; selectedIds.clear(); document.getElementById('multiSelectBar').classList.add('hidden'); renderTodos(); }
function bulkComplete() {
  for (const id of selectedIds) { const t = data.todos.find(x => x.id === id); if (t) { t.completed = true; t.updatedAt = Date.now(); } }
  showToast(`${selectedIds.size} todos completed`, '✅');
  bulkClearSelection(); persist(); renderAll();
}
async function bulkDelete() {
  const result = await window.api.confirmDelete(`Delete ${selectedIds.size} todos?`);
  if (result === 1) {
    const deleted = data.todos.filter(t => selectedIds.has(t.id));
    data.todos = data.todos.filter(t => !selectedIds.has(t.id));
    data.deletedTodos.unshift(...deleted);
    if (data.deletedTodos.length > 10) data.deletedTodos = data.deletedTodos.slice(0, 10);
    const count = selectedIds.size;
    bulkClearSelection();
    persist(); renderAll();
    showToast(`${count} todos deleted`, '🗑️', 4000, () => {
      data.todos.unshift(...data.deletedTodos.splice(0, deleted.length));
      persist(); renderAll();
    });
  }
}

// --- Tags ---
function renderTagSelector() {
  const container = document.getElementById('tagSelector');
  if (!data.tags.length) { container.innerHTML = '<p style="color:var(--text-muted);font-size:13px;">No tags yet. Create in 🏷️</p>'; return; }
  const selectedTagEls = document.querySelectorAll('.tag-option.selected');
  const curTagIds = new Set();
  selectedTagEls.forEach(el => curTagIds.add(parseInt(el.dataset.tagId)));
  container.innerHTML = data.tags.map(t => {
    const isSelected = curTagIds.has(t.id);
    return `<div class="tag-option ${isSelected ? 'selected' : ''}" data-tag-id="${t.id}" onclick="toggleTagOption(this)">
      <span class="tag-option-dot" style="background:${t.color}"></span>${escapeHtml(t.name)}</div>`;
  }).join('');
}
function renderTagList() {
  const container = document.getElementById('tagList');
  container.innerHTML = data.tags.length === 0 ? '<p style="color:var(--text-muted);text-align:center;padding:20px;">No tags yet</p>'
    : data.tags.map(t => `<div class="cat-item">
        <span class="tag-dot" style="background:${t.color};width:14px;height:14px;border-radius:50%;display:inline-block;"></span>
        <span class="cat-name">${escapeHtml(t.name)}</span>
        <button class="todo-action-btn delete" onclick="deleteTag(${t.id})" title="Delete">🗑️</button>
      </div>`).join('');
}
function renderColorPicker() {
  const container = document.getElementById('tagColorPicker');
  if (!container) return;
  container.innerHTML = COLORS.map(c => `<div class="color-dot ${c === selectedTagColor ? 'selected' : ''}" style="background:${c}" onclick="selectTagColor('${c}')"></div>`).join('');
}
function toggleTagOption(el) { el.classList.toggle('selected'); }
function selectTagColor(color) { selectedTagColor = color; renderColorPicker(); }
function addTag() {
  const name = document.getElementById('tagName').value.trim();
  if (!name) return;
  data.tags.push({ id: data.nextTagId++, name, color: selectedTagColor });
  document.getElementById('tagName').value = '';
  selectedTagColor = COLORS[0];
  renderColorPicker(); renderTagList(); renderTagSelector(); persist();
  showToast(`Tag "${name}" created`, '🏷️');
}
async function deleteTag(id) {
  const tag = data.tags.find(t => t.id === id);
  if (!tag) return;
  const result = await window.api.confirmDelete(`Delete tag "${tag.name}"?`);
  if (result === 1) {
    data.tags = data.tags.filter(t => t.id !== id);
    data.todos.forEach(t => { if (t.tagIds) t.tagIds = t.tagIds.filter(tid => tid !== id); });
    renderTagList(); renderTagSelector(); renderTodos(); persist();
  }
}
function openTagModal() { document.getElementById('tagModal').classList.remove('hidden'); renderColorPicker(); renderTagList(); }
function updatePriorityButtons() {
  document.querySelectorAll('.priority-btn').forEach(btn => btn.classList.toggle('active', btn.dataset.priority === selectedPriority));
}

// --- Utils ---
function escapeHtml(text) { const div = document.createElement('div'); div.textContent = String(text); return div.innerHTML; }
function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function formatDate(dateStr) { const d = new Date(dateStr + 'T00:00:00'); return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
function setQuickDate(offset) { const d = new Date(); d.setDate(d.getDate() + offset); document.getElementById('todoDueDate').value = d.toISOString().split('T')[0]; }

// --- Events ---
function bindEvents() {
  document.getElementById('addBtn').addEventListener('click', (e) => { e.stopPropagation(); toggleSpeedDial(); });
  document.getElementById('saveBtn').addEventListener('click', saveTodo);
  document.getElementById('themeToggle').addEventListener('click', toggleTheme);
  document.getElementById('pipBtn').addEventListener('click', pipToggle);
  document.getElementById('pomoFloatBtn').addEventListener('click', pomodoroToggle);
  document.getElementById('clearCompleted').addEventListener('click', clearCompleted);
  document.getElementById('manageTags').addEventListener('click', openTagModal);
  document.getElementById('settingsBtn').addEventListener('click', openSettings);
  document.getElementById('addTagBtn').addEventListener('click', addTag);
  document.getElementById('multiSelectBtn').addEventListener('click', toggleMultiSelect);
  document.getElementById('pomodoroBtn').addEventListener('click', openPomodoro);
  document.getElementById('saveSmartListBtn').addEventListener('click', saveCurrentViewAsSmartList);
  document.getElementById('quickAddBtn').addEventListener('click', quickAddTodo);
  document.getElementById('quickAddInput').addEventListener('input', updateQuickAddPreview);
  document.getElementById('quickAddInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); quickAddTodo(); } });
  document.getElementById('viewToggle').addEventListener('click', cycleView);

  document.getElementById('clearDate').addEventListener('click', () => { document.getElementById('todoDueDate').value = ''; });
  document.getElementById('clearSearch').addEventListener('click', () => {
    document.getElementById('searchInput').value = '';
    searchQuery = '';
    document.getElementById('clearSearch').classList.add('hidden');
    renderTodos();
  });

  document.getElementById('searchInput').addEventListener('input', (e) => {
    searchQuery = e.target.value;
    document.getElementById('clearSearch').classList.toggle('hidden', !searchQuery);
    renderTodos();
  });


  document.getElementById('todoReminder').addEventListener('change', function () {
    document.getElementById('todoReminderTime').classList.toggle('hidden', !this.checked);
    document.getElementById('reminderLabel').textContent = this.checked ? 'Set reminder time' : 'No reminder set';
  });
  document.getElementById('todoReminderTime').addEventListener('change', function () {
    if (this.value) {
      document.getElementById('reminderLabel').textContent = `Reminder: ${new Date(this.value).toLocaleString()}`;
    }
  });

  document.querySelectorAll('.filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      currentFilter = chip.dataset.filter;
      renderTodos();
    });
  });

  document.querySelectorAll('.priority-btn').forEach(btn => {
    btn.addEventListener('click', () => { selectedPriority = btn.dataset.priority; updatePriorityButtons(); });
  });

  document.querySelectorAll('.quick-date-btn').forEach(btn => {
    btn.addEventListener('click', () => setQuickDate(parseInt(btn.dataset.offset)));
  });

  document.getElementById('tagName').addEventListener('keydown', (e) => { if (e.key === 'Enter') addTag(); });
  document.getElementById('todoTitle').addEventListener('keydown', (e) => { if (e.key === 'Enter') saveTodo(); });
  });

  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', () => overlay.parentElement.classList.add('hidden'));
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeSpeedDial();
      document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    }
    if ((e.key === 'n' || e.key === 'N') && !e.target.matches('input, textarea, select')) { e.preventDefault(); toggleSpeedDial(); }
    if (e.key === '/' && !e.target.matches('input, textarea, select')) { e.preventDefault(); document.getElementById('searchInput').focus(); }
    if ((e.key === 'v' || e.key === 'V') && !e.target.matches('input, textarea, select')) { e.preventDefault(); cycleView(); }
  });
}

// Global
window.toggleSpeedDial = toggleSpeedDial; window.closeSpeedDial = closeSpeedDial;
window.toggleTodo = toggleTodo; window.togglePin = togglePin; window.deleteTodo = deleteTodo;
window.editTodo = editTodo; window.closeModal = closeModal; window.closeTagModal = closeTagModal;
window.selectTagColor = selectTagColor; window.deleteTag = deleteTag;
window.toggleTagOption = toggleTagOption; window.toggleSelect = toggleSelect;
window.bulkComplete = bulkComplete; window.bulkDelete = bulkDelete; window.bulkClearSelection = bulkClearSelection;

window.richBold = richBold; window.richItalic = richItalic; window.richUnderline = richUnderline; window.richList = richList;
window.richCode = richCode; window.richCheckbox = richCheckbox; window.toggleMdPreview = toggleMdPreview; window.onDescInput = onDescInput;
window.calPrev = calPrev; window.calNext = calNext; window.selectCalDay = selectCalDay;
window.closePomodoro = closePomodoro; window.pomoToggle = pomoToggle; window.pomoReset = pomoReset; window.pomoSkip = pomoSkip;
window.applySmartList = applySmartList; window.deleteSmartList = deleteSmartList;
window.initDragDrop = initDragDrop;
window.cycleView = cycleView;
window.openSettings = openSettings; window.closeSettings = closeSettings;
window.manualCheckUpdates = manualCheckUpdates;
window.startUpdateDownload = startUpdateDownload;
window.quitAndInstall = quitAndInstall;

// --- Settings & Updates ---
function openSettings() {
  document.getElementById('settingsModal').classList.remove('hidden');
  // Show the update animation when settings opens
  showUpdateAnimation(true);
  // Refresh update status from main process (handles case where
  // state changed since startup — e.g., another auto-check completed)
  if (typeof window.api.getUpdateStatus === 'function') {
    window.api.getUpdateStatus().then((state) => {
      if (state) { _updateState = state; refreshUpdateUI(); }
    }).catch(() => refreshUpdateUI());
  } else {
    refreshUpdateUI();
  }
}

function closeSettings() {
  document.getElementById('settingsModal').classList.add('hidden');
  // Hide animation when settings closes
  showUpdateAnimation(false);
}
let _updateState = { status: 'idle', info: null, progress: null, error: null };

// Initialize the update animation (CSS-only cat crying fallback — no external deps needed)
function initUpdateAnimation() {
  const container = document.getElementById('lottieAnimation');
  if (!container) return;
  container.innerHTML = '<div class="cat-crying-fallback" title="Cat crying emoji — check for updates">'
    + '😿'
    + '<span class="tear left">💧</span>'
    + '<span class="tear right">💧</span>'
    + '<span class="tear" style="left:16px;animation-delay:0.8s;animation-duration:1.1s;">💧</span>'
    + '</div>';
}

// Show/hide the update animation
function showUpdateAnimation(show) {
  const wrap = document.getElementById('updateAnimationWrap');
  if (!wrap) return;
  wrap.classList.toggle('hidden', !show);
}

function setupUpdateListeners() {
  if (typeof window.api.onUpdateStatus === 'function') {
    window.api.onUpdateStatus((state) => {
      _updateState = state;
      refreshUpdateUI();
      // Show toast for significant events
      if (state.status === 'available') {
        showToast('Update v' + (state.info?.version || '?') + ' available! Open Settings to download', '📦');
      } else if (state.status === 'not-available') {
        // Silent — only show in settings panel
      } else if (state.status === 'downloaded') {
        showToast('Update downloaded! Restart to install', '🚀');
      } else if (state.status === 'error') {
        // Show error only in settings, not on first auto-check
      }
    });
    window.api.onUpdateProgress((progress) => {
      _updateState = { ..._updateState, status: 'downloading', progress };
      refreshUpdateUI();
    });
  }
}

function refreshUpdateUI() {
  const statusText = document.getElementById('updateStatusText');
  const checkBtn = document.getElementById('checkUpdateBtn');
  const downloadBtn = document.getElementById('downloadUpdateBtn');
  const installBtn = document.getElementById('installUpdateBtn');
  const progressWrap = document.getElementById('updateProgressWrap');
  const progressFill = document.getElementById('updateProgressFill');
  const progressText = document.getElementById('updateProgressText');
  if (!statusText) return;

  switch (_updateState.status) {
    case 'idle':
      statusText.textContent = '🔍 Tap "Check for Updates" to check';
      checkBtn.classList.remove('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.add('hidden');
      progressWrap.classList.add('hidden');
      break;
    case 'checking':
      statusText.textContent = '⏳ Checking for updates...';
      checkBtn.classList.add('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.add('hidden');
      progressWrap.classList.add('hidden');
      break;
    case 'available':
      statusText.innerHTML = `📦 <strong>v${_updateState.info?.version || '?'}</strong> available!`;
      checkBtn.classList.add('hidden');
      downloadBtn.classList.remove('hidden');
      installBtn.classList.add('hidden');
      progressWrap.classList.add('hidden');
      break;
    case 'not-available':
      statusText.textContent = '✅ You\'re on the latest version!';
      checkBtn.classList.remove('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.add('hidden');
      progressWrap.classList.add('hidden');
      break;
    case 'downloading':
      if (_updateState.progress) {
        const pct = Math.round(_updateState.progress.percent || 0);
        statusText.textContent = `⬇ Downloading... ${pct}%`;
        progressFill.style.width = pct + '%';
        progressText.textContent = pct + '%';
        progressWrap.classList.remove('hidden');
      } else {
        statusText.textContent = '⬇ Downloading...';
        progressWrap.classList.remove('hidden');
      }
      checkBtn.classList.add('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.add('hidden');
      break;
    case 'downloaded':
      statusText.innerHTML = '✅ <strong>Downloaded!</strong> Restart to install';
      checkBtn.classList.add('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.remove('hidden');
      progressWrap.classList.add('hidden');
      break;
    case 'error':
      statusText.textContent = '⚠ ' + (_updateState.error || 'Update check failed. Check your connection.') + ' — You can try again';
      checkBtn.classList.remove('hidden');
      downloadBtn.classList.add('hidden');
      installBtn.classList.add('hidden');
      progressWrap.classList.add('hidden');
      break;
    default:
      statusText.textContent = 'Update status unknown';
  }
}

async function manualCheckUpdates() {
  if (typeof window.api.checkForUpdates !== 'function') return;
  
  _updateState = { status: 'checking', info: null, progress: null, error: null };
  refreshUpdateUI();
  
  // Safety timeout: if no event fires within 30s, revert to idle/error
  const checkTimeout = setTimeout(() => {
    if (_updateState.status === 'checking') {
      _updateState = { status: 'error', info: null, progress: null, error: 'Update check timed out. Check your internet connection.' };
      refreshUpdateUI();
    }
  }, 30000);
  
  try {
    const ok = await window.api.checkForUpdates();
    clearTimeout(checkTimeout);
    if (!ok && _updateState.status === 'checking') {
      // checkForUpdates() returned false but no error event fired — unlikely but handle it
      _updateState = { status: 'error', info: null, progress: null, error: 'Failed to start update check.' };
      refreshUpdateUI();
    }
  } catch(e) {
    clearTimeout(checkTimeout);
    _updateState = { status: 'error', info: null, progress: null, error: e.message || 'Update check failed.' };
    refreshUpdateUI();
  }
}

async function startUpdateDownload() {
  if (typeof window.api.startDownload !== 'function') return;
  const ok = await window.api.startDownload();
  if (!ok) {
    showToast('Could not start download — update may no longer be available', '⚠️', 4000);
    // Refresh state in case it changed
    if (typeof window.api.getUpdateStatus === 'function') {
      window.api.getUpdateStatus().then((state) => {
        if (state) { _updateState = state; refreshUpdateUI(); }
      }).catch(() => {});
    }
  }
}

function quitAndInstall() {
  if (typeof window.api.quitAndInstall === 'function') {
    window.api.quitAndInstall();
  }
}

init();
