import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/date_filter_header.dart';
import '../services/python_service.dart';
import '../services/date_filter_provider.dart';
import '../services/data_providers.dart';

class WinsScreen extends ConsumerStatefulWidget {
  const WinsScreen({
    super.key,
    required this.python,
  });

  final PythonService python;

  @override
  ConsumerState<WinsScreen> createState() => _WinsScreenState();
}

class _WinsScreenState extends ConsumerState<WinsScreen> {
  bool _isEditing = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isEditing = false;
    });
    ref.invalidate(winsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(dateFilterProvider);
    final winsAsync = ref.watch(winsProvider);

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

                    if (!_isEditing) {
                      _controller.text = text;
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
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
                                          ),
                                        ),
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
                                                content: Text('Wins updated'),
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
