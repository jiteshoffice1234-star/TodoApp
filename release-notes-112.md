## v1.12.0 — PiP & Auto-Updater Fixes

### 🐛 PiP Pop-Out Ticker Fixed
- Removed redundant `did-finish-load` handler in `openPipWindow()` that caused a double-send race on initial content delivery
- The `sendToPip` queue mechanism now handles content delivery single-handedly — no duplicate messages, no race window
- Cleaned up orphaned `pip:request-refresh` IPC handler and preload bridge method
- **Result**: PiP opens instantly with correct content, no blank flash

### 🚀 Auto-Updater Fixed
- Added `getUpdateStatus()` sync immediately after registering IPC listeners — catches the `update-available` event even if the 5-second startup check completed before the renderer was ready
- Added `getUpdateStatus()` sync inside `openSettings()` — always shows the freshest state when user opens settings
- **Result**: Update notifications reliably appear, download/install buttons work correctly

### 🏗 Other
- Version bumped to 1.12.0
- GitHub Actions auto-build workflow added (`.github/workflows/build-electron.yml`) — just push a `v*` tag
