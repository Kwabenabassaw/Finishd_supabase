import 'package:finishd/LoadingWidget/LogoLoading.dart';

import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GenericDetailsScreen extends StatefulWidget {
  const GenericDetailsScreen({super.key});

  @override
  State<GenericDetailsScreen> createState() => _GenericDetailsScreenState();
}

Trending api = Trending();

class _GenericDetailsScreenState extends State<GenericDetailsScreen> {
  bool isTV = false;

  MovieProvider get provider =>
      Provider.of<MovieProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.clearDetails();
      loadDetails();
    });
  }

  Future<void> loadDetails() async {
    /// 🔥 Get item from search result OR normal selection
    final item = provider.selectedSearchAsMediaItem ?? provider.selectedItem;

    if (item == null) return;

    MovieDetails? movie;
    TvShowDetails? show;

    if (item.mediaType == "movie") {
      movie = await api.fetchMovieDetails(item.id);
      isTV = false;
    } else if (item.mediaType == "tv") {
      show = await api.fetchDetailsTvShow(item.id);
      isTV = true;
    }

    if (show != null) provider.setShowDetail(show);
    if (movie != null) provider.setMovieDetail(movie);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MovieProvider>(context);

    /// 🔥 Prefer search selection ONLY if user came from search page
    final item = provider.selectedSearchAsMediaItem ?? provider.selectedItem;

    if (item == null) {
      return const Scaffold(body: Center(child: Text("No item selected")));
    }

    return WillPopScope(
      onWillPop: () async {
        /// 🔥 Clear search selection ONLY when navigating back
        provider.clearSearchSelection();
        return true;
      },
      child: Scaffold(
        /// 🔥 Show Movie or TV details correctly
        body: isTV
            ? (provider.showDetail != null
                  ? ShowDetailsScreen(movie: provider.showDetail!)
                  : const LogoLoadingScreen())
            : (provider.movieDetail != null
                  ? MovieDetailsScreen(movie: provider.movieDetail!)
                  : const LogoLoadingScreen()),
      ),
    );
  }
}
