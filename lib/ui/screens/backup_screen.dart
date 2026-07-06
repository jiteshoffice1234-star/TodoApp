import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/todo_provider.dart';
import '../../core/services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<FileSystemEntity> _backups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    _backups = await BackupService.instance.getBackupFiles();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExportSection(theme),
            const SizedBox(height: 24),
            _buildImportSection(theme),
            const SizedBox(height: 24),
            _buildBackupList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text('Export Data', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Export your todos and categories to a file for backup.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportToJson,
                    icon: const Icon(Icons.code),
                    label: const Text('JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportToCsv,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('CSV'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text('Import Data', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Restore your todos from a JSON backup file.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importFromJson,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import JSON'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text('Existing Backups', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_backups.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No backups yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _backups.length,
                itemBuilder: (context, index) {
                  final file = _backups[index];
                  final fileName = file.path.split('/').last;
                  final isJson = fileName.endsWith('.json');
                  final date = File(file.path).lastModifiedSync();
                  
                  return ListTile(
                    leading: Icon(
                      isJson ? Icons.code : Icons.table_chart,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      fileName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy HH:mm').format(date),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () => _shareBackup(file.path),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteBackup(file.path),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToJson() async {
    final provider = context.read<TodoProvider>();
    final todos = provider.getTodosForExport();
    final categories = provider.categories;
    
    final path = await BackupService.instance.exportToJson(todos, categories);
    await BackupService.instance.shareBackup(path);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON backup exported')),
      );
    }
  }

  Future<void> _exportToCsv() async {
    final provider = context.read<TodoProvider>();
    final todos = provider.getTodosForExport();
    final categories = provider.categories;
    
    final path = await BackupService.instance.exportToCsv(todos, categories);
    await BackupService.instance.shareBackup(path);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV backup exported')),
      );
    }
  }

  Future<void> _importFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result != null && result.files.single.path != null) {
      try {
        final data = await BackupService.instance.importFromJson(result.files.single.path!);
        final todos = data['todos'] as List;
        
        if (mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Import Data'),
              content: Text('Import ${todos.length} todos?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Import'),
                ),
              ],
            ),
          );
          
          if (confirmed == true) {
            await context.read<TodoProvider>().importTodos(todos.cast());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Imported ${todos.length} todos')),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _shareBackup(String path) async {
    await BackupService.instance.shareBackup(path);
  }

  Future<void> _deleteBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text('Are you sure you want to delete this backup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await BackupService.instance.deleteBackup(path);
      await _loadBackups();
    }
  }
}
