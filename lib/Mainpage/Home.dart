import 'package:finishd/Home/homescreen.dart  ';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return const Scaffold(body: HomeScreen());
    } else {
      return const CupertinoApp(home: HomeScreen());
    }
  }
}
