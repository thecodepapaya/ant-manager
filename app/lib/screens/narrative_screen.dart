import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/date_filter_header.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';
import '../utils/event_details_dialog.dart';

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
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add note'),
          content: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Short, factual context (e.g., blocked on API contract)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (note == null || note.isEmpty) return;
    await widget.python.addNote(note);
    await _refresh();
  }

  Future<void> _openEventDetails(String eventId) async {
    // Open the dialog immediately. It will fetch metadata and summary in stages.
    await showDialog<void>(
      context: context,
      builder: (ctx) => EventDetailsDialog(
        eventId: eventId,
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
                    icon: LucideIcons.sparkles,
                    tooltip: 'Regenerate Narrative',
                    onPressed: () => _refresh(regenerate: true),
                    theme: theme,
                    color: theme.colorScheme.primary,
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
                    final llmOk = data['llm_ok'] ?? true;
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
                                            'Local LLM is not reachable. Using fallback evidence view.',
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
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.text,
                                        size: 18,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Summary',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const Spacer(),
                                      if (narrativeId.isNotEmpty)
                                        _StatusBadge(
                                          label: 'AI Generated',
                                          color: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _isEditing
                                      ? TextField(
                                          controller: _controller,
                                          maxLines: null,
                                          minLines: 10,
                                          textAlignVertical:
                                              TextAlignVertical.top,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Edit today’s narrative (keep it factual).',
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                        )
                                      : SelectableText(
                                          text.isEmpty
                                              ? 'No narrative generated yet.'
                                              : text,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 16,
                                                height: 1.6,
                                              ),
                                        ),
                                  if (evidenceIds.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    const Divider(),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Sources & Evidence',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final id in evidenceIds.take(12))
                                          Tooltip(
                                            message: id.toString(),
                                            child: ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.08),
                                              side: BorderSide(
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.2),
                                              ),
                                              label: Text(
                                                '#${id.toString().substring(0, 6)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _openEventDetails(
                                                    id.toString(),
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (_isEditing) ...[
                                FilledButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () async {
                                          await widget.python.updateNarrative(
                                            narrativeId: narrativeId,
                                            text: _controller.text,
                                          );
                                          setState(() => _isEditing = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Changes saved'),
                                              ),
                                            );
                                          }
                                          await _refresh();
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
                                  child: const Text('Cancel'),
                                ),
                              ] else ...[
                                FilledButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () => setState(() => _isEditing = true),
                                  icon: const Icon(
                                    LucideIcons.pencil,
                                    size: 18,
                                  ),
                                  label: const Text('Edit Narrative'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: narrativeId.isEmpty
                                      ? null
                                      : () async {
                                          await widget.python.lockNarrative(
                                            narrativeId,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Narrative approved & locked',
                                                ),
                                              ),
                                            );
                                          }
                                          await _refresh();
                                        },
                                  icon: const Icon(LucideIcons.lock, size: 18),
                                  label: const Text('Approve & Lock'),
                                ),
                              ],
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _addNote,
                                icon: const Icon(
                                  LucideIcons.messageSquarePlus,
                                  size: 18,
                                ),
                                label: const Text('Add Observation'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
  final VoidCallback onPressed;
  final ThemeData theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
