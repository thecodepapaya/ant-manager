/// Connect / edit dialogs for every non-git source (SPEC §5).
library;

import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/commands.dart';
import '../../engine/messages.dart';
import '../../engine/setup_commands.dart';
import '../../platform/mac_calendar_bridge.dart';
import '../../state/providers.dart';
import '../settings/kit.dart';
import 'git_setup.dart';

/// What the user picks in "Add source". Outlook is an ICS feed (#82); GitHub covers GHES (#81 keeps GHES).
enum SourceOption {
  git('git', 'Local git', 'Commits on every branch'),
  github('GH', 'GitHub', 'github.com or Enterprise'),
  gitlab('GL', 'GitLab', 'gitlab.com or self-managed'),
  google('G', 'Google Calendar', 'Sign in with Google'),
  apple('', 'Apple Calendar', 'Uses Calendar.app'),
  outlook('O', 'Outlook / Microsoft 365', 'Paste the calendar’s ICS link'),
  ics('ics', 'ICS feed', 'Paste a calendar link'),
  linear('L', 'Linear', 'API key'),
  jira('J', 'Jira Cloud', 'Site, email and API token');

  const SourceOption(this.glyph, this.label, this.hint);
  final String glyph;
  final String label;
  final String hint;

  IconData? get icon => this == apple ? Icons.calendar_month_outlined : null;

  static List<SourceOption> get available =>
      [for (final o in values) if (o != apple || MacCalendarBridge.supported) o];

  /// The option an existing source row belongs to.
  static SourceOption of(SourceRow r) => switch (r.kind) {
        SourceKind.gitRepo => git,
        SourceKind.github || SourceKind.githubEnterprise => github,
        SourceKind.gitlab => gitlab,
        SourceKind.googleCalendar => google,
        SourceKind.appleCalendar => apple,
        SourceKind.ics => r.name.startsWith('Outlook') ? outlook : ics,
        SourceKind.linear => linear,
        SourceKind.jira => jira,
        _ => ics,
      };
}

class _Field {
  const _Field(this.key, this.label, {this.placeholder, this.hint, this.secret = false, this.required = true});
  final String key;
  final String label;
  final String? placeholder;
  final String? hint;
  final bool secret;
  final bool required;
}

const _secretKey = '_secret';

List<_Field> _fields(SourceOption o) => switch (o) {
      SourceOption.github => const [
          _Field(_secretKey, 'Personal access token',
              placeholder: 'ghp_…', secret: true, hint: 'Needs read access to repos and pull requests. Stored in your Keychain.'),
          _Field('apiBaseUrl', 'API URL (GitHub Enterprise only)',
              placeholder: 'https://github.example.com/api/v3', required: false),
          _Field('login', 'Username', placeholder: 'Detected from the token', required: false),
        ],
      SourceOption.gitlab => const [
          _Field('baseUrl', 'GitLab URL', placeholder: 'https://gitlab.com', required: false),
          _Field(_secretKey, 'Personal access token',
              placeholder: 'glpat-…', secret: true, hint: 'Scope: read_api. Stored in your Keychain.'),
          _Field('username', 'Username', placeholder: 'Detected from the token', required: false),
        ],
      SourceOption.outlook => const [
          _Field('url', 'ICS link',
              placeholder: 'https://outlook.office365.com/owa/calendar/…/calendar.ics',
              hint: 'Outlook on the web → Settings → Calendar → Shared calendars → Publish a calendar → ICS.'),
        ],
      SourceOption.ics => const [
          _Field('url', 'Calendar URL', placeholder: 'https://… or webcal://…', hint: 'Recurring events are expanded.'),
        ],
      SourceOption.linear => const [
          _Field(_secretKey, 'API key',
              placeholder: 'lin_api_…', secret: true, hint: 'Linear → Settings → Security & access → Personal API keys.'),
        ],
      SourceOption.jira => const [
          _Field('siteUrl', 'Site URL', placeholder: 'https://your-team.atlassian.net'),
          _Field('email', 'Account email', placeholder: 'you@company.com'),
          _Field(_secretKey, 'API token',
              secret: true, hint: 'id.atlassian.com → Security → API tokens. Jira Cloud only.'),
        ],
      _ => const [],
    };

String _host(String url) => Uri.tryParse(url)?.host ?? url;

/// Opens the right flow for [option]: git setup, Google sign-in, Apple access or a form.
Future<void> connectSource(BuildContext context, SourceOption option) async {
  if (option == SourceOption.git) {
    await showAntDialog<void>(context, builder: (_) => const GitSetupDialog());
    return;
  }
  await showAntDialog<void>(context, builder: (_) => SourceFormDialog(option: option));
}

Future<void> editSource(BuildContext context, SourceRow row) => showAntDialog<void>(
      context,
      builder: (_) => SourceFormDialog(option: SourceOption.of(row), existing: row),
    );

class SourceFormDialog extends ConsumerStatefulWidget {
  const SourceFormDialog({super.key, required this.option, this.existing});
  final SourceOption option;
  final SourceRow? existing;

  @override
  ConsumerState<SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends ConsumerState<SourceFormDialog> {
  late final Map<String, TextEditingController> _c;
  String? _error;
  String? _sourceId;
  bool _busy = false;
  String? _googleTokens;

  SourceOption get o => widget.option;

  @override
  void initState() {
    super.initState();
    _sourceId = widget.existing?.id;
    final config = widget.existing == null
        ? const <String, Object?>{}
        : jsonDecode(widget.existing!.config) as Map<String, Object?>;
    _c = {for (final f in _fields(o)) f.key: TextEditingController(text: (config[f.key] as String?) ?? '')};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _c[key]?.text.trim() ?? '';

  ({SourceKind kind, String name, Map<String, Object?> config, String? secret}) _draft() {
    final config = <String, Object?>{
      for (final f in _fields(o))
        if (f.key != _secretKey && _v(f.key).isNotEmpty) f.key: _v(f.key),
    };
    final secret = _v(_secretKey).isEmpty ? _googleTokens : _v(_secretKey);
    return switch (o) {
      SourceOption.github => (
          kind: config.containsKey('apiBaseUrl') ? SourceKind.githubEnterprise : SourceKind.github,
          name: config.containsKey('apiBaseUrl') ? 'GitHub · ${_host(_v('apiBaseUrl'))}' : 'GitHub',
          config: config,
          secret: secret,
        ),
      SourceOption.gitlab => (
          kind: SourceKind.gitlab,
          name: 'GitLab · ${_host(_v('baseUrl').isEmpty ? 'https://gitlab.com' : _v('baseUrl'))}',
          config: config,
          secret: secret,
        ),
      SourceOption.outlook => (kind: SourceKind.ics, name: 'Outlook calendar', config: config, secret: null),
      SourceOption.ics => (kind: SourceKind.ics, name: 'ICS · ${_host(_v('url'))}', config: config, secret: null),
      SourceOption.linear => (kind: SourceKind.linear, name: 'Linear', config: config, secret: secret),
      SourceOption.jira => (kind: SourceKind.jira, name: 'Jira · ${_host(_v('siteUrl'))}', config: config, secret: secret),
      SourceOption.google => (kind: SourceKind.googleCalendar, name: 'Google Calendar', config: config, secret: secret),
      SourceOption.apple => (kind: SourceKind.appleCalendar, name: 'Apple Calendar', config: config, secret: null),
      SourceOption.git => throw StateError('git uses GitSetupDialog'),
    };
  }

  Future<T> _run<T>(EngineCommand<T> cmd) async => (await ref.read(engineProvider.future)).runtime(cmd);

  Future<void> _save() async {
    final editing = widget.existing != null;
    for (final f in _fields(o)) {
      final skipSecret = f.secret && (editing || _sourceId != null);
      if (f.required && !skipSecret && _v(f.key).isEmpty) {
        setState(() => _error = '${f.label} is required');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = _draft();
      if (o == SourceOption.apple) {
        final ok = await _run(appleCalendarAccessCmd());
        if (!ok) {
          throw StateError('Calendar access was denied. Allow Ant Manager in System Settings → Privacy & Security → Calendars.');
        }
      }
      final id = _sourceId;
      if (id == null) {
        _sourceId = await _run(addSourceCmd(d.kind, d.name, d.config, secret: d.secret));
      } else {
        await _run(updateSourceCmd(id, name: d.name, config: d.config, secret: d.secret, enabled: true));
      }
      final problem = await _run(validateSourceCmd(_sourceId!));
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      await _run(syncSourceCmd(_sourceId!));
      if (!mounted) return;
      toast(context, editing ? 'Saved · syncing' : '${o.label} connected · importing the last 30 days', tone: AntTone.ok);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The loopback redirect server runs here because it must open the browser (url_launcher).
      final tokens = await GoogleOAuth().signIn((uri) async {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      });
      _googleTokens = tokens.encode();
      setState(() => _busy = false);
      await _save();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final editing = widget.existing != null;
    final googlePlaceholder = GoogleOAuth().clientId.startsWith('TODO');
    final body = <Widget>[
      if (o == SourceOption.google) ...[
        Text('Ant Manager reads events you attended (read-only). Sign-in happens in your browser.'),
        if (googlePlaceholder) ...[
          Gap(t.space.lg),
          // TODO(owner): replace the placeholder Google OAuth client (docs/OWNER_TODO.md).
          const Callout(
            child: Text('This build has a placeholder Google client id, so sign-in will fail until the owner '
                'registers the OAuth client.'),
          ),
        ],
      ],
      if (o == SourceOption.apple)
        Text('Reads everything synced into Calendar.app (iCloud, Exchange, Google…). macOS will ask for calendar access.'),
      for (final f in _fields(o)) ...[
        AntTextField(
          controller: _c[f.key],
          label: f.label,
          placeholder: f.secret && editing ? 'Saved in Keychain · leave blank to keep' : f.placeholder,
          obscureText: f.secret,
          mono: f.secret || f.key.toLowerCase().contains('url'),
          autofocus: f == _fields(o).first,
          onSubmitted: (_) => _save(),
        ),
        if (f.hint != null) Hint(f.hint!),
        Gap(t.space.lg),
      ],
      if (_error != null) ...[
        Gap(t.space.md),
        Text(_error!, style: t.typo.small.copyWith(color: t.dangerText)),
      ],
    ];
    final primary = switch (o) {
      SourceOption.google when !editing => AntButton.primary(
          label: _busy ? 'Waiting for browser…' : 'Sign in with Google',
          icon: Icons.open_in_new,
          onPressed: _busy ? null : _googleSignIn,
        ),
      SourceOption.apple when !editing => AntButton.primary(
          label: _busy ? 'Requesting…' : 'Allow calendar access',
          onPressed: _busy ? null : _save,
        ),
      _ => AntButton.primary(
          label: _busy ? 'Checking…' : (editing ? 'Save' : 'Connect'),
          onPressed: _busy ? null : _save,
        ),
    };
    return WideDialog(
      title: editing ? widget.existing!.name : 'Connect ${o.label}',
      subtitle: editing ? null : o.hint,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: body),
      leadingActions: [
        if (editing)
          AntButton(
            label: widget.existing!.enabled ? 'Disable' : 'Enable',
            variant: widget.existing!.enabled ? AntButtonVariant.danger : AntButtonVariant.secondary,
            onPressed: () async {
              await runCmd(context, ref, updateSourceCmd(widget.existing!.id, enabled: !widget.existing!.enabled));
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
      ],
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        primary,
      ],
    );
  }
}
