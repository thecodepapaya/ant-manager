/// Settings screen: AI models (first), Schedule, Backup, Templates, General.
library;

import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import 'ai_models_tab.dart';
import 'backup_tab.dart';
import 'general_tab.dart';
import 'kit.dart';
import 'schedule_tab.dart';
import 'templates_tab.dart';

enum SettingsTab { ai, schedule, backup, templates, general }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initial = SettingsTab.ai});
  final SettingsTab initial;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsTab _tab = widget.initial;

  @override
  Widget build(BuildContext context) {
    return TokensScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTopBar(
            title: 'Settings',
            center: AntTabs<SettingsTab>(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              tabs: const [
                AntTab(value: SettingsTab.ai, label: 'AI models'),
                AntTab(value: SettingsTab.schedule, label: 'Schedule'),
                AntTab(value: SettingsTab.backup, label: 'Backup'),
                AntTab(value: SettingsTab.templates, label: 'Templates'),
                AntTab(value: SettingsTab.general, label: 'General'),
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              SettingsTab.ai => const AiModelsTab(),
              SettingsTab.schedule => const ScheduleTab(),
              SettingsTab.backup => const BackupTab(),
              SettingsTab.templates => const TemplatesTab(),
              SettingsTab.general => const GeneralTab(),
            },
          ),
        ],
      ),
    );
  }
}
