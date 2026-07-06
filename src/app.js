const COLORS = [
  '#E53935', '#FB8C00', '#FDD835', '#43A047', '#1E88E5',
  '#8E24AA', '#FF4081', '#00ACC1', '#6D4C41', '#546E7A', '#6200EE'
];

let data = {
  todos: [], tags: [], nextTodoId: 1, nextTagId: 1, deletedTodos: []
};
let currentFilter = 'all';
let searchQuery = '';
let editingTodoId = null;
let selectedPriority = 'medium';
let selectedTagColor = COLORS[0];
let darkMode = false;
let advSearchOpen = false;
let advFilters = { dateFrom: null, dateTo: null, priorities: ['high','medium','low'], tags: [] };

// --- Init ---
async function init() {
  const raw = await window.api.getData();
  data = {
    todos: raw.todos || [],
    tags: raw.tags || [],
    nextTodoId: raw.nextTodoId || 1,
    nextTagId: raw.nextTagId || 1,
    deletedTodos: raw.deletedTodos || [],
  };
  // Migrate old categoryId -> tags
  for (const t of data.todos) {
    if (t.categoryId != null && (!t.tagIds || t.tagIds.length === 0)) {
      t.tagIds = [t.categoryId];
      delete t.categoryId;
    }
    if (t.pinned === undefined) t.pinned = false;
    if (!t.tagIds) t.tagIds = [];
  }
  loadTheme();
  renderAll();
  bindEvents();
  checkDueNotifications();
}

function loadTheme() {
  darkMode = localStorage.getItem('darkMode') === 'true';
  applyTheme();
}

function applyTheme() {
  document.body.classList.toggle('dark', darkMode);
  document.getElementById('themeToggle').textContent = darkMode ? '☀️' : '🌙';
}

function toggleTheme() {
  darkMode = !darkMode;
  localStorage.setItem('darkMode', darkMode);
  applyTheme();
}

async function persist() {
  await window.api.saveData(data);
}

// --- Notifications ---
function checkDueNotifications() {
  const today = new Date().toISOString().split('T')[0];
  for (const todo of data.todos) {
    if (todo.completed || !todo.dueDate) continue;
    if (todo.dueDate === today) {
      window.api.sendNotification('Todo App', `📅 "${todo.title}" is due today!`);
    } else if (todo.dueDate < today) {
      const overdue = Math.floor(
        (new Date().getTime() - new Date(todo.dueDate).getTime()) / 86400000
      );
      if (overdue === 1 || overdue % 7 === 0) {
        window.api.sendNotification('Todo App',
          `⚠️ "${todo.title}" is ${overdue} day${overdue > 1 ? 's' : ''} overdue!`);
      }
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
    undoBtn.onclick = () => {
      undoCallback();
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    };
    toast.appendChild(undoBtn);
    toast.style.animation = `toastIn 0.3s ease, toastOut 0.3s ease ${duration}ms forwards`;
  }

  container.appendChild(toast);
  setTimeout(() => {
    if (toast.parentNode) toast.parentNode.removeChild(toast);
  }, duration + 300);
}

// --- Render ---
function renderAll() {
  renderTodos();
  renderTagSelector();
  renderTagList();
  renderAdvTagFilters();
  updateMeta();
}

function getFilteredTodos() {
  let list = [...data.todos];

  // Text search
  if (searchQuery) {
    const q = searchQuery.toLowerCase();
    list = list.filter(t =>
      t.title.toLowerCase().includes(q) ||
      (t.description && t.description.toLowerCase().includes(q))
    );
  }

  // Status filter
  if (currentFilter === 'pending') list = list.filter(t => !t.completed);
  if (currentFilter === 'done') list = list.filter(t => t.completed);

  // Advanced search: date range
  if (advFilters.dateFrom) {
    list = list.filter(t => t.dueDate && t.dueDate >= advFilters.dateFrom);
  }
  if (advFilters.dateTo) {
    list = list.filter(t => t.dueDate && t.dueDate <= advFilters.dateTo);
  }

  // Advanced search: priority
  list = list.filter(t => advFilters.priorities.includes(t.priority));

  // Advanced search: tags (if any selected, todo must match at least one)
  if (advFilters.tags.length > 0) {
    list = list.filter(t =>
      t.tagIds && t.tagIds.some(tid => advFilters.tags.includes(tid))
    );
  }

  // Sort
  list.sort((a, b) => {
    // Pinned first
    if (!!a.pinned !== !!b.pinned) return a.pinned ? -1 : 1;
    // Then by completion
    if (a.completed !== b.completed) return a.completed ? 1 : -1;
    // Then by priority
    const pOrder = { high: 0, medium: 1, low: 2 };
    if (pOrder[a.priority] !== pOrder[b.priority]) return pOrder[a.priority] - pOrder[b.priority];
    // Then by due date
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

  if (list.length === 0) {
    container.innerHTML = '';
    empty.classList.remove('hidden');
    if (searchQuery) {
      document.getElementById('emptyTitle').textContent = 'No results found';
      document.getElementById('emptySubtitle').textContent = 'Try a different search or clear filters';
    } else {
      document.getElementById('emptyTitle').textContent = 'No todos yet';
      document.getElementById('emptySubtitle').textContent = 'Click + to add your first todo';
    }
    return;
  }
  empty.classList.add('hidden');

  container.innerHTML = list.map((todo, idx) => {
    const pinnedClass = todo.pinned ? 'pinned' : '';
    const pinIcon = todo.pinned ? '📌' : '📍';

    // Tags
    const todoTags = (todo.tagIds || [])
      .map(id => data.tags.find(t => t.id === id))
      .filter(Boolean);
    const tagDots = todoTags.slice(0, 4).map(t =>
      `<span class="tag-dot" style="background:${t.color}"></span>`
    ).join('');
    const moreTag = todoTags.length > 4
      ? `<span class="tag-dot more">+${todoTags.length - 4}</span>`
      : '';
    const tagDotsHtml = (tagDots || moreTag)
      ? `<div class="tag-dots">${tagDots}${moreTag}</div>`
      : '';

    // Tag badges row
    const tagBadges = todoTags.map(t =>
      `<span class="todo-tag-badge" style="background:${t.color}">${escapeHtml(t.name)}</span>`
    ).join('');
    const tagRow = tagBadges ? `<div class="todo-tags-row">${tagBadges}</div>` : '';

    const desc = todo.description
      ? `<div class="todo-desc">${escapeHtml(todo.description)}</div>` : '';

    let dueHtml = '';
    if (todo.dueDate) {
      const due = new Date(todo.dueDate + 'T23:59:59');
      const isOverdue = due < new Date() && !todo.completed;
      dueHtml = `<div class="todo-due ${isOverdue ? 'overdue' : 'normal'}">📅 ${formatDate(todo.dueDate)}</div>`;
    }

    return `
      <div class="todo-card ${todo.completed ? 'completed' : ''} ${pinnedClass}" data-id="${todo.id}" style="animation-delay:${idx * 40}ms">
        <div class="todo-row1">
          <span class="pin-icon ${todo.pinned ? 'pinned' : ''}" onclick="event.stopPropagation();togglePin(${todo.id})" title="${todo.pinned ? 'Unpin' : 'Pin to top'}">${pinIcon}</span>
          <div class="todo-checkbox ${todo.completed ? 'checked' : ''}" onclick="toggleTodo(${todo.id})"></div>
          ${tagDotsHtml}
          <span class="todo-title" onclick="editTodo(${todo.id})">${escapeHtml(todo.title)}</span>
          <span class="priority-badge priority-${todo.priority}">${capitalize(todo.priority)}</span>
          <div class="todo-actions">
            <button class="todo-action-btn" onclick="editTodo(${todo.id})" title="Edit">✏️</button>
            <button class="todo-action-btn delete" onclick="deleteTodo(${todo.id})" title="Delete">🗑️</button>
          </div>
        </div>
        ${tagRow}
        ${desc}
        ${dueHtml}
      </div>
    `;
  }).join('');
}

function renderTagSelector() {
  const container = document.getElementById('tagSelector');
  if (!data.tags.length) {
    container.innerHTML = '<p style="color:var(--text-muted);font-size:13px;">No tags yet. Create tags in the tags manager 🏷️</p>';
    return;
  }
  const selected = document.getElementById('editTagIds');
  const selectedIds = selected ? selected.value.split(',').filter(Boolean).map(Number) : [];

  container.innerHTML = data.tags.map(t => {
    const isSelected = selectedIds.includes(t.id);
    return `<div class="tag-option ${isSelected ? 'selected' : ''}" data-tag-id="${t.id}" onclick="toggleTagOption(this)">
      <span class="tag-option-dot" style="background:${t.color}"></span>
      ${escapeHtml(t.name)}
    </div>`;
  }).join('');
}

function renderTagList() {
  const container = document.getElementById('tagList');
  if (!data.tags.length) {
    container.innerHTML = '<p style="color:var(--text-muted);text-align:center;padding:20px;">No tags yet</p>';
    return;
  }
  container.innerHTML = data.tags.map(t => `
    <div class="cat-item">
      <span class="tag-dot" style="background:${t.color};width:14px;height:14px;border-radius:50%;display:inline-block;"></span>
      <span class="cat-name">${escapeHtml(t.name)}</span>
      <button class="todo-action-btn delete" onclick="deleteTag(${t.id})" title="Delete">🗑️</button>
    </div>
  `).join('');
}

function renderAdvTagFilters() {
  const container = document.getElementById('advTagFilters');
  if (!data.tags.length) {
    container.innerHTML = '<span style="font-size:12px;color:var(--text-muted)">No tags</span>';
    return;
  }
  container.innerHTML = data.tags.map(t => {
    const active = advFilters.tags.includes(t.id) ? 'active' : '';
    return `<span class="adv-tag-chip ${active}" data-tag-id="${t.id}" onclick="toggleAdvTagFilter(this)">${escapeHtml(t.name)}</span>`;
  }).join('');
}

function renderColorPicker() {
  const container = document.getElementById('tagColorPicker');
  if (!container) return;
  container.innerHTML = COLORS.map(c =>
    `<div class="color-dot ${c === selectedTagColor ? 'selected' : ''}" style="background:${c}" onclick="selectTagColor('${c}')"></div>`
  ).join('');
}

// --- Actions ---
function toggleTodo(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  todo.completed = !todo.completed;
  persist();
  renderTodos();
  updateMeta();
  showToast(todo.completed ? `"${todo.title}" done!` : `"${todo.title}" reopened`, todo.completed ? '✅' : '🔄');
}

function togglePin(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  todo.pinned = !todo.pinned;
  persist();
  renderTodos();
  showToast(todo.pinned ? `"${todo.title}" pinned 📌` : `"${todo.title}" unpinned`, '📌');
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
    persist();
    renderTodos();
    updateMeta();
    showToast(`"${todo.title}" deleted`, '🗑️', 4000, () => {
      data.todos.unshift(data.deletedTodos.shift());
      persist();
      renderTodos();
      updateMeta();
      showToast(`"${deleted.title}" restored`, '↩️');
    });
  }
}

async function clearCompleted() {
  const count = data.todos.filter(t => t.completed).length;
  if (count === 0) return;
  const result = await window.api.confirmDelete(`Delete ${count} completed ${count === 1 ? 'todo' : 'todos'}?`);
  if (result === 1) {
    const cleared = data.todos.filter(t => t.completed);
    data.todos = data.todos.filter(t => !t.completed);
    data.deletedTodos.unshift(...cleared);
    if (data.deletedTodos.length > 10) data.deletedTodos = data.deletedTodos.slice(0, 10);
    persist();
    renderTodos();
    updateMeta();
    showToast(`${count} ${count === 1 ? 'todo' : 'todos'} cleared`, '🧹', 4000, () => {
      data.todos.push(...data.deletedTodos.splice(0, cleared.length));
      persist();
      renderTodos();
      updateMeta();
      showToast(`${count} ${count === 1 ? 'todo' : 'todos'} restored`, '↩️');
    });
  }
}

function editTodo(id) {
  const todo = data.todos.find(t => t.id === id);
  if (!todo) return;
  editingTodoId = id;
  document.getElementById('modalTitle').textContent = '📝 Edit Todo';
  document.getElementById('saveBtn').textContent = '💾 Update';
  document.getElementById('todoTitle').value = todo.title;
  document.getElementById('todoDesc').value = todo.description || '';
  document.getElementById('todoDueDate').value = todo.dueDate || '';
  document.getElementById('todoPinned').checked = todo.pinned || false;
  selectedPriority = todo.priority;
  updatePriorityButtons();

  // Set selected tags
  const tagOptions = document.querySelectorAll('.tag-option');
  tagOptions.forEach(el => {
    const tid = parseInt(el.dataset.tagId);
    const isSelected = (todo.tagIds || []).includes(tid);
    el.classList.toggle('selected', isSelected);
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
  selectedPriority = 'medium';
  updatePriorityButtons();
  document.querySelectorAll('.tag-option').forEach(el => el.classList.remove('selected'));
  openModal('modal');
}

function openModal(id) {
  document.getElementById(id).classList.remove('hidden');
  setTimeout(() => document.getElementById('todoTitle').focus(), 150);
}

function closeModal() {
  document.getElementById('modal').classList.add('hidden');
  editingTodoId = null;
}

function closeTagModal() {
  document.getElementById('tagModal').classList.add('hidden');
}

function saveTodo() {
  const title = document.getElementById('todoTitle').value.trim();
  if (!title) {
    document.getElementById('todoTitle').focus();
    document.getElementById('todoTitle').style.borderColor = 'var(--error)';
    setTimeout(() => document.getElementById('todoTitle').style.borderColor = '', 1000);
    return;
  }
  const description = document.getElementById('todoDesc').value.trim();
  const dueDate = document.getElementById('todoDueDate').value || null;
  const pinned = document.getElementById('todoPinned').checked;

  // Get selected tag IDs from DOM
  const tagIds = Array.from(document.querySelectorAll('.tag-option.selected'))
    .map(el => parseInt(el.dataset.tagId));

  if (editingTodoId) {
    const todo = data.todos.find(t => t.id === editingTodoId);
    if (todo) {
      Object.assign(todo, {
        title, description, priority: selectedPriority,
        dueDate, tagIds, pinned, updatedAt: Date.now()
      });
      showToast(`"${title}" updated`, '💾');
    }
  } else {
    data.todos.push({
      id: data.nextTodoId++,
      title, description, completed: false,
      priority: selectedPriority, dueDate, tagIds, pinned,
      createdAt: Date.now(), updatedAt: Date.now(),
    });
    showToast(`"${title}" added`, '✨');
  }
  persist();
  renderAll();
  closeModal();
}

function toggleTagOption(el) {
  el.classList.toggle('selected');
}

function updatePriorityButtons() {
  document.querySelectorAll('.priority-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.priority === selectedPriority);
  });
}

function selectTagColor(color) {
  selectedTagColor = color;
  renderColorPicker();
}

function addTag() {
  const name = document.getElementById('tagName').value.trim();
  if (!name) return;
  data.tags.push({ id: data.nextTagId++, name, color: selectedTagColor });
  document.getElementById('tagName').value = '';
  selectedTagColor = COLORS[0];
  renderColorPicker();
  renderTagList();
  renderTagSelector();
  renderAdvTagFilters();
  persist();
  showToast(`Tag "${name}" created`, '🏷️');
}

async function deleteTag(id) {
  const tag = data.tags.find(t => t.id === id);
  if (!tag) return;
  const result = await window.api.confirmDelete(`Delete tag "${tag.name}"?`);
  if (result === 1) {
    data.tags = data.tags.filter(t => t.id !== id);
    data.todos.forEach(t => {
      if (t.tagIds) t.tagIds = t.tagIds.filter(tid => tid !== id);
    });
    renderTagList();
    renderTagSelector();
    renderAdvTagFilters();
    renderTodos();
    persist();
    showToast(`Tag "${tag.name}" deleted`, '🗑️');
  }
}

function openTagModal() {
  document.getElementById('tagModal').classList.remove('hidden');
  renderColorPicker();
  renderTagList();
}

// --- Advanced Search ---
function toggleAdvancedSearch() {
  advSearchOpen = !advSearchOpen;
  document.getElementById('advancedSearch').classList.toggle('hidden', !advSearchOpen);
  document.getElementById('advancedSearchToggle').classList.toggle('active', advSearchOpen);
}

function updateAdvancedSearch() {
  advFilters.dateFrom = document.getElementById('advDateFrom').value || null;
  advFilters.dateTo = document.getElementById('advDateTo').value || null;

  advFilters.priorities = [];
  document.querySelectorAll('.adv-priority-filters input[type="checkbox"]').forEach(cb => {
    if (cb.checked) advFilters.priorities.push(cb.dataset.pri);
  });

  renderTodos();
}

function clearAdvancedSearch() {
  document.getElementById('advDateFrom').value = '';
  document.getElementById('advDateTo').value = '';
  document.querySelectorAll('.adv-priority-filters input[type="checkbox"]').forEach(cb => cb.checked = true);
  document.querySelectorAll('.adv-tag-chip').forEach(el => el.classList.remove('active'));
  advFilters = { dateFrom: null, dateTo: null, priorities: ['high', 'medium', 'low'], tags: [] };
  renderTodos();
}

function toggleAdvTagFilter(el) {
  const tid = parseInt(el.dataset.tagId);
  el.classList.toggle('active');
  advFilters.tags = Array.from(document.querySelectorAll('.adv-tag-chip.active'))
    .map(e => parseInt(e.dataset.tagId));
  renderTodos();
}

// --- Utils ---
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

function formatDate(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function setQuickDate(offset) {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  document.getElementById('todoDueDate').value = d.toISOString().split('T')[0];
}

// --- Event Bindings ---
function bindEvents() {
  document.getElementById('addBtn').addEventListener('click', openAddModal);
  document.getElementById('saveBtn').addEventListener('click', saveTodo);
  document.getElementById('themeToggle').addEventListener('click', toggleTheme);
  document.getElementById('clearCompleted').addEventListener('click', clearCompleted);
  document.getElementById('manageTags').addEventListener('click', openTagModal);
  document.getElementById('addTagBtn').addEventListener('click', addTag);
  document.getElementById('clearDate').addEventListener('click', () => {
    document.getElementById('todoDueDate').value = '';
  });
  document.getElementById('clearSearch').addEventListener('click', () => {
    document.getElementById('searchInput').value = '';
    searchQuery = '';
    document.getElementById('clearSearch').classList.add('hidden');
    renderTodos();
  });

  // Advanced Search
  document.getElementById('advancedSearchToggle').addEventListener('click', toggleAdvancedSearch);
  document.getElementById('advDateFrom').addEventListener('change', updateAdvancedSearch);
  document.getElementById('advDateTo').addEventListener('change', updateAdvancedSearch);
  document.querySelectorAll('.adv-priority-filters input[type="checkbox"]').forEach(cb => {
    cb.addEventListener('change', updateAdvancedSearch);
  });
  document.getElementById('clearAdvancedSearch').addEventListener('click', clearAdvancedSearch);

  document.getElementById('searchInput').addEventListener('input', (e) => {
    searchQuery = e.target.value;
    document.getElementById('clearSearch').classList.toggle('hidden', !searchQuery);
    renderTodos();
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
    btn.addEventListener('click', () => {
      selectedPriority = btn.dataset.priority;
      updatePriorityButtons();
    });
  });

  document.querySelectorAll('.quick-date-btn').forEach(btn => {
    btn.addEventListener('click', () => setQuickDate(parseInt(btn.dataset.offset)));
  });

  document.getElementById('tagName').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') addTag();
  });

  document.getElementById('todoTitle').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') saveTodo();
  });

  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', () => {
      overlay.parentElement.classList.add('hidden');
    });
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    }
    if ((e.key === 'n' || e.key === 'N') && !e.target.matches('input, textarea, select')) {
      e.preventDefault();
      openAddModal();
    }
    if (e.key === '/' && !e.target.matches('input, textarea, select')) {
      e.preventDefault();
      document.getElementById('searchInput').focus();
    }
  });
}

// Make global for inline onclick
window.toggleTodo = toggleTodo;
window.togglePin = togglePin;
window.deleteTodo = deleteTodo;
window.editTodo = editTodo;
window.closeModal = closeModal;
window.closeTagModal = closeTagModal;
window.selectTagColor = selectTagColor;
window.deleteTag = deleteTag;
window.toggleTagOption = toggleTagOption;
window.toggleAdvTagFilter = toggleAdvTagFilter;

init();
