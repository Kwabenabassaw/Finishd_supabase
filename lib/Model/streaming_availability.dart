class StreamingAvailability {
  final Map<String, CountryAvailability> countries;

  StreamingAvailability({required this.countries});

  factory StreamingAvailability.fromJson(Map<String, dynamic> json) {
    // Structure: { "US": { "netflix": { "link": "...", "videoLink": "..." } } }
    final Map<String, CountryAvailability> countries = {};
    json.forEach((country, services) {
      countries[country] = CountryAvailability.fromJson(
        services as Map<String, dynamic>,
      );
    });
    return StreamingAvailability(countries: countries);
  }

  Map<String, dynamic> toJson() {
    return countries.map((key, value) => MapEntry(key, value.toJson()));
  }
}

class CountryAvailability {
  final Map<String, ServiceLink> services;

  CountryAvailability({required this.services});

  factory CountryAvailability.fromJson(Map<String, dynamic> json) {
    final Map<String, ServiceLink> services = {};
    json.forEach((service, data) {
      services[service] = ServiceLink.fromJson(data as Map<String, dynamic>);
    });
    return CountryAvailability(services: services);
  }

  Map<String, dynamic> toJson() {
    return services.map((key, value) => MapEntry(key, value.toJson()));
  }
}

class ServiceLink {
  final String link;
  final String? videoLink;
  final String? name;
  final String? logoUrl;

  ServiceLink({required this.link, this.videoLink, this.name, this.logoUrl});

  factory ServiceLink.fromJson(Map<String, dynamic> json) {
    return ServiceLink(
      link: json['link'] ?? "",
      videoLink: json['videoLink'],
      name: json['name'],
      logoUrl: json['logoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'link': link,
      'videoLink': videoLink,
      'name': name,
      'logoUrl': logoUrl,
    };
  }
}
