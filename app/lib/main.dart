import 'package:flutter/material.dart';

import 'screens/today_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/wins_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';
import 'services/python_service.dart';

void main() {
  runApp(const AntManagerApp());
}

class AntManagerApp extends StatelessWidget {
  const AntManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ant Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4B5563)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

enum AppSection { today, timeline, wins, notes, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.today;
  final PythonService _python = PythonService();

  @override
  Widget build(BuildContext context) {
    final page = switch (_section) {
      AppSection.today => TodayScreen(python: _python),
      AppSection.timeline => TimelineScreen(python: _python),
      AppSection.wins => WinsScreen(python: _python),
      AppSection.notes => NotesScreen(python: _python),
      AppSection.settings => SettingsScreen(python: _python),
    };

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _section.index,
            onDestinationSelected: (idx) => setState(() => _section = AppSection.values[idx]),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: Text('Today')),
              NavigationRailDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: Text('Timeline')),
              NavigationRailDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: Text('Wins')),
              NavigationRailDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt), label: Text('Notes')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Wiring this screen next...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
