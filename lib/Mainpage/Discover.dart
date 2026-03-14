
import 'package:finishd/Discover/discover.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Widget/animated_wallpaper.dart';

class Discover extends StatefulWidget {
  const Discover({super.key});

  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  @override
  Widget build(BuildContext context) {
    return AnimatedWallpaper(
      child: ExploreScreen(),
    );
  }
}