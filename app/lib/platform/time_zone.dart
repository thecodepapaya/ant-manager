import 'dart:io';

/// IANA name of the system time zone, used as a new profile's default (#87).
/// macOS/Linux: the `/etc/localtime` symlink target. Elsewhere (Windows) Dart has no IANA
/// name, so the zone abbreviation is stored. Day boundaries use the system offset either way.
String systemTimeZoneName() {
  final tz = Platform.environment['TZ'];
  if (tz != null && tz.contains('/')) return tz;
  if (!Platform.isWindows) {
    try {
      final target = Link('/etc/localtime').targetSync();
      final i = target.indexOf('zoneinfo/');
      if (i >= 0) return target.substring(i + 'zoneinfo/'.length);
    } on FileSystemException {
      // Not a symlink: fall through.
    }
  }
  return DateTime.now().timeZoneName;
}
