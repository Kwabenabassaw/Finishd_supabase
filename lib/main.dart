import 'package:finishd/Mainpage/Discover.dart';
import 'package:finishd/Mainpage/Home.dart';
import 'package:finishd/Mainpage/Messages.dart';
import 'package:finishd/Mainpage/Profile.dart';
import 'package:finishd/Mainpage/Watchlist.dart';
import 'package:finishd/SplashScreen/splash_screen.dart';
import 'package:finishd/onboarding/Login.dart';
import 'package:finishd/onboarding/landing.dart';
import 'package:finishd/onboarding/signUp.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     debugShowCheckedModeBanner: false,
      title: 'Finishd',
theme: ThemeData(
  useMaterial3: true,
  primaryColor: const Color(0xFF1A8927),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A8927),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF1A8927),
    secondary: const Color(0xFF1A8927),
  ),

  // 🟩 AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A8927),
    foregroundColor: Colors.white,
  ),

  // 🟩 Text styles
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black87),
    titleLarge: TextStyle(
      color: Color(0xFF1A8927),
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
  ),

  // 🟩 Elevated Buttons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A8927),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),

  // 🟩 Text Buttons
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF1A8927),
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
        '/home': (context) => const LandingScreen(),
        '/signup': (context) => SignUpScreen(),
        '/login': (context) => Login()
      }
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
     
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items:
      const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled),label: "Home"),
         BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
            BottomNavigationBarItem(
            icon: Icon(Icons.watch_later_outlined),
            label: 'Watchlist',
            ),
            BottomNavigationBarItem(icon:  Icon(Icons.messenger_outline_sharp),label: "Messages"),
            BottomNavigationBarItem(icon: Icon(Icons.person),label: 'Profile')

      ]
      ),
    );
    
  }
}
