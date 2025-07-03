class CosmologyItem {
  final String section;
  final String name;
  final String? image;
  final String? audio;
  final String description;

  CosmologyItem({
    required this.section,
    required this.name,
    this.image,
    this.audio,
    required this.description,
  });

  factory CosmologyItem.fromJson(Map<String, dynamic> json) {
    return CosmologyItem(
      section: json['section'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      audio: json['audio'] as String?,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'section': section,
    'name': name,
    'image': image,
    'audio': audio,
    'description': description,
  };
}
