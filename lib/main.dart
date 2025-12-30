import 'package:finishd/Discover/Search.dart';
import 'package:finishd/Home/Friends/friendsTab.dart';
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
import 'dart:io' show Platform;

import 'package:finishd/provider/app_navigation_provider.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:finishd/firebase_options.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/services/push_notification_service.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:finishd/db/objectbox/objectbox_store.dart'; // ObjectBox Init
import 'package:finishd/services/chat_sync_service.dart'; // Offline-first chat
import 'package:finishd/provider/chat_provider.dart'; // Chat state management

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

    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    // Start push notifications in the background so they don't block the UI
    PushNotificationService().initialize(navigatorKey).catchError((e) {
      debugPrint('Push Notification initialization error: $e');
    });

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
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Finishd',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

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
  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<AppNavigationProvider>();
    final selectedIndex = navProvider.currentIndex;

    return Scaffold(
      extendBody: true, // IMPORTANT for transparency

      body: IndexedStack(index: selectedIndex, children: _pages),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: (index) {
          // Handle video playback on tab switch
          final feedProvider = context.read<YoutubeFeedProvider>();
          if (index != 0) {
            feedProvider.pauseAll();
          } else if (index == 0 && selectedIndex != 0) {
            // Only resume if actually switching TO home from another tab
            feedProvider.resumeCurrent();
          }
          navProvider.setTab(index);
        },
        showUnselectedLabels: false,
        iconSize: 24,
        enableFeedback: true,

        unselectedItemColor: const Color.fromARGB(255, 1, 118, 32),

        // 🔥 Make transparent on Home tab
        backgroundColor: selectedIndex == 0 ? Colors.transparent : null,

        // ⚡ Remove shadow when transparent
        elevation: selectedIndex == 4 ? 8 : 8,

        items: [
          if (Platform.isAndroid) ...[
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.houseChimney),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.compass_fill),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.solidBookmark, size: 24.0),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.signalMessenger),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.user, size: 24.0),
              label: 'Profile',
            ),
          ],
          if (Platform.isIOS) ...[
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.houseChimney),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.bookmark, size: 24.0),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.solidMessage),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.user, size: 24.0),
              label: 'Profile',
            ),
          ],
        ],
      ),
    );
  }
}
