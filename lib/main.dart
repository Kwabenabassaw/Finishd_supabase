import 'package:finishd/Discover/Search.dart';
import 'package:finishd/Home/Friends/friendsTab.dart';
import 'package:finishd/services/analytics_service.dart';
import 'package:finishd/Home/Search.dart';
import 'package:finishd/Home/commentScreen.dart';
import 'package:finishd/Mainpage/Discover.dart';
import 'package:finishd/Mainpage/Home.dart';
import 'package:finishd/Mainpage/Messages.dart';
import 'package:finishd/Mainpage/Profile.dart';
import 'package:finishd/Mainpage/Watchlist.dart';
import 'package:finishd/notification/mainScreent.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/provider/onboarding_provider.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/provider/theme_provider.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/provider/actor_provider.dart';
import 'package:finishd/provider/ai_assistant_provider.dart';
import 'package:sizer/sizer.dart';
import 'dart:io' show Platform;

import 'package:finishd/provider/app_navigation_provider.dart';
import 'package:finishd/provider/unread_state_provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

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
          ChangeNotifierProvider(create: (_) => ChatProvider()..initialize()),
          ChangeNotifierProxyProvider<ChatProvider, UnreadStateProvider>(
            create: (context) =>
                UnreadStateProvider(context.read<ChatProvider>())..initialize(),
            update: (context, chatProvider, unreadProvider) => unreadProvider!,
          ),
          ChangeNotifierProvider(create: (_) => AiAssistantProvider()),
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
  Watchlist(),
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
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final internalIndex = navProvider.currentIndex; // 0..4

    // Check if user is an approved creator
    final isCreator =
        user != null &&
        user.role == 'creator' &&
        user.creatorStatus == 'approved';

    // Map internal index to visual index
    // If creator: skip the + button at visual index 2 (6 items: 0,1,+,3,4,5)
    // If not creator: no + button (5 items: 0,1,2,3,4)
    final visualIndex = isCreator
        ? (internalIndex >= 2 ? internalIndex + 1 : internalIndex)
        : internalIndex;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackPress(context);
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(index: internalIndex, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: visualIndex,
          onTap: (index) async {
            // Handle Plus Button (Index 2) - only if creator
            if (isCreator && index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VideoUploadScreen()),
              );
              return;
            }

            // Map visual index back to internal index
            // If creator: 0->0, 1->1, 3->2, 4->3, 5->4
            // If not creator: direct mapping 0->0, 1->1, 2->2, 3->3, 4->4
            final newInternalIndex = isCreator
                ? (index > 2 ? index - 1 : index)
                : index;

            final feedProvider = context.read<YoutubeFeedProvider>();
            if (newInternalIndex != 0) {
              feedProvider.pauseAll();
            } else if (newInternalIndex == 0 && internalIndex != 0) {
              feedProvider.resumeCurrent();
            }

            if (newInternalIndex == 3) {
              // Messages (internal index 3)
              Provider.of<UnreadStateProvider>(
                context,
                listen: false,
              ).markMessagesAsViewed();
            }

            navProvider.setTab(newInternalIndex);
          },
          showUnselectedLabels: false,
          iconSize: 24,
          enableFeedback: true,
          unselectedItemColor: visualIndex == 0
              ? Colors.white54
              : Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : Colors.black45,
          selectedItemColor: const Color(0xFF1A8927),
          backgroundColor: visualIndex == 0
              ? Colors.black
              : Theme.of(context).cardColor,
          elevation: 8,
          items: [
            // Android
            if (Platform.isAndroid) ...[
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.solidHouse),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.compass_fill),
                label: 'Discover',
              ),

              // PLUS BUTTON - only for creators
              if (isCreator)
                BottomNavigationBarItem(
                  icon: Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, color: Colors.black, size: 24),
                    ),
                  ),
                  label: 'Create',
                ),

              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.solidBookmark, size: 24.0),
                label: 'Watchlist',
              ),
              BottomNavigationBarItem(
                icon: Consumer<UnreadStateProvider>(
                  builder: (context, unreadProvider, child) {
                    return Badge(
                      isLabelVisible: unreadProvider.hasNewActivity,
                      smallSize: 8,
                      label: null,
                      backgroundColor: const Color(0xFF1A8927),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.14159),
                        child: const FaIcon(FontAwesomeIcons.signalMessenger),
                      ),
                    );
                  },
                ),
                label: "Messages",
              ),
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.imagePortrait, size: 24.0),
                label: 'Profile',
              ),
            ],

            // iOS
            if (Platform.isIOS) ...[
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.solidHouse),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                label: 'Discover',
              ),

              // PLUS BUTTON - only for creators
              if (isCreator)
                BottomNavigationBarItem(
                  icon: Container(
                    width: 42,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914), // Finishd Red
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                  label: 'Create',
                ),

              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.bookmark, size: 24.0),
                label: 'Watchlist',
              ),
              BottomNavigationBarItem(
                icon: Consumer<UnreadStateProvider>(
                  builder: (context, unreadProvider, child) {
                    return Badge(
                      isLabelVisible: unreadProvider.hasNewActivity,
                      smallSize: 8,
                      label: null,
                      backgroundColor: const Color(0xFF1A8927),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.14159),
                        child: const FaIcon(FontAwesomeIcons.solidMessage),
                      ),
                    );
                  },
                ),
                label: "Messages",
              ),
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.imagePortrait, size: 24.0),
                label: 'Profile',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
