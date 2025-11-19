import 'package:url_launcher/url_launcher.dart';

Map<int, String> providerSearchUrls = {
  // 🔥 Major Streaming Platforms
  8: "https://www.netflix.com/search?q=",                  // Netflix
  9: "https://www.amazon.com/s?k=",                        // Amazon Prime Video
  337: "https://www.disneyplus.com/search?q=",             // Disney+
  15: "https://www.hulu.com/search?q=",                    // Hulu
  350: "https://tv.apple.com/search?term=",                // Apple TV+
  384: "https://www.max.com/search?q=",                    // Max (HBO Max)
  531: "https://www.paramountplus.com/search/?q=",         // Paramount+
  386: "https://www.peacocktv.com/search?q=",              // Peacock

  // 🔥 Rent / Buy Platforms
  192: "https://www.youtube.com/results?search_query=",    // YouTube
  3: "https://play.google.com/store/search?q=",            // Google Play Movies
  7: "https://www.vudu.com/content/movies/search?q=",      // Vudu
  68: "https://www.microsoft.com/en-us/search?q=",         // Microsoft Store
  2: "https://itunes.apple.com/search?term=",              // iTunes (Apple)

  // 🔥 Other Popular Streaming Services
  296: "https://www.crunchyroll.com/search?q=",            // Crunchyroll
  122: "https://www.amctheatres.com/search?q=",            // AMC+
  257: "https://watch.amazon.com/search?q=",               // Amazon Channels
  190: "https://www.criterionchannel.com/search?q=",       // Criterion Channel
  177: "https://www.starz.com/us/en/search?q=",            // Starz
  151: "https://www.showtime.com/#/search?q=",             // Showtime
  188: "https://www.nowtv.com/search?q=",                  // Now TV (UK)
  283: "https://www.bbc.co.uk/iplayer/search?q=",          // BBC iPlayer
  232: "https://www.itv.com/search?q=",                    // ITV Hub
  100: "https://www.sky.com/search?q=",                    // Sky Go

  // 🔥 Anime Streaming
  72: "https://www.funimation.com/search/?q=",             // Funimation
  27: "https://www.hidive.com/search?q=",                  // HIDIVE

  // 🔥 Free Streaming Services
  175: "https://tubitv.com/search?q=",                     // Tubi
  201: "https://www.pluto.tv/search/?q=",                  // Pluto TV
  237: "https://therokuchannel.roku.com/search?q=",        // Roku Channel

  // 🔥 European / Global
  35: "https://www.canalplus.com/search?q=",               // Canal+
  426: "https://www.cmore.com/sok?q=",                     // C More
  356: "https://www.viaplay.com/search?q=",                // Viaplay
};


/// 🔥 Opens the streaming provider with the movie title as the search query
Future<void> openStreamingProvider({
  required int providerId,
  required String title,
}) async {
  if (!providerSearchUrls.containsKey(providerId)) {
    print("❌ Provider ID not supported");
    return;
  }

  final encodedTitle = Uri.encodeComponent(title);
  final url = providerSearchUrls[providerId]! + encodedTitle;
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    print("❌ Could not launch: $url");
  }
}
