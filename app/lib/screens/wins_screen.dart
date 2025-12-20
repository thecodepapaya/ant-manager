import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import '../utils/date_filter_header.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';
import '../utils/event_details_dialog.dart';
import '../utils/evidence_collection.dart';

class WinsScreen extends ConsumerStatefulWidget {
  const WinsScreen({super.key, required this.python});

  final PythonService python;

  @override
  ConsumerState<WinsScreen> createState() => _WinsScreenState();
}

class _WinsScreenState extends ConsumerState<WinsScreen> {
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
    ref.invalidate(winsProvider(_regenerate));
  }

  Future<void> _openEventDetails(String eventId,
      {String? type, String? timestamp}) async {
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
    final winsAsync = ref.watch(winsProvider(_regenerate));
    final locked = winsAsync.maybeWhen(
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
                title: 'Wins',
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
                defaultSubtitle: 'Achievements & Milestones',
                extraActions: [
                  _HeaderButton(
                    icon: locked ? LucideIcons.lock : LucideIcons.sparkles,
                    tooltip: locked ? 'Wins are Locked' : 'Regenerate Wins',
                    onPressed: locked ? null : () => _refresh(regenerate: true),
                    theme: theme,
                    color: locked ? Colors.grey : theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: winsAsync.when(
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
                              'Failed to load wins',
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
                          Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.trophy,
                                        size: 18,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Highlights',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const Spacer(),
                                      if (narrativeId.isNotEmpty)
                                        _StatusBadge(
                                          label: locked
                                              ? 'Approved & Locked'
                                              : 'AI Generated',
                                          color: locked
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _isEditing
                                      ? TextField(
                                          controller: _controller,
                                          maxLines: null,
                                          minLines: 10,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 16,
                                                height: 1.6,
                                                color: const Color(0xFF334155),
                                              ),
                                          decoration: const InputDecoration(
                                            hintText: 'Describe your wins...',
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                        )
                                      : SelectableText(
                                          text.isEmpty
                                              ? 'No wins recorded for this period.'
                                              : text,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 16,
                                                height: 1.6,
                                                color: const Color(0xFF334155),
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
                                  message: 'Wins are approved and locked',
                                  child: FilledButton.icon(
                                    onPressed: null,
                                    icon: const Icon(
                                      LucideIcons.pencil,
                                      size: 18,
                                    ),
                                    label: const Text('Edit Wins'),
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
                                  message: 'Wins are already locked',
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
                                                const SnackBar(
                                                  content: Text('Wins updated'),
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
                                  label: const Text('Edit Wins'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: text.trim().isEmpty
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: text),
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Copied to clipboard',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(LucideIcons.copy, size: 18),
                                  label: const Text('Copy to Clipboard'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
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
  final VoidCallback? onPressed;
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
