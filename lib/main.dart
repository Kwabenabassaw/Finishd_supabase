import 'package:finishd/Discover/Search.dart';
import 'package:finishd/Home/Friends/friendsTab.dart';
import 'package:finishd/Home/Search.dart';
import 'package:finishd/Home/commentScreen.dart';
import 'package:finishd/Home/shareSceen.dart';
import 'package:finishd/Mainpage/Discover.dart';
import 'package:finishd/Mainpage/Home.dart';
import 'package:finishd/Mainpage/Messages.dart';
import 'package:finishd/Mainpage/Profile.dart';
import 'package:finishd/Mainpage/Watchlist.dart';
import 'package:finishd/notification/mainScreent.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/provider/onboarding_provider.dart';
import 'package:finishd/provider/user_provider.dart';

import 'package:finishd/SplashScreen/splash_screen.dart';
import 'package:finishd/onboarding/CategoriesTypeMove.dart';
import 'package:finishd/onboarding/Login.dart';
import 'package:finishd/onboarding/Welcome.dart';
import 'package:finishd/onboarding/landing.dart';
import 'package:finishd/onboarding/showSelectionScreen.dart';
import 'package:finishd/onboarding/signUp.dart';
import 'package:finishd/onboarding/streamingService.dart';
import 'package:finishd/settings/settimgPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:finishd/firebase_options.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  await PushNotificationService().initialize(navigatorKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MovieProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MyApp(navigatorKey: navigatorKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Finishd',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 🟩 Elevated Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A8927),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),

        // 🟩 Bottom Navigation Bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF1A8927),
          unselectedItemColor: Colors.grey,
        ),
      ),

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
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // IMPORTANT for transparency

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,

        // 🔥 Make transparent on Home tab
        backgroundColor: _selectedIndex == 0
            ? Colors.transparent
            : Colors.white,

        // ⚡ Remove shadow when transparent
        elevation: _selectedIndex == 0 ? 0 : 8,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(
            icon: Icon(Icons.watch_later_outlined),
            label: 'Watchlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.messenger_outline_sharp),
            label: "Messages",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
