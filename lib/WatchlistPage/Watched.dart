
import 'package:finishd/WatchlistPage/WatchingCard.dart';
import 'package:flutter/material.dart';
  final List<Map<String, dynamic>> _movieList = [
    {
      'posterTitle': 'RAINMAKER',
      'posterSubtitle': 'SEASON 1 | MUSIC BY CLINTON SHORTER',
      'controlTitle': 'The Rainmaker 2025',
      'episodeInfo': 'Season 1_EP07',
      'backgroundImage': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=2525&auto=format&fit=crop',
      'duration': '2:30:05',
      'currentTime': '00:36:14',
      'initialSliderValue': 0.3,
    },
    {
      'posterTitle': 'DUNE: PROPHECY',
      'posterSubtitle': 'ORIGINAL SERIES | MAX',
      'controlTitle': 'Dune: Prophecy',
      'episodeInfo': 'Season 1_EP01',
      'backgroundImage': 'https://images.unsplash.com/photo-1541963463532-d68292c34b19?q=80&w=2576&auto=format&fit=crop', // Desert aesthetic
      'duration': '0:58:12',
      'currentTime': '00:12:05',
      'initialSliderValue': 0.15,
    },
    {
      'posterTitle': 'YELLOWSTONE',
      'posterSubtitle': 'SEASON 5 PART 2',
      'controlTitle': 'Yellowstone',
      'episodeInfo': 'Season 5_EP09',
      'backgroundImage': 'https://images.unsplash.com/photo-1626814026160-2237a95fc5a0?q=80&w=2670&auto=format&fit=crop', // Western aesthetic
      'duration': '1:02:30',
      'currentTime': '00:55:00',
      'initialSliderValue': 0.85,
    },
  ];


class Watched extends StatefulWidget {
  const Watched({super.key});

  @override
  State<Watched> createState() => _WatchedState();
}

class _WatchedState extends State<Watched> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
        body: ListView.builder(
        itemCount: _movieList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: MovieCard(movieData: _movieList[index]),
          );
        },
      ),
    );
  }
}
