import 'package:finishd/Model/MovieCredit.dart' as movie;
import 'package:finishd/Model/TvShowcredit.dart' as show;
import 'package:finishd/tmbd/fetchCredit.dart';
import 'package:flutter/material.dart';

Fetchcredit credit = Fetchcredit();

class CastAvatar extends StatefulWidget {
  final int showId;
  const CastAvatar({super.key, required this.showId});

  @override
  State<CastAvatar> createState() => _CastAvatarState();
}

class _CastAvatarState extends State<CastAvatar> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: credit.fetchTvShowCredit(widget.showId),
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
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: credit.fetchMovieCredit(widget.movieId),
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
              );
            },
          ),
        );
      },
    );
  }
}
