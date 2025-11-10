import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Watched extends StatefulWidget {
  const Watched({super.key});

  @override
  State<Watched> createState() => _WatchedState();
}

class _WatchedState extends State<Watched> {
  List shows = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchShows();
  }

  Future<void> fetchShows() async {
    final url = Uri.parse('https://api.tvmaze.com/shows');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        shows = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load shows');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading?
      const Center(child: CircularProgressIndicator()):
      GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
             maxCrossAxisExtent: 200, // max width per item
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 0.65,
        ),
        itemCount: shows.length,
        itemBuilder:(context, index) {
          final id = shows[index];
          final image = id['image'] !=null   ? id['image']['medium']
                    : 'https://via.placeholder.com/300x400?text=No+Image';
          final title = id['name']  ?? 'No title';
         
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadiusGeometry.circular(15)
              
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ClipRRect(
                       borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),
                          child: Image.network(
                            image,
                            height: MediaQuery.of(context).size.height *0.24,
                           width: double.infinity,
                            fit: BoxFit.fill,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(title),
                ),
              

              ],
            ),
          ) ;
          
        } ,
      )
      
    );
     
  
}
}