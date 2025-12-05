class TvShowCredit {
    TvShowCredit({
        required this.cast,
        required this.crew,
        required this.id,
    });

    final List<Cast> cast;
    final List<Cast> crew;
    final int? id;

    TvShowCredit copyWith({
        List<Cast>? cast,
        List<Cast>? crew,
        int? id,
    }) {
        return TvShowCredit(
            cast: cast ?? this.cast,
            crew: crew ?? this.crew,
            id: id ?? this.id,
        );
    }

    factory TvShowCredit.fromJson(Map<String, dynamic> json){ 
        return TvShowCredit(
            cast: json["cast"] == null ? [] : List<Cast>.from(json["cast"]!.map((x) => Cast.fromJson(x))),
            crew: json["crew"] == null ? [] : List<Cast>.from(json["crew"]!.map((x) => Cast.fromJson(x))),
            id: json["id"],
        );
    }

    Map<String, dynamic> toJson() => {
        "cast": cast.map((x) => x.toJson()).toList(),
        "crew": crew.map((x) => x.toJson()).toList(),
        "id": id,
    };

    @override
    String toString(){
        return "$cast, $crew, $id, ";
    }
}

class Cast {
    Cast({
        required this.adult,
        required this.gender,
        required this.id,
        required this.knownForDepartment,
        required this.name,
        required this.originalName,
        required this.popularity,
        required this.profilePath,
        required this.character,
        required this.creditId,
        required this.order,
        required this.department,
        required this.job,
    });

    final bool? adult;
    final int? gender;
    final int? id;
    final String? knownForDepartment;
    final String? name;
    final String? originalName;
    final double? popularity;
    final String? profilePath;
    final String? character;
    final String? creditId;
    final int? order;
    final String? department;
    final String? job;

    Cast copyWith({
        bool? adult,
        int? gender,
        int? id,
        String? knownForDepartment,
        String? name,
        String? originalName,
        double? popularity,
        String? profilePath,
        String? character,
        String? creditId,
        int? order,
        String? department,
        String? job,
    }) {
        return Cast(
            adult: adult ?? this.adult,
            gender: gender ?? this.gender,
            id: id ?? this.id,
            knownForDepartment: knownForDepartment ?? this.knownForDepartment,
            name: name ?? this.name,
            originalName: originalName ?? this.originalName,
            popularity: popularity ?? this.popularity,
            profilePath: profilePath ?? this.profilePath,
            character: character ?? this.character,
            creditId: creditId ?? this.creditId,
            order: order ?? this.order,
            department: department ?? this.department,
            job: job ?? this.job,
        );
    }

    factory Cast.fromJson(Map<String, dynamic> json){ 
        return Cast(
            adult: json["adult"],
            gender: json["gender"],
            id: json["id"],
            knownForDepartment: json["known_for_department"],
            name: json["name"],
            originalName: json["original_name"],
            popularity: json["popularity"],
            profilePath: json["profile_path"],
            character: json["character"],
            creditId: json["credit_id"],
            order: json["order"],
            department: json["department"],
            job: json["job"],
        );
    }

    Map<String, dynamic> toJson() => {
        "adult": adult,
        "gender": gender,
        "id": id,
        "known_for_department": knownForDepartment,
        "name": name,
        "original_name": originalName,
        "popularity": popularity,
        "profile_path": profilePath,
        "character": character,
        "credit_id": creditId,
        "order": order,
        "department": department,
        "job": job,
    };

    @override
    String toString(){
        return "$adult, $gender, $id, $knownForDepartment, $name, $originalName, $popularity, $profilePath, $character, $creditId, $order, $department, $job, ";
    }
}
