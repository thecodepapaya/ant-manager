import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:url_launcher/url_launcher.dart';

import '../services/python_service.dart';
import '../firebase_options.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.python});

  final PythonService python;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _future;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _googleClientIdController =
      TextEditingController();
  final TextEditingController _googleClientSecretController =
      TextEditingController();
  bool _showManualOAuth = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkFirebaseRedirect();
  }

  Future<void> _checkFirebaseRedirect() async {
    try {
      final redirectResult = await FirebaseAuth.instance.getRedirectResult();
      if (redirectResult.user != null && mounted) {
        final idToken = await redirectResult.user!.getIdToken();
        await widget.python.setGoogleToken('FIREBASE:$idToken');
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Calendar connected!')),
          );
        }
      }
    } catch (e) {
      // Silently handle
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _userController.dispose();
    _googleClientIdController.dispose();
    _googleClientSecretController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    await widget.python.initDb();
    final config = await widget.python.getConfig();

    if (mounted) {
      final clientId = config['google_client_id'] as String? ?? '';
      final clientSecret = config['google_client_secret'] as String? ?? '';
      _googleClientIdController.text = clientId;
      _googleClientSecretController.text = clientSecret;
    }

    return config;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _addRepo() async {
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select Git Repository');

    if (selectedDirectory != null) {
      await widget.python.addRepo(selectedDirectory);

      final currentUserName = _userController.text.trim();
      if (currentUserName.isEmpty) {
        final detectedName = await widget.python.detectGitUser(
          selectedDirectory,
        );
        if (mounted) {
          final confirmedName = await showDialog<String>(
            context: context,
            builder: (ctx) {
              final c = TextEditingController(text: detectedName);
              return AlertDialog(
                title: const Text('Setup Identity'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detectedName != null
                          ? 'We detected your Git name. Is this you? We use this to filter only your commits.'
                          : 'We couldn\'t detect your Git name automatically. Please enter it here so we can filter your commits.',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: c,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Git Author Name',
                        hintText: 'e.g., Jane Doe',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          );

          if (confirmedName != null && confirmedName.isNotEmpty) {
            await widget.python.setUserName(confirmedName);
          }
        }
      }

      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added repository: $selectedDirectory')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                SelectableText('Failed to load settings.\n\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final repos =
            (data['repo_paths'] as List?)?.cast<dynamic>() ?? const [];
        final llmModel = (data['llm_model'] ?? 'llama3.1:8b').toString();
        final userName = (data['user_name'] ?? '').toString();
        final isGoogleConnected = data['google_calendar_token'] != null;

        _modelController.text = llmModel;
        _userController.text = userName;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuration & Sources',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Settings',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderButton(
                    icon: LucideIcons.refreshCw,
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    // IDENTITY SECTION
                    _SettingsGroup(
                      title: 'Account Identity',
                      icon: LucideIcons.user,
                      children: [
                        _SettingsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Information',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _userController,
                                      decoration: const InputDecoration(
                                        labelText: 'Git Author Name',
                                        hintText: 'Jane Doe',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () async {
                                      final name = _userController.text.trim();
                                      await widget.python.setUserName(name);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Identity saved'),
                                          ),
                                        );
                                      }
                                      _refresh();
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Used to filter your commits from the provided repositories.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // DATA SOURCES SECTION
                    _SettingsGroup(
                      title: 'Data Connections',
                      icon: LucideIcons.database,
                      children: [
                        // Git Repos Card
                        _SettingsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.gitBranch, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Git Repositories',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _addRepo,
                                    icon: const Icon(
                                      LucideIcons.plus,
                                      size: 16,
                                    ),
                                    label: const Text('Add Repository'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (repos.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(
                                      'No repositories added yet.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey.shade500,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: repos.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final path = repos[idx].toString();
                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        title: Text(
                                          path,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            size: 16,
                                          ),
                                          color: Colors.red.shade400,
                                          onPressed: () async {
                                            await widget.python.removeRepo(
                                              path,
                                            );
                                            _refresh();
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Google Calendar Card
                        _SettingsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.calendar, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Google Calendar',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isGoogleConnected)
                                    _StatusBadge(
                                      label: 'Connected',
                                      color: Colors.green,
                                    )
                                  else
                                    _StatusBadge(
                                      label: 'Not Linked',
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (isGoogleConnected)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _disconnectGoogle,
                                    icon: const Icon(
                                      LucideIcons.logOut,
                                      size: 16,
                                    ),
                                    label: const Text('Disconnect Account'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _connectGoogle,
                                    icon: const Icon(
                                      LucideIcons.calendarPlus,
                                      size: 16,
                                    ),
                                    label: const Text('Connect with Google'),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _ManualOAuthToggle(
                                isVisible: _showManualOAuth,
                                onToggle: () => setState(() {
                                  _showManualOAuth = !_showManualOAuth;
                                }),
                              ),
                              if (_showManualOAuth) ...[
                                const SizedBox(height: 16),
                                _ManualOAuthForm(
                                  clientIdController: _googleClientIdController,
                                  clientSecretController:
                                      _googleClientSecretController,
                                  onSaveOnly: _saveGoogleSecretsOnly,
                                  onSaveAndConnect:
                                      _saveGoogleSecretsAndConnect,
                                  theme: theme,
                                  python: widget.python,
                                  refresh: _refresh,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // AI SECTION
                    _SettingsGroup(
                      title: 'Artificial Intelligence',
                      icon: LucideIcons.brainCircuit,
                      children: [
                        _SettingsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local LLM (via Ollama)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _modelController,
                                      decoration: const InputDecoration(
                                        labelText: 'Model Name',
                                        hintText: 'llama3.1:8b',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () async {
                                      final model = _modelController.text
                                          .trim();
                                      if (model.isEmpty) return;
                                      await widget.python.setModel(model);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('AI model updated'),
                                          ),
                                        );
                                      }
                                      _refresh();
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Summaries are processed locally on your machine.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // SECURITY SECTION
                    _SettingsGroup(
                      title: 'Security & Privacy',
                      icon: LucideIcons.shieldCheck,
                      children: [
                        _SettingsCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _PlannedFeatureTile(
                                icon: LucideIcons.lock,
                                title: 'Database Encryption',
                                subtitle: 'AES-256 local encryption',
                              ),
                              const Divider(height: 1),
                              _PlannedFeatureTile(
                                icon: LucideIcons.eyeOff,
                                title: 'Privacy Shield',
                                subtitle: 'Blur content in app switcher',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ABOUT SECTION
                    _SettingsGroup(
                      title: 'About',
                      icon: LucideIcons.info,
                      children: [
                        _SettingsCard(
                          color: theme.colorScheme.primary.withOpacity(0.03),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AntManager',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'A 100% local-first work tracker. No cloud, no tracking, no telemetry. Your data stays on your disk.',
                                style: TextStyle(fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Version 1.0.0',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _disconnectGoogle() async {
    try {
      await FirebaseAuth.instance.signOut();
      try {
        final clientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
        if (clientId != null && clientId.isNotEmpty) {
          final googleSignIn = GoogleSignIn(clientId: clientId);
          await googleSignIn.signOut();
        }
      } catch (e) {}
      await widget.python.setGoogleToken('');
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected Google Calendar')),
        );
      }
    } catch (e) {
      await widget.python.setGoogleToken('');
      _refresh();
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final idToken = await currentUser.getIdToken();
        await widget.python.setGoogleToken('FIREBASE:$idToken');
        _refresh();
      } else {
        final clientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
        if (clientId == null || clientId.isEmpty) {
          throw Exception('Firebase iOS Client ID not configured.');
        }
        final googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: [cal.CalendarApi.calendarReadonlyScope],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          if (userCredential.user != null) {
            final idToken = await userCredential.user!.getIdToken();
            await widget.python.setGoogleToken('FIREBASE:$idToken');
            _refresh();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _saveGoogleSecretsOnly() async {
    final clientId = _googleClientIdController.text.trim();
    final clientSecret = _googleClientSecretController.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) return;
    try {
      await widget.python.setGoogleSecrets(clientId, clientSecret);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Credentials saved')));
      }
    } catch (e) {}
  }

  Future<void> _saveGoogleSecretsAndConnect() async {
    final clientId = _googleClientIdController.text.trim();
    final clientSecret = _googleClientSecretController.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) return;
    try {
      await widget.python.setGoogleSecrets(clientId, clientSecret);
      final authUrl = await widget.python.getGoogleAuthUrl();
      if (authUrl != null && mounted) {
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          final codeController = TextEditingController();
          final code = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enter Code'),
              content: TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Authorization Code',
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, codeController.text.trim()),
                  child: const Text('Connect'),
                ),
              ],
            ),
          );
          if (code != null && code.isNotEmpty) {
            await widget.python.setGoogleToken(code);
            _refresh();
          }
        }
      }
    } catch (e) {}
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(padding: padding, child: child),
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

class _PlannedFeatureTile extends StatelessWidget {
  const _PlannedFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: _StatusBadge(label: 'Planned', color: Colors.blue),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _ManualOAuthToggle extends StatelessWidget {
  const _ManualOAuthToggle({required this.isVisible, required this.onToggle});
  final bool isVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onToggle,
      icon: Icon(
        isVisible ? LucideIcons.chevronUp : LucideIcons.chevronDown,
        size: 14,
      ),
      label: Text(
        isVisible ? 'Hide Advanced Settings' : 'Use Manual OAuth (Advanced)',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _ManualOAuthForm extends StatelessWidget {
  const _ManualOAuthForm({
    required this.clientIdController,
    required this.clientSecretController,
    required this.onSaveOnly,
    required this.onSaveAndConnect,
    required this.theme,
    required this.python,
    required this.refresh,
  });

  final TextEditingController clientIdController;
  final TextEditingController clientSecretController;
  final VoidCallback onSaveOnly;
  final VoidCallback onSaveAndConnect;
  final ThemeData theme;
  final PythonService python;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual OAuth Setup',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Required if standard connection fails. Create a "Desktop app" credential in Google Cloud Console.',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: clientIdController,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: clientSecretController,
          decoration: const InputDecoration(
            labelText: 'Client Secret',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onSaveAndConnect,
                child: const Text('Save & Connect'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onSaveOnly,
              child: const Text('Save Only'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ThemeData theme;

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
        icon: Icon(icon, color: Colors.grey.shade700, size: 18),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
