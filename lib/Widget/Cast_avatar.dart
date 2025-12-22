import 'package:finishd/Model/MovieCredit.dart' as movie;
import 'package:finishd/Model/TvShowcredit.dart' as show;
import 'package:finishd/tmbd/fetchCredit.dart';
import 'package:finishd/screens/actor_profile_screen.dart';
import 'package:flutter/material.dart';

Fetchcredit credit = Fetchcredit();

class CastAvatar extends StatefulWidget {
  final int showId;
  const CastAvatar({super.key, required this.showId});

  @override
  State<CastAvatar> createState() => _CastAvatarState();
}

class _CastAvatarState extends State<CastAvatar> {
  late Future<show.TvShowCredit> _creditFuture;

  @override
  void initState() {
    super.initState();
    _creditFuture = credit.fetchTvShowCredit(widget.showId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<show.TvShowCredit>(
      future: _creditFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {}
        final List<show.Cast> data = snapshot.data!.cast;
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActorProfileScreen(
                          personId: data[index].id!,
                          personName: data[index].name!,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          data
                              .map(
                                (image) =>
                                    "https://image.tmdb.org/t/p/w500${image.profilePath}",
                              )
                              .toList()[index],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data[index].name!.length > 15
                            ? '${data[index].name!.substring(0, 15)}...'
                            : data[index].name!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class MovieCastAvatar extends StatefulWidget {
  final int movieId;
  const MovieCastAvatar({super.key, required this.movieId});

  @override
  State<MovieCastAvatar> createState() => _MovieCastAvatar();
}

class _MovieCastAvatar extends State<MovieCastAvatar> {
  late Future<movie.MovieCredit> _creditFuture;

  @override
  void initState() {
    super.initState();
    _creditFuture = credit.fetchMovieCredit(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<movie.MovieCredit>(
      future: _creditFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {}
        final List<movie.Cast> data = snapshot.data!.cast;
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActorProfileScreen(
                          personId: data[index].id!,
                          personName: data[index].name!,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          data
                              .map(
                                (image) =>
                                    "https://image.tmdb.org/t/p/w500${image.profilePath}",
                              )
                              .toList()[index],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data[index].name!.length > 15
                            ? '${data[index].name!.substring(0, 15)}...'
                            : data[index].name!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
