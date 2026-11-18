import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/narrative_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/wins_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';
import 'services/python_service.dart';
import 'services/data_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: AntManagerApp()));
}

class AntManagerApp extends StatelessWidget {
  const AntManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      primary: const Color(0xFF6366F1),
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF3F4F6),
    );

    return MaterialApp(
      title: 'Ant Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF374151),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.white,
          indicatorColor: colorScheme.primary.withOpacity(0.1),
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade400),
          selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEEF2FF),
          side: const BorderSide(color: Color(0xFFC7D2FE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF4338CA),
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      home: const AppShell(),
    );
  }
}

enum AppSection { narrative, timeline, wins, notes, settings }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  AppSection _section = AppSection.narrative;
  final PythonService _python = PythonService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthAsync = ref.watch(backendHealthProvider);

    return healthAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting backend services...'),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertOctagon,
                    size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  'Critical Backend Error',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The Ant Manager Python core failed to start. This is usually due to a configuration or code error.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => ref.refresh(backendHealthProvider),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Try to Restart Services'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (_) {
        final page = switch (_section) {
          AppSection.narrative => NarrativeScreen(
              python: _python,
              onNavigateToSettings: () =>
                  setState(() => _section = AppSection.settings),
            ),
          AppSection.timeline => TimelineScreen(python: _python),
          AppSection.wins => WinsScreen(python: _python),
          AppSection.notes => NotesScreen(python: _python),
          AppSection.settings => SettingsScreen(python: _python),
        };

        return Scaffold(
          body: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // App Logo
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/logo.webp', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: _section.index,
                        onDestinationSelected: (idx) =>
                            setState(() => _section = AppSection.values[idx]),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.scrollText),
                            selectedIcon: Icon(LucideIcons.scrollText),
                            label: Text('Narrative'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.history),
                            selectedIcon: Icon(LucideIcons.history),
                            label: Text('Timeline'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.trophy),
                            selectedIcon: Icon(LucideIcons.trophy),
                            label: Text('Wins'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.stickyNote),
                            selectedIcon: Icon(LucideIcons.stickyNote),
                            label: Text('Notes'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.settings),
                            selectedIcon: Icon(LucideIcons.settings),
                            label: Text('Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          LucideIcons.user,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  // Add a subtle rounding to the content area
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
