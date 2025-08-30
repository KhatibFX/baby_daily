import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/edit_session_provider.dart';
import 'providers/session_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/session_history_screen.dart';
import 'screens/session_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>(
          create: (_) {
            final provider = SessionProvider();
            // Load sessions immediately when the app starts
            provider.loadSessions();
            return provider;
          },
        ),
        ChangeNotifierProvider<EditSessionProvider>(
          create: (_) => EditSessionProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Baby Daily',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    SessionScreen(),
    SessionHistoryScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = [
    'Current Session',
    'Session History',
    'Analytics',
    'Settings',
  ];

  @override
  initState() {
    super.initState();
    // Initialize settings service
    SettingsService.instance.initialize();
    // Load initial sessions
    Provider.of<SessionProvider>(context, listen: false).loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_titles[_currentIndex]),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.baby_changing_station),
            label: 'Session',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
