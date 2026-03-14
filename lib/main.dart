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
import 'dart:io' show Platform;
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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:finishd/models/simkl/trakt_model.dart';
import 'package:finishd/workers/schedule_worker.dart';
import 'package:finishd/services/moderation_notification_handler.dart'; // Moderation warnings
import 'package:finishd/screens/video_upload_screen.dart';
import 'package:finishd/provider/video_upload_provider.dart';
import 'package:finishd/widgets/upload_progress_overlay.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:finishd/config/env.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('DEBUG: WidgetsFlutterBinding initialized');

    // Initialize dotenv
    debugPrint('DEBUG: Loading .env file');
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('DEBUG: .env loaded successfully');
    } catch (e) {
      debugPrint(
        'WARNING: .env file not found or failed to load. '
        'Falling back to dart-define/environment defaults. Error: $e',
      );
    }

    // Feed-safe image cache limits (avoid bitmap growth during long scroll sessions).
    PaintingBinding.instance.imageCache.maximumSize = 150;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 120 << 20; // 120 MB

    // Initialize Supabase
    debugPrint('DEBUG: Initializing Supabase...');
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    debugPrint('DEBUG: Supabase initialized');

    // Initialize ObjectBox (Offline-First DB)
    debugPrint('DEBUG: Initializing ObjectBox...');
    await ObjectBoxStore.create();
    debugPrint('DEBUG: ObjectBox initialized');

    // Initialize Hive for Schedule Caching
    debugPrint('DEBUG: Initializing Hive...');
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(ShowReleaseAdapter());
    }
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(ReleaseScheduleAdapter());
    }
    debugPrint('DEBUG: Hive initialized');

    // Calculate delay until 9 AM GMT
    final now = DateTime.now().toUtc();
    var next9AmGmt = DateTime.utc(now.year, now.month, now.day, 9, 0);
    if (now.isAfter(next9AmGmt)) {
      next9AmGmt = next9AmGmt.add(const Duration(days: 1));
    }
    final initialDelay = next9AmGmt.difference(now);

    // Initialize Workmanager for Daily Schedule Notifications
    debugPrint('DEBUG: Initializing Workmanager...');
    Workmanager().initialize(callbackDispatcher);
    // Register the daily background task
    Workmanager().registerPeriodicTask(
      "dailyReleaseScheduleTask",
      releaseScheduleTask,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    debugPrint('DEBUG: Workmanager initialized');

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

    // Ensure edge-to-edge drawing and transparent status bar globally
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Make it transparent
        systemNavigationBarColor: Colors.transparent, // Optionally transparent
        statusBarIconBrightness: Brightness.dark, // Default for light themes, will be overridden by theme usually
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

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
    FlutterNativeSplash.remove();
    final stackTraceString = stackTrace.toString();
    final stackPreview = stackTraceString.length > 500
        ? '${stackTraceString.substring(0, 500)}...'
        : stackTraceString;

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
                  Text('Stack: $stackPreview'),
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
              // Configure top-level builders to handle both System UI and Upload Overlays
              builder: (context, child) {
                final brightness = Theme.of(context).brightness;
                final isDark = brightness == Brightness.dark;
                
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    // Android: Dark icons if theme is light, Light icons if theme is dark
                    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    // iOS: Light bar if theme is light (dark icons), Dark bar if theme is dark (light icons)
                    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  ),
                  child: UploadProgressOverlay(
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              navigatorObservers: [
                routeObserver,
                AnalyticsService().getAnalyticsObserver(),
                ScreenTimeObserver(),
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
  const CommsTab(),
  Messages(),
  Profile(),
];

class _HomePageState extends State<HomePage> {
  DateTime? _lastBackPressTime;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final internalIndex = navProvider.currentIndex;
    
    // Check if user is an approved creator
    final isCreator = user != null &&
        user.role == 'creator' &&
        user.creatorStatus == 'approved';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackPress(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: false,
        body: IndexedStack(index: internalIndex, children: _pages),
        drawer: isCreator
            ? Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A8927),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: user.profileImage.isNotEmpty
                                ? NetworkImage(user.profileImage)
                                : null,
                            child: user.profileImage.isEmpty
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Creator Studio',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_box_rounded),
                      title: const Text('Create'),
                      onTap: () {
                        Navigator.pop(context); // Close drawer first
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const VideoUploadScreen()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.analytics),
                      title: const Text('Analytics'),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Implement Analytics screen routing
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help & Support'),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Implement Help screen routing
                      },
                    ),
                  ],
                ),
              )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: internalIndex,
          onTap: (index) async {
            final feedProvider = context.read<YoutubeFeedProvider>();
            if (index != 0) {
              feedProvider.pauseAll();
            } else if (index == 0 && internalIndex != 0) {
              feedProvider.resumeCurrent();
            }

            if (index == 3) {
              // Messages
              Provider.of<UnreadStateProvider>(
                context,
                listen: false,
              ).markMessagesAsViewed();
            }

            navProvider.setTab(index);
          },
          showUnselectedLabels: false,
          iconSize: 24,
          enableFeedback: true,
          unselectedItemColor: internalIndex == 0
              ? Colors.white54
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.black45,
          selectedItemColor: const Color(0xFF1A8927),
          backgroundColor: internalIndex == 0
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
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.userGroup, size: 24.0),
                label: 'Comms',
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
              const BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.userGroup, size: 24.0),
                label: 'Comms',
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
