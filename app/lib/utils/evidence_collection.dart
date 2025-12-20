import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'evidence_chip.dart';

class EvidenceCollection extends StatefulWidget {
  const EvidenceCollection({
    super.key,
    required this.evidenceIds,
    required this.onTap,
    this.initialLimit = 12,
  });

  final List<dynamic> evidenceIds;
  final Function(String id, {String? type}) onTap;
  final int initialLimit;

  @override
  State<EvidenceCollection> createState() => _EvidenceCollectionState();
}

class _EvidenceCollectionState extends State<EvidenceCollection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMore = widget.evidenceIds.length > widget.initialLimit;
    final displayItems = _showAll
        ? widget.evidenceIds
        : widget.evidenceIds.take(widget.initialLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(LucideIcons.link, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'Sources & Context',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
            if (hasMore) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAll
                      ? 'Show Less'
                      : 'Show All (${widget.evidenceIds.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in displayItems)
              EvidenceChip(
                data: item,
                onTap: () {
                  final id = item is Map
                      ? item['id'].toString()
                      : item.toString();
                  final type = item is Map ? item['type']?.toString() : null;
                  widget.onTap(id, type: type);
                },
              ),
          ],
        ),
      ],
    );
  }
}
