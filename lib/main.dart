import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/reminders_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/analytics_provider.dart';
import 'screens/login_screen.dart';
import 'screens/transactions_list_screen.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/mock_db_service.dart';
// SQLite support for desktop
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize databaseFactory for desktop platforms
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('[main] SQLite databaseFactory initialized');
  }
  
  print('[main] App starting...');
  print('[main] kIsWeb=$kIsWeb');
  
  // Charger les variables d'environnement (sauf sur web)
  if (!kIsWeb) {
    try {
      await dotenv.load();
      print('[main] ✅ dotenv.load() completed');
      print('[main] USE_REMOTE_DB=${dotenv.env['USE_REMOTE_DB']}');
      print('[main] DB_HOST=${dotenv.env['DB_HOST']}');
    } catch (e) {
      print('[main] ⚠️ .env file not loaded: $e');
    }
  } else {
    print('[main] Web platform detected, skipping dotenv.load()');
  }

  // Sur web, forcer l'utilisation de mock DB
  if (kIsWeb) {
    try {
      dotenv.env['USE_MOCK_DB'] = 'true';
      print('[main] Web: forced USE_MOCK_DB=true');
    } catch (e) {
      print('[main] Note: Using Mock DB on web');
    }
  }

  // Initialiser la base de données locale (sauf sur web)
  if (!kIsWeb) {
    try {
      print('[main] Initializing DBService (SQLite)...');
      await DBService.instance.init();
      print('[main] ✅ DBService initialized');
    } catch (e) {
      print('[main] ⚠️ DBService.init() failed: $e');
    }
  }

  // Initialize notification service
  try {
    print('[main] Initializing NotificationService...');
    await NotificationService.instance.initialize();
    print('[main] ✅ NotificationService initialized');
  } catch (e) {
    print('[main] ⚠️ NotificationService.initialize() failed: $e');
  }

  // Initialize offline sync service
  try {
    print('[main] Initializing OfflineSyncService...');
    await OfflineSyncService.instance.initialize();
    print('[main] ✅ OfflineSyncService initialized');
  } catch (e) {
    print('[main] ⚠️ OfflineSyncService.initialize() failed: $e');
  }

  // If using the mock DB for testing, ensure a test user exists
  try {
    // Accès sécurisé à dotenv
    String? useMockDb;
    try {
      useMockDb = dotenv.env['USE_MOCK_DB'];
    } catch (e) {
      // Sur web, forcer mock
      useMockDb = kIsWeb ? 'true' : null;
    }
    
    print('[main] Checking for test user... (useMockDb=$useMockDb)');
    if (useMockDb == 'true') {
      print('[main] Creating test user in MockDbService...');
      // create a default test user (email: test@example.com / password: secret123)
      final existing = await MockDbService.instance.getUserByEmail('test@example.com');
      if (existing == null) {
        await MockDbService.instance.createUser(email: 'test@example.com', password: 'secret123', displayName: 'Test User');
        print('[main] ✅ Mock test user created: test@example.com / secret123');
      } else {
        print('[main] ℹ️ Mock test user already exists: test@example.com');
      }
    }
  } catch (e) {
    print('[main] ⚠️ Error ensuring mock test user: $e');
  }
  
  print('[main] ✅ App initialization complete, running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<TransactionsProvider>(
          create: (_) => TransactionsProvider(),
        ),
        ChangeNotifierProvider<RemindersProvider>(
          create: (_) => RemindersProvider.instance,
        ),
        ChangeNotifierProvider<AnalyticsProvider>(
          create: (_) => AnalyticsProvider(),
        ),
        ChangeNotifierProvider<OfflineSyncService>(
          create: (_) => OfflineSyncService.instance,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'App Bancaire - Noé Gomes',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const EntryPoint(),
        ),
      ),
    );
  }
}

class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Selon l’état de connexion, on affiche l’écran approprié
    if (auth.isAuthenticated) {
      return const TransactionsListScreen();
    } else {
      return const LoginScreen();
    }
  }
}
