import 'package:finishd/Widget/ImageSlideshow.dart';
import 'package:flutter/material.dart';
import '../widget/movie_card.dart';
import '../widget/community_avatar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
      var currentpage = 0;
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final List<String> imageUrls = [
      'https://image.tmdb.org/t/p/w500/9Gtg2DzBhmYamXBS1hKAhiwbBKS.jpg',
      'https://image.tmdb.org/t/p/w500/8UlWHLMpgZm9bx6QYh0NFoq67TZ.jpg',
      'https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
    ];


    String ChangeText(int index){
        if (index == 0){
            return "Doctor Strange";
        }else if (index == 1){
          return "Wonder Woman";
        }
        else{
          return "The Matrix";
        }
    }
  
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Explore', style: TextStyle(color: Colors.black,)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: const [
          Icon(Icons.search, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎬 Top Featured Banner
              
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    ImageSlideshow(
                      changedIndex:(index){
                        
                      setState(() {
                        currentpage =index;
                      });
                      }
                    )
                    ,
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ChangeText(currentpage),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Action   Adventure',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Watch Trailer',style: 
                            TextStyle(color: Colors.white)
                            ,),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 👥 Suggested Communities
              const Text(
                "Suggested Communities",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const CommunityAvatarList(),

              const SizedBox(height: 20),

              // 🔥 Trending Now
              const Text("Trending Now",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              const MovieHorizontalList(),

              const SizedBox(height: 20),

              // 🆕 New Releases
              const Text("New Releases",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              const MovieHorizontalList(),
            ],
          ),
        ),
      ),









      
    );
  }
}
