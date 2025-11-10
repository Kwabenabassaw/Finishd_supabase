import 'dart:convert';
import 'package:finishd/Model/shows.dart';
import 'package:http/http.dart' as http;

class Getshow {
  Future<List<Welcome>?> getshows() async {
    try{
var client = http.Client();
    var url = Uri.parse("https://api.tvmaze.com/shows");
    var response = await client.get(url);

    if (response.statusCode == 200) {
      var jsonString = response.body;
      var jsonData = jsonDecode(jsonString);

      // Convert each JSON object to a Welcome model
      List<Welcome> shows = List<Welcome>.from(
        jsonData.map((data) => Welcome.fromJson(data)),
      );

      return shows;
    } else {
      return null;
    }
    }catch(err){
      print(err.toString());
    }
    return null;
    
  }
}
