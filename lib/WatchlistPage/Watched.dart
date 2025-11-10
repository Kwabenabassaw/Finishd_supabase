import 'package:flutter/material.dart';

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
      body: Container(
        margin: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          
          padding: const EdgeInsets.all(8),
          children: List.generate(10, (index) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),

              ),
              elevation: 4,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ Movie Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w500/9Gtg2DzBhmYamXBS1hKAhiwbBKS.jpg',
                      fit: BoxFit.cover,
                      height: 220,
                      width: double.infinity,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                                     
                      children: [ 
                        Text(
                          "Doctor Strange in the Multiverse of Madness",
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                       const Spacer(),
                        Icon(Icons.play_circle_fill_rounded,size: 30,color: Colors.green,applyTextScaling: true,)
                      ],
                    ),
                  )
                ,


                 
                  Column(
                    children: [
                          Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: LinearProgressIndicator(
                      value: 0.6, // between 0.0 and 1.0
                      color: Colors.green,
                      backgroundColor: Colors.grey[300],
                      minHeight: 8,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    
                  ),
                 
               Row(
                  children: [
                    Padding(padding: 
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: 
                    const Text(
                    "00:36:14/2:30:05",
                    textAlign:TextAlign.start,
                    style: TextStyle(color: Colors.black54,fontSize: 10),

                  ),
                   
                    
                    )
                  ],
               ),
               
                    ],
                  ),
                 
              


                  // ✅ Optional progress percentage text
                 
                 
                ],
                
              ),
            );
          }),
        ),
      ),
    );
  }
}
