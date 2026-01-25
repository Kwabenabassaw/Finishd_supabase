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
import 'package:flutter/services.dart'; // Added for SystemNavigator
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:finishd/firebase_options.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/services/push_notification_service.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:finishd/theme/app_colors.dart';
import 'package:finishd/db/objectbox/objectbox_store.dart'; // ObjectBox Init
import 'package:finishd/services/chat_sync_service.dart'; // Offline-first chat
import 'package:finishd/provider/chat_provider.dart'; // Chat state management
import 'package:finishd/services/deep_link_service.dart';
import 'package:finishd/services/seen_sync_service.dart'; // Video deduplication sync
import 'package:finishd/services/moderation_listener_service.dart'; // Real-time moderation
import 'package:finishd/services/moderation_notification_handler.dart'; // Moderation warnings

// GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize ObjectBox (Offline-First DB)
    await ObjectBoxStore.create();

    // Initialize ChatSyncService (after ObjectBox is ready)
    await ChatSyncService.instance.initialize();

    // Initialize SeenSyncService for video deduplication (sync on login)
    SeenSyncService.instance.syncOnLogin();

    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    // Initialize Moderation Listener (real-time ban/suspension detection)
    ModerationListenerService.instance.init(navigatorKey);

    // Initialize Moderation Notification Handler (warnings display)
    ModerationNotificationHandler.instance.init(navigatorKey);

    // Start push notifications in the background so they don't block the UI
    PushNotificationService().initialize(navigatorKey).catchError((e) {
      debugPrint('Push Notification initialization error: $e');
    });

    // Initialize Deep Link Handling
    DeepLinkService().initialize(navigatorKey);

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
          ChangeNotifierProvider(
            create: (_) => YoutubeFeedProvider()..initialize(),
          ),
          ChangeNotifierProvider(create: (_) => ChatProvider()..initialize()),
          ChangeNotifierProxyProvider<ChatProvider, UnreadStateProvider>(
            create: (context) => UnreadStateProvider(context.read<ChatProvider>())..initialize(),
            update: (context, chatProvider, unreadProvider) => unreadProvider!,
          ),
          ChangeNotifierProvider(create: (_) => AiAssistantProvider()),
          Provider<AuthService>(create: (_) => AuthService()),
        ],
        child: MyApp(navigatorKey: navigatorKey),
      ),
    );
  } catch (e) {
    debugPrint('App initialization error: $e');
    // Still run the app even if initialization fails, allowing the UI to handle errors
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'An initialization error occurred. Please restart the app.',
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
    final navProvider = Provider.of<AppNavigationProvider>(context, listen: false);
    final selectedIndex = navProvider.currentIndex;

    // 1. If not on Home tab (index 0), navigate to Home tab
    if (selectedIndex != 0) {
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1A8927).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final selectedIndex = navProvider.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackPress(context);
      },
      child: Scaffold(
        extendBody: false, // Ensure content sits ABOVE the nav bar, not behind it

        body: IndexedStack(index: selectedIndex, children: _pages),

        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex,
          onTap: (index) {
            final feedProvider = context.read<YoutubeFeedProvider>();
            if (index != 0) {
              feedProvider.pauseAll();
            } else if (index == 0 && selectedIndex != 0) {
              feedProvider.resumeCurrent();
            }

            // Mark messages as viewed when tapping the Messages tab (Index 3)
            if (index == 3) {
              Provider.of<UnreadStateProvider>(context, listen: false).markMessagesAsViewed();
            }

            navProvider.setTab(index);
          },
          showUnselectedLabels: false,
          iconSize: 24,
          enableFeedback: true,

          unselectedItemColor: selectedIndex == 0
              ? Colors.white54
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.black45,

          selectedItemColor: const Color(0xFF1A8927),

          backgroundColor: selectedIndex == 0
              ? Colors.black
              : Theme.of(context).cardColor,

          elevation: 8,

          items: [
            if (Platform.isAndroid) ...[
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.solidHouse),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.compass_fill),
                label: 'Discover',
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
            if (Platform.isIOS) ...[
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.solidHouse),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                label: 'Discover',
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
