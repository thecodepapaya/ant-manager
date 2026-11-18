import 'package:intl/intl.dart';

class AppFormatters {
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown date';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, ${DateFormat.jm().format(dt)}';
      }
      
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return 'Yesterday, ${DateFormat.jm().format(dt)}';
      }
      
      return DateFormat('MMM d, y • h:mm a').format(dt);
    } catch (e) {
      return isoString;
    }
  }
  
  static String formatDateOnly(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown date';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('EEEE, MMMM d, y').format(dt);
    } catch (e) {
      return isoString;
    }
  }
}

