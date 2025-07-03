class StoryItem {
  final String title;
  final String author;
  final String? coverImage;
  final String? audio;
  final String text;
  final String category;
  final String? excerpt;
  final String? source;

  StoryItem({
    required this.title,
    required this.author,
    this.coverImage,
    this.audio,
    required this.text,
    required this.category,
    this.excerpt,
    this.source,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      title: json['title'] as String,
      author: json['author'] as String,
      coverImage: json['cover_image'] as String?,
      audio: json['audio'] as String?,
      text: json['text'] as String,
      category: json['category'] as String,
      excerpt: json['excerpt'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'cover_image': coverImage,
    'audio': audio,
    'text': text,
    'category': category,
    'excerpt': excerpt,
    'source': source,
  };
}
