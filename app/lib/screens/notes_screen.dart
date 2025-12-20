import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/date_filter_header.dart';
import '../utils/formatters.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, required this.python});

  final PythonService python;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  Future<void> _refresh() async {
    ref.invalidate(notesProvider);
  }

  Future<void> _addNote() async {
    final result = await _showNoteDialog();
    if (result != null && (result['content'] as String).isNotEmpty) {
      await widget.python.addNote(
        result['content'] as String,
        timestamp: result['timestamp'] as String,
      );
      _refresh();
    }
  }

  Future<void> _editNote(Map<String, dynamic> note) async {
    final noteId = note['id'].toString();
    final result = await _showNoteDialog(
      initialContent: note['content'].toString(),
      initialTime: DateTime.parse(note['timestamp'].toString()),
    );
    if (result != null && (result['content'] as String).isNotEmpty) {
      await widget.python.updateNote(
        noteId,
        result['content'] as String,
        timestamp: result['timestamp'] as String,
      );
      _refresh();
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.python.deleteNote(noteId);
      _refresh();
    }
  }

  Future<Map<String, dynamic>?> _showNoteDialog({
    String initialContent = '',
    DateTime? initialTime,
  }) async {
    final controller = TextEditingController(text: initialContent);
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        DateTime selectedTime = initialTime ?? DateTime.now();
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initialContent.isEmpty ? 'Add Note' : 'Edit Note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter your note content...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Time: ${AppFormatters.formatDateTime(selectedTime.toIso8601String())}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedTime,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedTime),
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'content': controller.text.trim(),
                    'timestamp': selectedTime.toUtc().toIso8601String(),
                  }),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openNote(Map<String, dynamic> note) async {
    final content = (note['content'] ?? '').toString();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note Details'),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(dateFilterProvider);
    final notesAsync = ref.watch(notesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateFilterHeader(
                title: 'Notes',
                view: filter.view,
                selectedDate: filter.selectedDate,
                selectedRange: filter.selectedRange,
                onViewChanged: (newView) {
                  ref.read(dateFilterProvider.notifier).updateView(newView);
                },
                onDateChanged: (newDate) {
                  if (newDate == null) {
                    ref.read(dateFilterProvider.notifier).clearFilters();
                  } else {
                    ref.read(dateFilterProvider.notifier).updateDate(newDate);
                  }
                },
                onRangeChanged: (newRange) {
                  ref.read(dateFilterProvider.notifier).updateRange(newRange);
                },
                onRefresh: _refresh,
                defaultSubtitle: 'Last 30 days',
                extraActions: [
                  _HeaderActionButton(
                    icon: LucideIcons.plus,
                    tooltip: 'Add Note',
                    onPressed: _addNote,
                    theme: theme,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: notesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.alertCircle,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load notes',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  data: (data) {
                    final notesListRaw = data['notes'];
                    final notesList = (notesListRaw is List)
                        ? notesListRaw
                        : const [];
                    final typed = notesList
                        .whereType<Map>()
                        .map((e) => e.cast<String, dynamic>())
                        .toList();

                    if (typed.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.stickyNote,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _addNote,
                              child: const Text('Add your first note'),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            mainAxisExtent: 160,
                          ),
                      itemCount: typed.length,
                      itemBuilder: (context, idx) {
                        final n = typed[idx];
                        final ts = (n['timestamp'] ?? '').toString();
                        final content = (n['content'] ?? '').toString();
                        return Card(
                          child: InkWell(
                            onTap: () => _openNote(n),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        AppFormatters.formatDateTime(ts),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          LucideIcons.moreVertical,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editNote(n);
                                          } else if (value == 'delete') {
                                            _deleteNote(n['id'].toString());
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  LucideIcons.pencil,
                                                  size: 14,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  LucideIcons.trash2,
                                                  size: 14,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      content,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: 14, height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ThemeData theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? Colors.grey.shade700, size: 18),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
