import 'dart:io';

/// Every provider not on this machine needs the one-time consent notice, LAN included (#74).
bool requiresConsent(String baseUrl) {
  final host = Uri.parse(baseUrl).host.toLowerCase();
  if (host == 'localhost') return false;
  return !(InternetAddress.tryParse(host)?.isLoopback ?? false);
}
