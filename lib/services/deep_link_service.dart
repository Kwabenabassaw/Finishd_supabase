import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:finishd/Model/Watchprovider.dart';

class DeepLinkService {
  /// Maps TMDB Provider IDs to app URL schemes
  static final Map<int, String> _providerSchemes = {
    8: 'nflx://', // Netflix
    9: 'primevideo://', // Amazon Prime
    337: 'disneyplus://', // Disney+
    384: 'hbomax://', // HBO Max (now Max)
    15: 'hulu://', // Hulu
    2: 'videos://', // Apple TV
    531: 'paramountplus://', // Paramount+
    386: 'peacocktv://', // Peacock
    350: 'appletv://', // Apple TV+
    1899: 'max://', // Max (new)
  };

  /// Maps TMDB Provider IDs to their official website search/browse URLs
  static final Map<int, String> _providerWebUrls = {
    8: 'https://www.netflix.com/search?q=', // Netflix search
    9: 'https://www.amazon.com/s?k=', // Prime Video search
    337: 'https://www.disneyplus.com/search/', // Disney+ search
    384: 'https://www.max.com/search?q=', // Max search
    15: 'https://www.hulu.com/search?q=', // Hulu search
    2: 'https://tv.apple.com/search?term=', // Apple TV search
    531: 'https://www.paramountplus.com/search/', // Paramount+
    386: 'https://www.peacocktv.com/search?q=', // Peacock
    350: 'https://tv.apple.com/search?term=', // Apple TV+
    1899: 'https://www.max.com/search?q=', // Max
  };

  /// Maps TMDB Provider IDs to their home page URLs (fallback)
  static final Map<int, String> _providerHomeUrls = {
    8: 'https://www.netflix.com',
    9: 'https://www.primevideo.com',
    337: 'https://www.disneyplus.com',
    384: 'https://www.max.com',
    15: 'https://www.hulu.com',
    2: 'https://tv.apple.com',
    531: 'https://www.paramountplus.com',
    386: 'https://www.peacocktv.com',
    350: 'https://tv.apple.com',
    1899: 'https://www.max.com',
  };

  /// Tries to launch the streaming app or website.
  Future<void> launchProvider({
    required int providerId,
    required String providerName,
    required String title,
  }) async {
    // 1. Try to open the installed app (mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      final scheme = _providerSchemes[providerId];
      if (scheme != null) {
        final Uri appUri = Uri.parse(scheme);
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    // 2. Try to open the platform's search page with the title
    final searchUrl = _providerWebUrls[providerId];
    if (searchUrl != null) {
      final encodedTitle = Uri.encodeComponent(title);
      final Uri searchUri = Uri.parse('$searchUrl$encodedTitle');
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 3. Fallback to the platform's home page
    final homeUrl = _providerHomeUrls[providerId];
    if (homeUrl != null) {
      final Uri homeUri = Uri.parse(homeUrl);
      if (await canLaunchUrl(homeUri)) {
        await launchUrl(homeUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    print('Could not launch $providerName');
  }

  /// Static helper to be compatible with existing calls
  static Future<void> openStreamingProvider(
    WatchProvider provider,
    String title,
    String? webUrl, // Kept for backward compatibility but not used
  ) async {
    final service = DeepLinkService();
    await service.launchProvider(
      providerId: provider.providerId,
      providerName: provider.providerName,
      title: title,
    );
  }
}
