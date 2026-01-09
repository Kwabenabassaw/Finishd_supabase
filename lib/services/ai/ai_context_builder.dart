import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/movie_ratings_model.dart';

class AiContextBuilder {
  /// Builds structured AI context for a movie
  static String buildMovieContext({
    required MovieDetails movie,
    required MovieRatings ratings,
  }) {
    final buffer = StringBuffer();

    // ───────────────── AI ROLE ─────────────────
    buffer.writeln(
      'You are Finishd’s AI Movie Assistant. '
      'You are factual, neutral, concise, and spoiler-safe.',
    );
    buffer.writeln(
      'You must not speculate, exaggerate, or invent information.',
    );
    buffer.writeln('');

    // ───────────────── MOVIE DATA ─────────────────
    buffer.writeln('### MOVIE CONTEXT (FACTUAL DATA)');
    buffer.writeln('Title: ${movie.title}');
    buffer.writeln('Release Date: ${movie.releaseDate ?? "Unknown"}');
    buffer.writeln(
      'Genres: ${movie.genres.isNotEmpty ? movie.genres.map((g) => g.name).join(", ") : "Not available"}',
    );
    buffer.writeln(
      'Runtime: ${movie.runtime != null ? "${movie.runtime} minutes" : "Unknown"}',
    );
    buffer.writeln('Overview: ${movie.overview}');

    if (movie.tagline != null && movie.tagline!.isNotEmpty) {
      buffer.writeln('Tagline: ${movie.tagline}');
    }

    // ───────────────── RATINGS ─────────────────
    buffer.writeln('\n### RATINGS & STATS');
    buffer.writeln(
      'TMDB Rating: ${movie.voteAverage}/10 (${movie.voteCount} votes)',
    );
    buffer.writeln('IMDb Rating: ${ratings.imdbRating}');
    buffer.writeln('Rotten Tomatoes: ${ratings.rotten}');
    buffer.writeln('Metacritic: ${ratings.metacritic}');

    if (ratings.awards.isNotEmpty) {
      buffer.writeln('Awards: ${ratings.awards}');
    }

    // ───────────────── GUIDELINES ─────────────────
    buffer.writeln('\n### GUIDELINES');
    buffer.writeln('1. Only answer questions about "${movie.title}".');
    buffer.writeln(
      '2. Do NOT disclose plot twists, major reveals, or the ending (No Spoilers).',
    );
    buffer.writeln(
      '3. Prioritize the context above as your primary source of truth.',
    );
    buffer.writeln(
      '4. If the question is not answered by the context, you MAY use your general knowledge or search tools to answer accurately (e.g. cast, trivia, soundtrack).',
    );
    buffer.writeln(
      '5. Ensure any outside information is strictly relevant to "${movie.title}".',
    );
    buffer.writeln(
      '6. You MAY discuss premise, themes, tone, cast, and general reception without revealing story outcomes.',
    );
    buffer.writeln(
      '7. Ratings and popularity indicate public reception, not factual quality.',
    );
    buffer.writeln(
      '8. Keep responses under 120 words unless the user asks for a detailed explanation.',
    );

    return buffer.toString();
  }

  /// Builds structured AI context for a TV show
  static String buildTvShowContext({
    required TvShowDetails show,
    required MovieRatings ratings,
  }) {
    final buffer = StringBuffer();

    // ───────────────── AI ROLE ─────────────────
    buffer.writeln(
      'You are Finishd’s AI TV Show Assistant. '
      'You are factual, neutral, concise, and spoiler-safe.',
    );
    buffer.writeln(
      'You must not speculate, exaggerate, or invent information.',
    );
    buffer.writeln('');

    // ───────────────── TV SHOW DATA ─────────────────
    buffer.writeln('### TV SHOW CONTEXT (FACTUAL DATA)');
    buffer.writeln('Title: ${show.name}');
    buffer.writeln('First Air Date: ${show.firstAirDate ?? "Unknown"}');

    if (show.lastAirDate != null) {
      buffer.writeln('Last Air Date: ${show.lastAirDate}');
    }

    buffer.writeln('Status: ${show.status}');
    buffer.writeln(
      'Genres: ${show.genres.isNotEmpty ? show.genres.map((g) => g.name).join(", ") : "Not available"}',
    );
    buffer.writeln('Seasons: ${show.numberOfSeasons}');
    buffer.writeln('Episodes: ${show.numberOfEpisodes}');
    buffer.writeln(
      'Networks: ${show.networks.isNotEmpty ? show.networks.map((n) => n.name).join(", ") : "Not available"}',
    );
    buffer.writeln('Overview: ${show.overview}');

    if (show.tagline != null && show.tagline!.isNotEmpty) {
      buffer.writeln('Tagline: ${show.tagline}');
    }

    // ───────────────── RATINGS ─────────────────
    buffer.writeln('\n### RATINGS & STATS');
    buffer.writeln(
      'TMDB Rating: ${show.voteAverage}/10 (${show.voteCount} votes)',
    );
    buffer.writeln('IMDb Rating: ${ratings.imdbRating}');
    buffer.writeln('Rotten Tomatoes: ${ratings.rotten}');
    buffer.writeln('Metacritic: ${ratings.metacritic}');

    if (ratings.awards.isNotEmpty) {
      buffer.writeln('Awards: ${ratings.awards}');
    }

    // ───────────────── GUIDELINES ─────────────────
    buffer.writeln('\n### GUIDELINES');
    buffer.writeln('1. Only answer questions about "${show.name}".');
    buffer.writeln(
      '2. Do NOT disclose plot twists, major reveals, or the ending (No Spoilers).',
    );
    buffer.writeln(
      '3. Prioritize the context above as your primary source of truth.',
    );
    buffer.writeln(
      '4. If the question is not answered by the context, you MAY use your general knowledge or search tools to answer accurately (e.g. cast, trivia, soundtrack).',
    );
    buffer.writeln(
      '5. Ensure any outside information is strictly relevant to "${show.name}".',
    );
    buffer.writeln(
      '6. You MAY discuss premise, themes, tone, cast, and general reception without revealing story outcomes.',
    );
    buffer.writeln(
      '7. Ratings and popularity indicate public reception, not factual quality.',
    );
    buffer.writeln(
      '8. Keep responses under 120 words unless the user asks for a detailed explanation.',
    );

    return buffer.toString();
  }
}
