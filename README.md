<div align="center">
  <h1>📋 Todo App</h1>
  <p><strong>A feature-rich cross-platform Todo application built with Flutter & Electron</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
    <img src="https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
    <img src="https://img.shields.io/badge/Electron-33-47848F?logo=electron&logoColor=white" alt="Electron"/>
    <img src="https://img.shields.io/badge/Node.js-18+-339933?logo=nodedotjs&logoColor=white" alt="Node.js"/>
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
    <img src="https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white" alt="Android"/>
    <img src="https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white" alt="Windows"/>
  </p>
</div>

---

## ✨ Features

### 📝 Task Management
| Feature | Flutter | Electron |
|---------|:-------:|:--------:|
| Create / Edit / Delete todos | ✅ | ✅ |
| Due dates with date picker | ✅ | ✅ |
| Priority levels (High / Medium / Low) | ✅ | ✅ |
| Tags for organization | ✅ | ✅ |
| Categories with custom colors | ✅ | ❌ (uses tags) |
| Subtasks with progress tracking | ✅ | ✅ |
| Drag & drop reordering | ✅ | ✅ |
| Pin to top | ❌ | ✅ |
| Rich text descriptions (bold/italic/lists) | ❌ | ✅ |
| Plain multiline descriptions | ✅ | ✅ |

### 🔄 Recurring Tasks
- **Daily** — repeats every N days
- **Weekly** — repeats on selected days of the week
- **Monthly** — repeats on a specific day of the month
- **Yearly** — repeats on the same date each year
- **Custom interval** — flexible recurrence with optional end date

### ⏰ Reminders & Notifications
- Per-task reminder with custom date/time
- Local push notifications via `flutter_local_notifications`
- Due date checking on app startup
- Desktop notifications (Electron native)

### 🍅 Pomodoro Timer
- **Work sessions** (25 min default)
- **Short breaks** (5 min)
- **Long breaks** (15 min, after 4 sessions)
- Session counter with dot indicator
- Manual start/stop — no auto-loop (user chooses next session)

### 📅 Calendar View
- Monthly calendar via `table_calendar`
- Event dots for tasks with due dates
- Tap a date to see that day's tasks
- Navigate between months
- Jump to today

### 📊 Statistics & Charts
- **Current streak** — consecutive days with completed tasks
- **Completion pie chart** — done vs pending
- **Category distribution** — pie chart by category
- **Subtask progress** — completion ratio
- **Recurring task summary** — count by recurrence type
- **Quick stats** — total, done, pending counts
- Built with `fl_chart`

### 🎨 Customization
- **Dark / Light / System** theme modes
- **12 accent colors** to personalize the UI
- Material Design 3 (Material You)
- Smooth staggered list animations
- Grid and list view toggle

### 💾 Backup & Restore
- **JSON export** — full backup with all todos, categories, subtasks
- **CSV export** — spreadsheets-compatible task export
- **Import** — restore from JSON backup files
- **Share** — share backups via system share sheet (`share_plus`)
- Auto-generated filenames with date stamps

### 🔍 Filtering & Sorting
- **Search** by title, description, or tags
- **Filter** by: All, Pending, Done
- **Sort** by: Due date, Priority, Title, Created date, Updated date, Custom (drag order)
- Tag-specific filtering
- Multi-select for batch operations (complete, delete, set category)

### 📱 Additional
- Voice input button (placeholder — no microphone integration yet)
- Android home screen widget (`home_widget` — experimental, requires platform testing)

---

## 🏗️ Architecture

### Flutter App (Android / Windows)

```
main.dart
  └── TodoApp (MultiProvider)
        ├── TodoProvider      → CRUD, filters, subtasks, stats
        ├── ThemeProvider     → Dark/light mode, accent color
        └── PomodoroProvider  → Timer state & sessions
              └── MaterialApp (themed)
                    ├── HomeScreen (list/grid)
                    ├── AddEditTodoScreen
                    ├── CalendarScreen
                    ├── StatsScreen
                    ├── CategoriesScreen
                    ├── PomodoroScreen
                    ├── SettingsScreen
                    └── BackupScreen
```

### Electron App (Windows Desktop)

```
main.js (Main process)
  └── BrowserWindow
        ├── IPC handlers (CRUD, file I/O)
        ├── Due date checker (periodic)
        └── Recurring task processor
              └── preload.js (context bridge)
                    └── index.html / app.js / styles.css
                          └── Vanilla JS SPA
                                ├── CRUD, calendar, pomodoro
                                ├── Drag & drop, tags, search
                                └── Desktop notifications
```

### Data Flow

```
UI (Screens / Widgets)
    ↕  watch() / read() via Provider
Providers (ChangeNotifier)
    ↕
Repositories (TodoRepository, CategoryRepository)
    ↕
DatabaseHelper (SQLite singleton)
    ↕
todos.db (SQLite database)
```

---

## 🗄️ Database Schema

### `todos` table
| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `title` | TEXT | Task title |
| `description` | TEXT | Plain text description |
| `priority` | TEXT | high / medium / low |
| `dueDate` | INTEGER | Epoch ms |
| `categoryId` | INTEGER FK | References categories |
| `isDone` | INTEGER | 0 or 1 |
| `tags` | TEXT | Comma-separated |
| `attachments` | TEXT | Comma-separated paths |
| `createdAt` | INTEGER | Epoch ms |
| `updatedAt` | INTEGER | Epoch ms |
| `recurringConfig` | INTEGER | 0=none, 1=daily, 2=weekly, 3=monthly, 4=yearly |
| `recurringInterval` | INTEGER | Every N days/weeks/months |
| `recurringDaysOfWeek` | TEXT | Comma-separated (0=Sun..6=Sat) |
| `recurringDayOfMonth` | INTEGER | 1-31 |
| `recurringEndDate` | INTEGER | Epoch ms |
| `recurringHasEnd` | INTEGER | 0 or 1 |
| `nextDueDate` | INTEGER | Epoch ms |
| `reminderAt` | INTEGER | Epoch ms |
| `hasReminder` | INTEGER | 0 or 1 |
| `sortOrder` | INTEGER | Drag-drop order |

### `categories` table
| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `name` | TEXT | Category name |
| `color` | TEXT | Hex color |
| `customColors` | TEXT | Comma-separated hex colors |

### `subtasks` table
| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT PK | UUID |
| `title` | TEXT | Subtask text |
| `isDone` | INTEGER | 0 or 1 |
| `todoId` | INTEGER FK | References todos |
| `sortOrder` | INTEGER | Display order |

### `pomodoro_sessions` table
| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `todoId` | INTEGER FK | Associated task |
| `startedAt` | INTEGER | Epoch ms |
| `durationMinutes` | INTEGER | Session length |
| `completed` | INTEGER | 0 or 1 |

---

## 🚀 Getting Started

### Prerequisites

| Dependency | Version | Download |
|------------|---------|----------|
| Flutter | 3.44+ | [flutter.dev](https://flutter.dev) |
| Dart | 3.12+ | (bundled with Flutter) |
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |

### Flutter App (Android)

```bash
# Clone the repo
git clone https://github.com/jiteshoffice1234-star/TodoApp.git
cd TodoApp

# Get dependencies
flutter pub get

# Run on Android device / emulator
flutter run

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### Flutter App (Windows)

```bash
# Enable Windows support
flutter config --enable-windows-desktop

# Run
flutter run -d windows

# Build installer
flutter build windows
```

### Electron App (Windows Desktop)

```bash
# Install Node dependencies
npm install

# Run in development
npm start

# Build installer
npm run build

# Build portable .exe
npm run build:portable

# Build MSI
npm run build:msi
```

### ⌨️ Android Studio / VS Code

1. Open the `TodoApp` folder
2. Run `flutter pub get`
3. Select a device/emulator
4. Press **Run** (▶️)

---

## 🧪 Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

> ⚠️ **Note:** Only 3 model serialization tests exist. The widget test at `test/widget_test.dart` is outdated (references a removed `MyApp` class) and will fail.

---

## 🧰 Tech Stack

### Flutter App
| Package | Version | Purpose |
|---------|:-------:|---------|
| `provider` | 6.1.2 | State management |
| `sqflite` | 2.3.2 | SQLite database |
| `intl` | 0.20.0 | Date formatting |
| `shared_preferences` | 2.2.3 | Settings persistence |
| `table_calendar` | 3.2.0 | Calendar view |
| `fl_chart` | 0.66.0 | Statistics charts |
| `reorderables` | 0.6.0 | Drag & drop |
| `flutter_local_notifications` | 18.0.1 | Push notifications |
| `csv` | 5.1.0 | CSV export |
| `share_plus` | 13.2.0 | File sharing |
| `image_picker` | 1.1.2 | *(declared but unused)* |
| `home_widget` | 0.9.3 | Android home widget |
| `flutter_staggered_animations` | 1.1.1 | List animations |
| `uuid` | 4.5.1 | Subtask IDs |
| `timezone` | 0.10.0 | Timezone support |

### Electron App
| Package | Version | Purpose |
|---------|:-------:|---------|
| `electron` | 33.4.11 | Desktop shell |
| `electron-builder` | 25.1.8 | Windows installer |

---

## 📁 Project Structure

```
TodoApp/
├── lib/                          # Flutter / Dart source
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # Root widget (MultiProvider + MaterialApp)
│   ├── core/
│   │   ├── database/
│   │   │   └── database_helper.dart   # SQLite connection & migrations
│   │   ├── services/
│   │   │   ├── backup_service.dart    # JSON / CSV export/import
│   │   │   ├── notification_service.dart # Local notifications
│   │   │   └── widget_service.dart    # Home screen widget
│   │   └── theme/
│   │       ├── app_theme.dart         # Light/dark themes, accent colors
│   │       └── color_utils.dart       # Hex color parsing utility
│   ├── data/
│   │   ├── models/
│   │   │   ├── todo.dart             # Todo model + serialization
│   │   │   ├── subtask.dart          # Subtask model
│   │   │   ├── recurring_config.dart # Recurrence configuration
│   │   │   └── category.dart         # Category model
│   │   └── repositories/
│   │       ├── todo_repository.dart  # Todo data access
│   │       └── category_repository.dart # Category data access
│   ├── providers/
│   │   ├── todo_provider.dart        # Todo CRUD, filters, stats
│   │   ├── theme_provider.dart       # Theme & accent color
│   │   └── pomodoro_provider.dart    # Pomodoro timer
│   └── ui/
│       ├── screens/
│       │   ├── home_screen.dart      # Main todo list
│       │   ├── add_edit_todo_screen.dart # Create/edit form
│       │   ├── calendar_screen.dart  # Calendar view
│       │   ├── stats_screen.dart     # Statistics
│       │   ├── categories_screen.dart # Category manager
│       │   ├── pomodoro_screen.dart  # Timer UI
│       │   ├── settings_screen.dart  # Appearance settings
│       │   └── backup_screen.dart    # Backup & restore
│       └── widgets/
│           ├── todo_card.dart        # List tile
│           ├── grid_todo_card.dart   # Grid tile
│           ├── priority_badge.dart   # Priority indicator
│           ├── empty_state.dart      # Empty placeholder
│           └── voice_input_button.dart # Voice input stub
├── src/                          # Electron / web frontend
│   ├── index.html                # Main HTML page
│   ├── app.js                    # Full Electron SPA (CRUD, calendar, pomodoro)
│   └── styles.css                # Complete stylesheet
├── main.js                       # Electron main process
├── preload.js                    # Electron context bridge
├── package.json                  # Node / Electron config
├── pubspec.yaml                  # Flutter / Dart config
├── test/
│   ├── models_test.dart          # Model unit tests
│   └── widget_test.dart          # Widget test (⚠️ outdated)
├── android/                      # Android platform
├── windows/                      # Windows platform
└── README.md
```

---

## 🔐 Known Issues & Limitations

| Issue | Severity | Status |
|-------|:--------:|--------|
| Widget test references old `MyApp` class | 🟡 Medium | Needs update |
| No database indexes on frequent query columns | 🟡 Medium | Performance impact for large datasets |
| No pagination — all todos loaded into memory | 🟢 Low | Noticeable with 1000+ todos |
| No data encryption (plain SQLite / JSON) | 🟢 Low | Local-only app, but no encryption at rest |
| Renamed `_parseColor` utility — now shared via `color_utils.dart` | ✅ Fixed | |
| `reorderTodos` now operates on `_todos` directly | ✅ Fixed | Drag-drop reorder now works |
| Pomodoro no longer auto-cycles; has Stop button | ✅ Fixed | User controls session flow |
| Notifications/widget services now initialized in `main.dart` | ✅ Fixed | |
| `_parseColor` / `int.parse` — now error-safe | ✅ Fixed | |
| CSP added to Electron HTML | ✅ Fixed | |
| `CREATE TABLE IF NOT EXISTS` in migrations | ✅ Fixed | |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Built with ❤️ using Flutter, Dart, and Electron</sub>
  <br>
  <a href="https://github.com/jiteshoffice1234-star/TodoApp">GitHub</a> •
  <a href="https://github.com/jiteshoffice1234-star/TodoApp/issues">Issues</a> •
  <a href="https://github.com/jiteshoffice1234-star/TodoApp/pulls">Pull Requests</a>
</div>
