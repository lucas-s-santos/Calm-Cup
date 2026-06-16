import '../utils/json_parse.dart';

class Stadium {
  final String city;
  final String timezone;
  final String name;
  final int capacity;
  final String coords;
  final String? cc;

  const Stadium({
    required this.city,
    required this.timezone,
    required this.name,
    required this.capacity,
    required this.coords,
    this.cc,
  });

  factory Stadium.fromJson(Map<String, dynamic> json) {
    return Stadium(
      city: json['city'] as String,
      timezone: json['timezone'] as String,
      name: json['name'] as String,
      capacity: asIntOr(json['capacity'], 0),
      coords: json['coords'] as String,
      cc: json['cc'] as String?,
    );
  }

  String get countryFlag {
    const flags = {'us': '🇺🇸', 'mx': '🇲🇽', 'ca': '🇨🇦'};
    return flags[cc?.toLowerCase()] ?? '🏟️';
  }
}
