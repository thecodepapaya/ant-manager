import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EvidenceChip extends StatelessWidget {
  const EvidenceChip({
    super.key,
    required this.data,
    required this.onTap,
  });

  final dynamic data;
  final VoidCallback onTap;

  IconData _getIcon(String? type) {
    if (type == null) return LucideIcons.hash;
    switch (type.toLowerCase()) {
      case 'note':
        return LucideIcons.stickyNote;
      case 'calendar.event':
        return LucideIcons.calendar;
      case 'code.commit':
        return LucideIcons.gitCommit;
      default:
        if (type.startsWith('code.')) return LucideIcons.code;
        return LucideIcons.hash;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String id = data is Map ? data['id'].toString() : data.toString();
    final String? type = data is Map ? data['type']?.toString() : null;
    final displayId = id.length > 8 ? id.substring(0, 8) : id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(type),
                size: 14,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                displayId,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

