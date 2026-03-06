import 'package:finishd/Discover/Search.dart';
import 'package:finishd/Home/Friends/friendsTab.dart';
import 'package:finishd/services/analytics_service.dart';
import 'package:finishd/Home/Search.dart';
import 'package:finishd/Home/commentScreen.dart';
import 'package:finishd/Mainpage/Discover.dart';
import 'package:finishd/Mainpage/Home.dart';
import 'package:finishd/Mainpage/Messages.dart';
import 'package:finishd/Mainpage/Profile.dart';
import 'package:finishd/Mainpage/Tabs/comms_tab.dart';
import 'package:finishd/notification/mainScreent.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/provider/onboarding_provider.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/provider/theme_provider.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/provider/actor_provider.dart';
import 'package:finishd/provider/ai_assistant_provider.dart';
import 'package:sizer/sizer.dart';

import 'package:finishd/provider/app_navigation_provider.dart';
import 'package:finishd/provider/unread_state_provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
import 'package:finishd/provider/creators_feed_provider.dart';
import 'package:finishd/provider/trailers_feed_provider.dart';
import 'package:finishd/SplashScreen/splash_screen.dart';
import 'package:finishd/onboarding/CategoriesTypeMove.dart';
import 'package:finishd/onboarding/Login.dart';
import 'package:finishd/onboarding/Welcome.dart';
import 'package:finishd/onboarding/landing.dart';
import 'package:finishd/onboarding/showSelectionScreen.dart';
import 'package:finishd/onboarding/signUp.dart';
import 'package:finishd/onboarding/streamingService.dart';
import 'package:finishd/settings/settimgPage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart'; // Added for SystemNavigator
import 'package:provider/provider.dart';
import 'package:finishd/widgets/dynamic_nav_bar.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:finishd/theme/app_colors.dart';
import 'package:finishd/db/objectbox/objectbox_store.dart'; // ObjectBox Init
import 'package:finishd/services/chat_sync_service.dart'; // Offline-first chat
import 'package:finishd/provider/chat_provider.dart'; // Chat state management
import 'package:finishd/services/deep_link_service.dart';
import 'package:finishd/services/seen_sync_service.dart'; // Video deduplication sync
import 'package:finishd/services/moderation_listener_service.dart'; // Real-time moderation
import 'package:finishd/services/moderation_notification_handler.dart'; // Moderation warnings
import 'package:finishd/screens/video_upload_screen.dart';
import 'package:finishd/provider/video_upload_provider.dart';
import 'package:finishd/widgets/upload_progress_overlay.dart';

// GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('DEBUG: WidgetsFlutterBinding initialized');

    // Feed-safe image cache limits (avoid bitmap growth during long scroll sessions).
    PaintingBinding.instance.imageCache.maximumSize = 150;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 120 << 20; // 120 MB

    // Initialize Supabase
    debugPrint('DEBUG: Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://lihaddxlyychswpkswbp.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM',
    );
    debugPrint('DEBUG: Supabase initialized');

    // Initialize ObjectBox (Offline-First DB)
    debugPrint('DEBUG: Initializing ObjectBox...');
    await ObjectBoxStore.create();
    debugPrint('DEBUG: ObjectBox initialized');

    // Initialize ChatSyncService (after ObjectBox is ready)
    debugPrint('DEBUG: Initializing ChatSyncService...');
    await ChatSyncService.instance.initialize();
    debugPrint('DEBUG: ChatSyncService initialized');

    // Initialize SeenSyncService for video deduplication (sync on login)
    debugPrint('DEBUG: Initializing SeenSyncService...');
    SeenSyncService.instance.syncOnLogin();
    debugPrint('DEBUG: SeenSyncService initialized');

    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    // Initialize Moderation Listener (real-time ban/suspension detection)
    debugPrint('DEBUG: Initializing ModerationListenerService...');
    ModerationListenerService.instance.init(navigatorKey);
    debugPrint('DEBUG: ModerationListenerService initialized');

    // Initialize Moderation Notification Handler (warnings display)
    debugPrint('DEBUG: Initializing ModerationNotificationHandler...');
    ModerationNotificationHandler.instance.init(navigatorKey);
    debugPrint('DEBUG: ModerationNotificationHandler initialized');

    // Initialize Deep Link Handling
    debugPrint('DEBUG: Initializing DeepLinkService...');
    DeepLinkService().initialize(navigatorKey);
    debugPrint('DEBUG: All services initialized, running app...');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MovieProvider()),
          ChangeNotifierProvider(create: (_) => OnboardingProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => CommunityProvider()),
          ChangeNotifierProvider(create: (_) => ActorProvider()),
          ChangeNotifierProvider(create: (_) => AppNavigationProvider()),
          ChangeNotifierProvider(create: (_) => YoutubeFeedProvider()),
          ChangeNotifierProvider(create: (_) => CreatorsFeedProvider()),
          ChangeNotifierProvider(create: (_) => TrailersFeedProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()..initialize()),
          ChangeNotifierProxyProvider<ChatProvider, UnreadStateProvider>(
            create: (context) =>
                UnreadStateProvider(context.read<ChatProvider>())..initialize(),
            update: (context, chatProvider, unreadProvider) => unreadProvider!,
          ),
          ChangeNotifierProvider(create: (_) => AiAssistantProvider()),
          ChangeNotifierProvider(create: (_) => VideoUploadProvider()),
          Provider<AuthService>(create: (_) => AuthService()),
        ],
        child: MyApp(navigatorKey: navigatorKey),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('App initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // Show the actual error on screen for debugging
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Initialization Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $e'),
                  const SizedBox(height: 16),
                  Text('Stack: ${stackTrace.toString().substring(0, 500)}...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Sizer(
          builder: (context, orientation, deviceType) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Finishd',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              navigatorObservers: [
                routeObserver,
                // Add the two analytics observers
                AnalyticsService()
                    .getAnalyticsObserver(), // For standard screen_view events
                ScreenTimeObserver(), // For our custom screen_view_duration events
              ],
              initialRoute: '/',
              builder: (context, child) {
                return UploadProgressOverlay(
                  child: child ?? const SizedBox.shrink(),
                );
              },
              routes: {
                '/': (context) => const SplashScreen(),
                '/home': (context) => LandingScreen(),
                '/signup': (context) => SignUpScreen(),
                '/login': (context) => Login(),
                'genre': (context) => GenreSelectionScreen(),
                'showSelect': (context) => ShowSelectionScreen(),
                'streaming': (context) => ServiceSelectionScreen(),
                'welcome': (context) => CompletionScreen(),
                'homepage': (context) => HomePage(),
                'Search_discover': (context) => SearchScreen(),
                'settings': (context) => SettingsScreen(),
                'homesearch': (context) => SearchScreenHome(),
                'notification': (context) => NotificationScreen(),
                'comment': (context) => CommentsScreen(),
                'friends': (context) => FriendsScreen(),
              },
            );
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

final List<Widget> _pages = [
  Home(),
  Discover(),
  const CommsTab(),
  Messages(),
  Profile(),
];

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressTime;

  Future<void> _handleBackPress(BuildContext context) async {
    final navProvider = Provider.of<AppNavigationProvider>(
      context,
      listen: false,
    );

    // 1. If not on Home tab (index 0), navigate to Home tab
    if (navProvider.currentIndex != 0) {
      navProvider.setTab(0);
      return;
    }

    // 2. If already on Home tab, check for double-press
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Press back again to exit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF1A8927).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    // 3. Second press within 2 seconds -> Exit app
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<AppNavigationProvider>();
    final internalIndex = navProvider.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackPress(context);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: internalIndex, children: _pages),
        floatingActionButton: const DynamicNavFab(),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: const DynamicNavBar(),
      ),
    );
  }
}
