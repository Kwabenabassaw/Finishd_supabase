import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/Community/post_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  late GlobalKey<NavigatorState> _navigatorKey;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // Handle the initial link when the app is opened from a terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        // Small delay to ensure the navigator is ready and context is available
        Future.delayed(
          const Duration(milliseconds: 1500),
          () => _handleUri(uri),
        );
      }
    });

    // Listen for deep links while the app is running (foreground or background)
    _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) async {
    debugPrint('Deep Link Received: $uri');

    // Handle OAuth login callback (finishd://login-callback#access_token=...)
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      await _handleOAuthCallback(uri);
      return;
    }

    // Structure: https://finishd-admin.vercel.app/post/{postId}
    // pathSegments: ['post', 'POST_ID']
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
      final postId = uri.pathSegments[1];
      _navigateToPost(postId);
    }
  }

  /// Handle OAuth callback to complete authentication
  Future<void> _handleOAuthCallback(Uri uri) async {
    debugPrint('🔑 OAuth Callback Received: $uri');

    try {
      // The access_token is typically in the fragment (#access_token=...)
      // Convert fragment to query parameters for Supabase to parse
      final fragment = uri.fragment;
      debugPrint('🔑 Fragment: $fragment');

      if (fragment.isNotEmpty) {
        // Reconstruct URI with fragment as query parameters
        final callbackUri = Uri.parse('${uri.scheme}://${uri.host}?$fragment');
        debugPrint('🔑 Parsing OAuth session from: $callbackUri');

        // Let Supabase extract the session from the URL
        final response = await Supabase.instance.client.auth.getSessionFromUrl(
          callbackUri,
        );

        debugPrint(
          '✅ OAuth session established for user: ${response.session.user.email}',
        );

        // Navigate to home page after successful OAuth
        final navigatorState = _navigatorKey.currentState;
        final context = _navigatorKey.currentContext;

        debugPrint('🔑 Navigator state: $navigatorState');
        debugPrint('🔑 Context: $context');

        if (navigatorState != null && context != null) {
          // Initialize user data
          final userId = response.session.user.id;
          debugPrint('🔑 Initializing user: $userId');

          Provider.of<UserProvider>(
            context,
            listen: false,
          ).fetchCurrentUser(userId);

          debugPrint('🔑 Navigating to homepage...');

          // Use pushNamedAndRemoveUntil to clear the stack and go to homepage
          navigatorState.pushNamedAndRemoveUntil(
            'homepage',
            (route) => false, // Remove all previous routes
          );

          debugPrint('✅ Navigation to homepage triggered');
        } else {
          debugPrint('❌ Navigator state or context is null');
        }
      } else {
        debugPrint('❌ No fragment in OAuth callback URL');
      }
    } catch (e, stack) {
      debugPrint('❌ Error handling OAuth callback: $e');
      debugPrint('❌ Stack: $stack');
    }
  }

  void _navigateToPost(String postId) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    try {
      final provider = Provider.of<CommunityProvider>(context, listen: false);

      // Fetch post details from Firestore
      final post = await provider.getPost(postId);

      if (post != null && context.mounted) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                PostDetailScreen(post: post, showId: post.showId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  /// 🔥 Opens the streaming provider with the provided URL
  Future<void> launchProvider({
    required int providerId,
    required String providerName,
    required String title,
    String? directUrl,
  }) async {
    if (directUrl == null || directUrl.isEmpty) {
      debugPrint('❌ No direct URL provided for $providerName');
      return;
    }

    final uri = Uri.parse(directUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('❌ Could not launch: $directUrl');
      }
    } catch (e) {
      debugPrint('❌ Error launching $providerName: $e');
    }
  }
}
