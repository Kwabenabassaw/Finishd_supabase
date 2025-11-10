import 'package:finishd/WatchlistPage/Watched.dart';
import 'package:finishd/WatchlistPage/SavedMovies.dart' as saved;
import 'package:flutter/material.dart';


class Watchlist extends StatefulWidget {
  const Watchlist({super.key});

  @override
  State<Watchlist> createState() => _WatchlistState();
}

class _WatchlistState extends State<Watchlist> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar:  AppBar(
         title: Text("Watchlist"),
         centerTitle: true,
         bottom: TabBar(
          tabAlignment: TabAlignment.fill,
          indicatorColor: Colors.green,
          labelColor: Colors.black,
          tabs: 
          
          [
            Tab(
              text: "Watchlist",
            ),
            Tab(
              text: "Saved",
            )
          ],
         ),
        ),
        body: TabBarView(children: 
        [
            Watched(),
            saved.Watched(),
        ]
        

        ),
      ),
      
    );
  }
}
