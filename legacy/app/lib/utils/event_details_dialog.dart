import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'formatters.dart';
import '../services/python_service.dart';

class EventDetailsDialog extends StatefulWidget {
  const EventDetailsDialog({
    super.key,
    required this.eventId,
    this.item,
    this.source,
    this.timestamp,
    this.isCalendarEvent = false,
    required this.python,
    required this.onRefresh,
  });

  final String eventId;
  final Map<String, dynamic>? item;
  final String? source;
  final String? timestamp;
  final bool isCalendarEvent;
  final PythonService python;
  final VoidCallback onRefresh;

  @override
  State<EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<EventDetailsDialog>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _detailsFuture;
  Future<Map<String, dynamic>>? _summaryFuture;
  bool _isEditingSummary = false;
  final _summaryController = TextEditingController();
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadMetadata();
  }

  void _loadMetadata() {
    setState(() {
      _detailsFuture = widget.python.getEventDetails(
        widget.eventId,
        source: (widget.source != null && widget.source!.isNotEmpty)
            ? widget.source
            : null,
        timestamp: (widget.timestamp != null && widget.timestamp!.isNotEmpty)
            ? widget.timestamp
            : null,
        skipLlm: true, // Fetch instantly from DB or Live Git (no LLM)
      );
    });
  }

  void _generateSummary({bool force = false}) {
    setState(() {
      _summaryFuture = widget.python.getEventDetails(
        widget.eventId,
        source: (widget.source != null && widget.source!.isNotEmpty)
            ? widget.source
            : null,
        timestamp: (widget.timestamp != null && widget.timestamp!.isNotEmpty)
            ? widget.timestamp
            : null,
        regenerate: force,
      );
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<bool> _uploadTranscript(Map<String, dynamic> event) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final fileName = result.files.single.name;

        final timestamp =
            (event['timestamp'] ?? event['timestamp_start'] ?? '').toString();
        final title = (event['title'] ?? 'Event').toString();
        final source = (event['source'] ?? '').toString();
        final type = (event['type'] ?? '').toString();

        await widget.python.addEventArtifact(
          eventId: widget.eventId,
          kind: 'calendar.transcript',
          content: content,
          title: title,
          timestamp: timestamp,
          source: source,
          type: type,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transcript "$fileName" uploaded successfully'),
            ),
          );
          _loadMetadata();
        }
        return true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error uploading transcript: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return false;
  }

  Future<bool> _addNoteToEvent(Map<String, dynamic> event) async {
    final theme = Theme.of(context);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        final timestamp = (event['timestamp'] ?? event['timestamp_start'] ?? '')
            .toString();
        final title = (event['title'] ?? 'Event').toString();

        return AlertDialog(
          title: const Text('Add Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDateTime(timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Enter your note about this event...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (note != null && note.isNotEmpty) {
      try {
        final timestamp =
            (event['timestamp'] ?? event['timestamp_start'] ?? '').toString();
        final title = (event['title'] ?? 'Event').toString();
        final source = (event['source'] ?? '').toString();
        final type = (event['type'] ?? '').toString();

        await widget.python.addEventArtifact(
          eventId: widget.eventId,
          kind: 'calendar.note',
          content: note,
          title: title,
          timestamp: timestamp,
          source: source,
          type: type,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note added successfully')),
          );
          _loadMetadata();
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText('Error adding note: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    return false;
  }

  Future<bool?> _showEditNoteDialog(
    BuildContext context,
    String noteId,
    String initialContent,
    DateTime initialTime,
  ) async {
    final controller = TextEditingController(text: initialContent);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        DateTime selectedTime = initialTime;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Note'),
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
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1)),
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.python.updateNote(
                        noteId,
                        controller.text.trim(),
                        timestamp: selectedTime.toUtc().toIso8601String(),
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update note: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              (widget.item?['title'] ?? 'Event Details').toString(),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Regenerate Summary',
            onPressed: () => _generateSummary(force: true),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('Error loading metadata: ${snapshot.error}'),
              );
            }

            final details = snapshot.data ?? {};
            final event = details['event'] ?? widget.item ?? {};
            final isNote = (event['type'] == 'note');
            final timestamp =
                (event['timestamp'] ?? event['timestamp_start'] ?? '')
                    .toString();
            final artifacts =
                (details['artifacts'] as List?)?.cast<dynamic>() ?? const [];

            final transcripts = artifacts
                .where((a) => a['kind'] == 'calendar.transcript')
                .toList();
            final notes = artifacts
                .where((a) => a['kind'] == 'calendar.note')
                .toList();
            final aiSummaryArtifact = artifacts
                .where((a) => a['kind'] == 'ai.summary')
                .firstOrNull;
            final otherArtifacts = artifacts
                .where(
                  (a) =>
                      a['kind'] != 'calendar.transcript' &&
                      a['kind'] != 'calendar.note' &&
                      a['kind'] != 'ai.summary',
                )
                .toList();

            // Auto-trigger summary generation if missing
            if (!isLoading &&
                aiSummaryArtifact == null &&
                _summaryFuture == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _generateSummary();
              });
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Basic Info - Always Visible
                  Row(
                    children: [
                      Text(
                        'When: ${AppFormatters.formatDateTime(timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (isNote) ...[
                        IconButton(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          tooltip: 'Edit Note',
                          onPressed: () async {
                            final result = await _showEditNoteDialog(
                              context,
                              event['id'].toString(),
                              artifacts[0]['content'].toString(),
                              DateTime.parse(timestamp),
                            );
                            if (result == true) {
                              _loadMetadata();
                              widget.onRefresh();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2,
                              size: 16, color: Colors.red),
                          tooltip: 'Delete Note',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Note'),
                                content: const Text(
                                    'Are you sure you want to delete this note?'),
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
                              try {
                                await widget.python
                                    .deleteNote(event['id'].toString());
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  widget.onRefresh();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                      if (!isNote && event['created_at'] != null) ...[
                        IconButton(
                          icon: const Icon(LucideIcons.trash2,
                              size: 16, color: Colors.red),
                          tooltip: 'Delete Evidence',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Evidence'),
                                content: const Text(
                                    'Are you sure you want to delete this event\'s evidence (notes, transcripts, and AI summaries) from the database? This will not affect the original source.'),
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
                              try {
                                await widget.python.deleteEvent(widget.eventId);
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  widget.onRefresh();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'ID: ${widget.eventId.length > 8 ? widget.eventId.substring(0, 8) : widget.eventId}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.isCalendarEvent ||
                          event['type'] == 'calendar.event') &&
                      event['duration'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${event['duration']} minutes',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Sub-actions visible immediately if we know it's a calendar event
                  if (widget.isCalendarEvent ||
                      (event['type'] == 'calendar.event')) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _uploadTranscript(event),
                            icon: const Icon(LucideIcons.upload, size: 18),
                            label: const Text('Upload Transcript'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _addNoteToEvent(event),
                            icon: const Icon(LucideIcons.stickyNote, size: 18),
                            label: const Text('Add Note'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // AI Summary Section
                  _buildSummarySection(theme, aiSummaryArtifact),

                  // Metadata/Artifacts loader (subtle)
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),

                  if (transcripts.isNotEmpty) ...[
                    Text(
                      'Transcripts',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final t in transcripts)
                      ArtifactBox(
                        content: t['content'].toString(),
                        color: Colors.blue,
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (notes.isNotEmpty) ...[
                    Text(
                      'Notes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final n in notes)
                      ArtifactBox(
                        content: n['content'].toString(),
                        color: Colors.amber,
                        icon: LucideIcons.stickyNote,
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (otherArtifacts.isNotEmpty)
                    for (final a in otherArtifacts) ...[
                      Text(
                        a['kind'] == 'git.commit' ? 'Changes' : 'Details',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ArtifactBox(
                        content: a['content'].toString(),
                        color: Colors.grey,
                        isMonospace: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                  if (!isLoading && artifacts.isEmpty && _summaryFuture == null)
                    const Text('No details available.'),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSummarySection(ThemeData theme, dynamic existingSummary) {
    if (existingSummary != null && !_isEditingSummary) {
      return _buildSummaryCard(theme, existingSummary['content'].toString());
    }

    if (_isEditingSummary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Edit AI Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _isEditingSummary = false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await widget.python.updateEventArtifact(
                      eventId: widget.eventId,
                      kind: 'ai.summary',
                      content: _summaryController.text,
                    );
                    setState(() => _isEditingSummary = false);
                    _loadMetadata();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
          TextField(
            controller: _summaryController,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerSummary(theme);
        }

        if (snapshot.hasData && snapshot.data!['ok'] == true) {
          final summaryList = snapshot.data!['artifacts'] as List;
          final summary = summaryList.firstWhere(
            (a) => a['kind'] == 'ai.summary',
            orElse: () => null,
          );
          if (summary != null) {
            return _buildSummaryCard(theme, summary['content'].toString());
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildShimmerSummary(ThemeData theme) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generating AI Summary...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Shimmering lines
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Opacity(
                      opacity: 0.3 + (0.4 * _shimmerController.value),
                      child: Container(
                        height: 10,
                        width: double.infinity * (i == 2 ? 0.6 : 1.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'AI Summary',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEditingSummary = true;
                  _summaryController.text = content;
                });
              },
              icon: const Icon(LucideIcons.pencil, size: 14),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          child: SelectableText(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class ArtifactBox extends StatelessWidget {
  const ArtifactBox({
    super.key,
    required this.content,
    required this.color,
    this.icon,
    this.isMonospace = false,
  });

  final String content;
  final Color color;
  final IconData? icon;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SelectableText(
                content,
                style: isMonospace
                    ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
                    : theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
