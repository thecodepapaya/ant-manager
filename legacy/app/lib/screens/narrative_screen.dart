import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/date_filter_header.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';
import '../utils/event_details_dialog.dart';
import '../utils/formatters.dart';
import '../utils/evidence_collection.dart';

class NarrativeScreen extends ConsumerStatefulWidget {
  const NarrativeScreen({
    super.key,
    required this.python,
    this.onNavigateToSettings,
  });

  final PythonService python;
  final VoidCallback? onNavigateToSettings;

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  bool _isEditing = false;
  bool _regenerate = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool regenerate = false}) async {
    setState(() {
      _isEditing = false;
      _regenerate = regenerate;
    });
    ref.invalidate(dailySummaryProvider(_regenerate));
  }

  Future<void> _addNote() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        DateTime selectedTime = DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: c,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          'Short, factual context (e.g., blocked on API contract)',
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
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'content': c.text.trim(),
                    'timestamp': selectedTime.toUtc().toIso8601String(),
                  }),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || (result['content'] as String).isEmpty) return;
    try {
      await widget.python.addNote(
        result['content'] as String,
        timestamp: result['timestamp'] as String,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add note: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openEventDetails(String eventId,
      {String? type, String? timestamp}) async {
    // Open the dialog immediately. It will fetch metadata and summary in stages.
    String? source;
    if (type != null) {
      if (type.startsWith('code.')) {
        source = 'git';
      } else if (type == 'calendar.event') {
        source = 'calendar';
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => EventDetailsDialog(
        eventId: eventId,
        source: source,
        timestamp: timestamp,
        python: widget.python,
        onRefresh: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(dateFilterProvider);
    final summaryAsync = ref.watch(dailySummaryProvider(_regenerate));
    final locked = summaryAsync.maybeWhen(
      data: (data) => data['locked'] == true || data['locked'] == 1,
      orElse: () => false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateFilterHeader(
                title: 'Narrative',
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
                defaultSubtitle: 'Daily Summary',
                extraActions: [
                  _HeaderButton(
                    icon: locked ? LucideIcons.lock : LucideIcons.sparkles,
                    tooltip: locked
                        ? 'Narrative is Locked'
                        : 'Regenerate Narrative',
                    onPressed: locked ? null : () => _refresh(regenerate: true),
                    theme: theme,
                    color: locked ? Colors.grey : theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: summaryAsync.when(
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
                              'Failed to load narrative',
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
                    final text = (data['text'] ?? '').toString();
                    final narrativeId = (data['narrative_id'] ?? '').toString();
                    final periodStart = (data['period_start'] ?? '').toString();
                    final llmOk = data['llm_ok'] ?? true;
                    final llmProvider = (data['llm_provider'] ?? 'LLM')
                        .toString();
                    final evidenceIdsRaw = data['evidence_event_ids'];
                    List<dynamic> evidenceIds = [];
                    if (evidenceIdsRaw is List) {
                      evidenceIds = evidenceIdsRaw;
                    } else if (evidenceIdsRaw is String &&
                        evidenceIdsRaw.isNotEmpty) {
                      try {
                        evidenceIds = jsonDecode(evidenceIdsRaw);
                      } catch (e) {
                        evidenceIds = [];
                      }
                    }

                    if (!_isEditing) {
                      _controller.text = text;
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!llmOk)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Material(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onNavigateToSettings != null) {
                                      widget.onNavigateToSettings!();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.amber.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.alertTriangle,
                                          size: 20,
                                          color: Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SelectableText(
                                            '${llmProvider.toUpperCase()} is not reachable. Using fallback evidence view.',
                                            style: TextStyle(
                                              color: Colors.amber.shade900,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 16,
                                          color: Colors.amber.shade800,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.sparkles,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Daily Narrative',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: const Color(0xFF1E293B),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const Spacer(),
                                      if (narrativeId.isNotEmpty)
                                        _StatusBadge(
                                          label: locked
                                              ? 'Approved & Locked'
                                              : 'AI Summary',
                                          color: locked
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  _isEditing
                                      ? Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: _controller,
                                            maxLines: null,
                                            minLines: 10,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontSize: 16,
                                                  height: 1.6,
                                                  color: const Color(
                                                    0xFF334155,
                                                  ),
                                                ),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Edit today’s narrative...',
                                              filled: false,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        )
                                      : SelectableText(
                                          text.isEmpty
                                              ? 'No narrative generated yet.'
                                              : text,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 16,
                                                height: 1.7,
                                                color: const Color(0xFF334155),
                                                letterSpacing: 0.2,
                                              ),
                                        ),
                                  if (evidenceIds.isNotEmpty)
                                    EvidenceCollection(
                                      evidenceIds: evidenceIds,
                                      onTap: (id, {type}) => _openEventDetails(
                                        id,
                                        type: type,
                                        timestamp: periodStart,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (locked) ...[
                                Tooltip(
                                  message: 'Narrative is approved and locked',
                                  child: FilledButton.icon(
                                    onPressed: null,
                                    icon: const Icon(
                                      LucideIcons.edit3,
                                      size: 18,
                                    ),
                                    label: const Text('Edit'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.disabledColor,
                                      foregroundColor: theme
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.38),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Tooltip(
                                  message: 'Narrative is already locked',
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(
                                      LucideIcons.checkCircle,
                                      size: 18,
                                    ),
                                    label: const Text('Approved'),
                                  ),
                                ),
                              ] else if (_isEditing) ...[
                                FilledButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () async {
                                          try {
                                            await widget.python.updateNarrative(
                                              narrativeId: narrativeId,
                                              text: _controller.text,
                                            );
                                            setState(() => _isEditing = false);
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Narrative updated successfully',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                            await _refresh();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to update: $e',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(LucideIcons.check, size: 18),
                                  label: const Text('Save Changes'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _controller.text = text;
                                    });
                                  },
                                  child: const Text('Discard'),
                                ),
                              ] else ...[
                                FilledButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () => setState(() => _isEditing = true),
                                  icon: const Icon(LucideIcons.edit3, size: 18),
                                  label: const Text('Edit'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () async {
                                          try {
                                            await widget.python.lockNarrative(
                                              narrativeId,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Narrative approved and locked',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                            await _refresh();
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to lock: $e',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(LucideIcons.lock, size: 18),
                                  label: const Text('Approve & Lock'),
                                ),
                              ],
                              const Spacer(),
                              Tooltip(
                                message: locked
                                    ? 'Cannot add observations to a locked narrative'
                                    : '',
                                child: TextButton.icon(
                                  onPressed: locked ? null : _addNote,
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          (locked
                                                  ? Colors.grey
                                                  : theme.colorScheme.primary)
                                              .withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.plus,
                                      size: 14,
                                      color: locked
                                          ? Colors.grey
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                  label: const Text('Add Observation'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: locked
                                        ? Colors.grey
                                        : theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? const Color(0xFF64748B), size: 20),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
