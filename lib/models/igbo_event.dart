class IgboEvent {
  final String name;
  final String description;
  final DateTime date;
  final String? location;
  final String? imageUrl;
  final bool recurring;

  IgboEvent({
    required this.name,
    required this.description,
    required this.date,
    this.location,
    this.imageUrl,
    this.recurring = false,
  });

  factory IgboEvent.fromJson(Map<String, dynamic> json) {
    return IgboEvent(
      name: json['name'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      location: json['location'],
      imageUrl: json['imageUrl'],
      recurring: json['recurring'] ?? false,
    );
  }
}
