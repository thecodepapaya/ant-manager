import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecretStore] on the OS keychain (Keychain / Credential Manager / libsecret, #77).
/// Plugin-backed: call only from the UI isolate (the engine reaches it through the port bridge).
class SecureSecretStore implements SecretStore {
  SecureSecretStore()
      : _storage = const FlutterSecureStorage(
          // The data-protection keychain needs a team-signed app (keychain-access-groups);
          // releases are unsigned for now, so use the login keychain.
          // TODO(signing): switch to the data-protection keychain once builds are Developer ID signed.
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
