const COLORS = [
  '#E53935', '#FB8C00', '#FDD835', '#43A047', '#1E88E5',
  '#8E24AA', '#FF4081', '#00ACC1', '#6D4C41', '#546E7A', '#6200EE'
];

let data = { todos: [], tags: [], nextTodoId: 1, nextTagId: 1, deletedTodos: [], settings: {} };
let currentFilter = 'all';
let searchQuery = '';
let editingTodoId = null;
let selectedPriority = 'medium';
let selectedTagColor = COLORS[0];
let darkMode = false;
let multiSelectMode = false;
let selectedIds = new Set();
let calendarMode = false;
let calYear, calMonth;
let editingSubtasks = [];

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
  };
  for (const t of data.todos) {
    if (t.tagIds === undefined) t.tagIds = [];
    if (t.pinned === undefined) t.pinned = false;
    if (t.subtasks === undefined) t.subtasks = [];
    if (t.recurring === undefined) t.recurring = { type: 'none', interval: 1 };
    if (t.reminderAt === undefined) t.reminderAt = null;
    if (t.sortOrder === undefined) t.sortOrder = 0;
  }
  const now = new Date();
  calYear = now.getFullYear();
  calMonth = now.getMonth();
  loadTheme();
  renderAll();
  bindEvents();
  initDragDrop();
  checkDueNotifications();
  setInterval(checkDueNotifications, 60000);
}

function loadTheme() { darkMode = localStorage.getItem('darkMode') === 'true'; applyTheme(); }
function applyTheme() {
  document.body.classList.toggle('dark', darkMode);
  document.getElementById('themeToggle').textContent = darkMode ? '☀️' : '🌙';
}
function toggleTheme() { darkMode = !darkMode; localStorage.setItem('darkMode', darkMode); applyTheme(); }
async function persist() { await window.api.saveData(data); }

// --- Notifications ---
function checkDueNotifications() {
  const today = new Date().toISOString().split('T')[0];
  for (const todo of data.todos) {
    if (todo.completed || !todo.dueDate) continue;
    if (todo.dueDate === today) {
      window.api.sendNotification('Todo App', `"${todo.title}" is due today!`);
    } else if (todo.dueDate < today) {
      const overdue = Math.floor((new Date().getTime() - new Date(todo.dueDate).getTime()) / 86400000);
      if (overdue === 1 || overdue % 7 === 0) {
        window.api.sendNotification('Todo App', `"${todo.title}" is ${overdue} day${overdue > 1 ? 's' : ''} overdue!`);
      }
    }
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

// --- Render ---
function renderAll() {
  if (calendarMode) { renderCalendar(); } else { renderTodos(); }
  renderTagSelector(); renderTagList(); updateMeta();
}

function getFilteredTodos() {
  let list = [...data.todos];
  if (searchQuery) {
    const q = searchQuery.toLowerCase();
    list = list.filter(t => t.title.toLowerCase().includes(q) || (t.description && t.description.toLowerCase().includes(q)));
  }
  if (currentFilter === 'pending') list = list.filter(t => !t.completed);
  if (currentFilter === 'done') list = list.filter(t => t.completed);
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
    const desc = todo.description ? `<div class="todo-desc">${escapeHtml(todo.description)}</div>` : '';

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
    const dragHandle = `<span class="drag-handle" draggable="true" data-id="${todo.id}">⠿</span>`;

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

// --- Subtasks ---
function addSubtask() {
  const input = document.getElementById('subtaskInput');
  const title = input.value.trim();
  if (!title) return;
  editingSubtasks.push({ id: Date.now().toString(), title, done: false });
  input.value = '';
  renderSubtaskList();
}
function renderSubtaskList() {
  const el = document.getElementById('subtaskList');
  el.innerHTML = editingSubtasks.map((s, i) => `
    <div class="subtask-item ${s.done ? 'done' : ''}">
      <div class="subtask-check ${s.done ? 'checked' : ''}" onclick="toggleEditSubtask(${i})">${s.done ? '✓' : ''}</div>
      <span class="subtask-title">${escapeHtml(s.title)}</span>
      <button class="subtask-del" onclick="removeEditSubtask(${i})">✕</button>
    </div>`).join('');
}
function toggleEditSubtask(i) { editingSubtasks[i].done = !editingSubtasks[i].done; renderSubtaskList(); }
function removeEditSubtask(i) { editingSubtasks.splice(i, 1); renderSubtaskList(); }

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
  if (!todo || multiSelectMode) return;
  editingTodoId = id;
  document.getElementById('modalTitle').textContent = '📝 Edit Todo';
  document.getElementById('saveBtn').textContent = '💾 Update';
  document.getElementById('todoTitle').value = todo.title;
  document.getElementById('todoDesc').value = todo.description || '';
  document.getElementById('todoDueDate').value = todo.dueDate || '';
  document.getElementById('todoPinned').checked = todo.pinned || false;
  document.getElementById('todoRecurring').value = (todo.recurring && todo.recurring.type) || 'none';
  document.getElementById('recurringInterval').value = (todo.recurring && todo.recurring.interval) || 1;
  toggleRecurringInterval();
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

  // Subtasks
  editingSubtasks = (todo.subtasks || []).map(s => ({ ...s }));
  renderSubtaskList();

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
  document.getElementById('todoRecurring').value = 'none';
  document.getElementById('recurringInterval').value = 1;
  document.getElementById('todoReminder').checked = false;
  document.getElementById('todoReminderTime').classList.add('hidden');
  document.getElementById('reminderLabel').textContent = 'No reminder set';
  toggleRecurringInterval();
  selectedPriority = 'medium';
  updatePriorityButtons();
  document.querySelectorAll('.tag-option').forEach(el => el.classList.remove('selected'));
  editingSubtasks = [];
  renderSubtaskList();
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

  const recurringType = document.getElementById('todoRecurring').value;
  const recurring = { type: recurringType, interval: parseInt(document.getElementById('recurringInterval').value) || 1, endDate: null };

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
        subtasks: [...editingSubtasks], recurring, reminderAt,
        reminderFired: false, updatedAt: Date.now()
      });
      showToast(`"${title}" updated`, '💾');
    }
  } else {
    data.todos.push({
      id: data.nextTodoId++, title, description, completed: false,
      priority: selectedPriority, dueDate, tagIds, pinned,
      subtasks: [...editingSubtasks], recurring, reminderAt,
      reminderFired: false, createdAt: Date.now(), updatedAt: Date.now(),
    });
    showToast(`"${title}" added`, '✨');
  }
  persist(); renderAll(); closeModal();
}

function toggleRecurringInterval() {
  const v = document.getElementById('todoRecurring').value;
  document.getElementById('recurringIntervalWrap').classList.toggle('hidden', v === 'none');
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
    data.todos = data.todos.filter(t => !selectedIds.has(t.id));
    showToast(`${selectedIds.size} todos deleted`, '🗑️');
    bulkClearSelection(); persist(); renderAll();
  }
}

// --- Tags ---
function renderTagSelector() {
  const container = document.getElementById('tagSelector');
  if (!data.tags.length) { container.innerHTML = '<p style="color:var(--text-muted);font-size:13px;">No tags yet. Create in 🏷️</p>'; return; }
  container.innerHTML = data.tags.map(t => {
    const isSelected = document.querySelector(`.tag-option[data-tag-id="${t.id}"]`)?.classList.contains('selected');
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
function escapeHtml(text) { const div = document.createElement('div'); div.textContent = text; return div.innerHTML; }
function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function formatDate(dateStr) { const d = new Date(dateStr + 'T00:00:00'); return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
function setQuickDate(offset) { const d = new Date(); d.setDate(d.getDate() + offset); document.getElementById('todoDueDate').value = d.toISOString().split('T')[0]; }

// --- Events ---
function bindEvents() {
  document.getElementById('addBtn').addEventListener('click', openAddModal);
  document.getElementById('saveBtn').addEventListener('click', saveTodo);
  document.getElementById('themeToggle').addEventListener('click', toggleTheme);
  document.getElementById('clearCompleted').addEventListener('click', clearCompleted);
  document.getElementById('manageTags').addEventListener('click', openTagModal);
  document.getElementById('addTagBtn').addEventListener('click', addTag);
  document.getElementById('multiSelectBtn').addEventListener('click', toggleMultiSelect);
  document.getElementById('pomodoroBtn').addEventListener('click', openPomodoro);

  document.getElementById('viewToggle').addEventListener('click', () => {
    calendarMode = !calendarMode;
    document.getElementById('viewToggle').textContent = calendarMode ? '📋' : '📅';
    renderAll();
  });

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

  document.getElementById('todoRecurring').addEventListener('change', toggleRecurringInterval);
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

  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', () => overlay.parentElement.classList.add('hidden'));
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    }
    if ((e.key === 'n' || e.key === 'N') && !e.target.matches('input, textarea, select')) { e.preventDefault(); openAddModal(); }
    if (e.key === '/' && !e.target.matches('input, textarea, select')) { e.preventDefault(); document.getElementById('searchInput').focus(); }
    if (e.key === 'c' && !e.target.matches('input, textarea, select')) { calendarMode = !calendarMode; document.getElementById('viewToggle').textContent = calendarMode ? '📋' : '📅'; renderAll(); }
  });
}

// Global
window.toggleTodo = toggleTodo; window.togglePin = togglePin; window.deleteTodo = deleteTodo;
window.editTodo = editTodo; window.closeModal = closeModal; window.closeTagModal = closeTagModal;
window.selectTagColor = selectTagColor; window.deleteTag = deleteTag;
window.toggleTagOption = toggleTagOption; window.toggleSelect = toggleSelect;
window.bulkComplete = bulkComplete; window.bulkDelete = bulkDelete; window.bulkClearSelection = bulkClearSelection;
window.addSubtask = addSubtask; window.toggleEditSubtask = toggleEditSubtask; window.removeEditSubtask = removeEditSubtask;
window.richBold = richBold; window.richItalic = richItalic; window.richUnderline = richUnderline; window.richList = richList;
window.calPrev = calPrev; window.calNext = calNext; window.selectCalDay = selectCalDay;
window.closePomodoro = closePomodoro; window.pomoToggle = pomoToggle; window.pomoReset = pomoReset; window.pomoSkip = pomoSkip;
window.initDragDrop = initDragDrop;

init();
