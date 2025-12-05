class MovieProvider {
    MovieProvider({
        required this.results,
    });

    final List<Result> results;

    MovieProvider copyWith({
        List<Result>? results,
    }) {
        return MovieProvider(
            results: results ?? this.results,
        );
    }

    factory MovieProvider.fromJson(Map<String, dynamic> json){ 
        return MovieProvider(
            results: json["results"] == null ? [] : List<Result>.from(json["results"]!.map((x) => Result.fromJson(x))),
        );
    }

    Map<String, dynamic> toJson() => {
        "results": results.map((x) => x.toJson()).toList(),
    };

    @override
    String toString(){
        return "$results, ";
    }
}

class Result {
    Result({
        required this.displayPriorities,
        required this.displayPriority,
        required this.logoPath,
        required this.providerName,
        required this.providerId,
    });

    final Map<String, int> displayPriorities;
    final int? displayPriority;
    final String? logoPath;
    final String? providerName;
    final int? providerId;

    Result copyWith({
        Map<String, int>? displayPriorities,
        int? displayPriority,
        String? logoPath,
        String? providerName,
        int? providerId,
    }) {
        return Result(
            displayPriorities: displayPriorities ?? this.displayPriorities,
            displayPriority: displayPriority ?? this.displayPriority,
            logoPath: logoPath ?? this.logoPath,
            providerName: providerName ?? this.providerName,
            providerId: providerId ?? this.providerId,
        );
    }

    factory Result.fromJson(Map<String, dynamic> json){ 
        return Result(
            displayPriorities: Map.from(json["display_priorities"]).map((k, v) => MapEntry<String, int>(k, v)),
            displayPriority: json["display_priority"],
            logoPath: json["logo_path"],
            providerName: json["provider_name"],
            providerId: json["provider_id"],
        );
    }

    Map<String, dynamic> toJson() => {
        "display_priorities": Map.from(displayPriorities).map((k, v) => MapEntry<String, dynamic>(k, v)),
        "display_priority": displayPriority,
        "logo_path": logoPath,
        "provider_name": providerName,
        "provider_id": providerId,
    };

    @override
    String toString(){
        return "$displayPriorities, $displayPriority, $logoPath, $providerName, $providerId, ";
    }
}
