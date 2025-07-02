class Example {
  final String id;
  final String igbo;
  final String english;
  final String? pronunciation;
  final String? meaning;
  final String? nsibidi;

  Example({
    required this.id,
    required this.igbo,
    required this.english,
    this.pronunciation,
    this.meaning,
    this.nsibidi,
  });

  factory Example.fromJson(Map<String, dynamic> json) {
    return Example(
      id: json['id'] ?? '',
      igbo: json['igbo'] ?? '',
      english: json['english'] ?? '',
      pronunciation: json['pronunciation'],
      meaning: json['meaning'],
      nsibidi: json['nsibidi'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'igbo': igbo,
      'english': english,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'nsibidi': nsibidi,
    };
  }

  static Example fromMap(Map<String, dynamic> map) {
    return Example(
      id: map['id'] ?? '',
      igbo: map['igbo'] ?? '',
      english: map['english'] ?? '',
      pronunciation: map['pronunciation'],
      meaning: map['meaning'],
      nsibidi: map['nsibidi'],
    );
  }
}

class Definition {
  final String? wordClass;
  final List<String> definitions;
  final String? nsibidi;

  Definition({this.wordClass, required this.definitions, this.nsibidi});

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      wordClass: json['wordClass'],
      definitions: (json['definitions'] as List?)?.cast<String>() ?? [],
      nsibidi: json['nsibidi'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wordClass': wordClass,
      'definitions': definitions,
      'nsibidi': nsibidi,
    };
  }

  static Definition fromMap(Map<String, dynamic> map) {
    return Definition(
      wordClass: map['wordClass'],
      definitions: (map['definitions'] as List?)?.cast<String>() ?? [],
      nsibidi: map['nsibidi'],
    );
  }

  static String getWordClassLabel(String? code) {
    if (code == null) return '';
    switch (code.toUpperCase()) {
      case 'NNC':
        return 'Noun (Common)';
      case 'NNP':
        return 'Noun (Proper)';
      case 'V':
        return 'Verb';
      case 'ADV':
        return 'Adverb';
      case 'AV':
        return 'Active verb';
      case 'ADJ':
        return 'Adjective';
      case 'WH':
        return 'Question word';
      case 'PRON':
        return 'Pronoun';
      case 'PREP':
        return 'Preposition';
      case 'CONJ':
        return 'Conjunction';
      case 'CJN':
        return 'Conjunction';
      case 'INTJ':
        return 'Interjection';
      default:
        return code;
    }
  }
}

class TranslationResult {
  final String id;
  final String igboWord;
  final String? nsibidi;
  final List<Definition> definitions;
  final String? audioUrl;
  final Map<String, String?>? tenses;
  final Attributes? attributes;
  final List<String>? tags;
  final List<String>? relatedTerms;
  final List<Example>? examples;

  TranslationResult({
    required this.id,
    required this.igboWord,
    this.nsibidi,
    required this.definitions,
    this.audioUrl,
    this.tenses,
    this.attributes,
    this.tags,
    this.relatedTerms,
    this.examples,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    final definitions =
        (json['definitions'] as List?)
            ?.map((def) => Definition.fromJson(def))
            .toList() ??
        [];
    String? extractedNsibidi;
    // Prefer first non-empty nsibidi found in definitions
    for (var def in definitions) {
      if (extractedNsibidi == null &&
          def.nsibidi != null &&
          def.nsibidi!.trim().isNotEmpty) {
        extractedNsibidi = def.nsibidi!.trim();
      }
    }
    // Fallback to attributes.nsibidi if none found above
    if ((extractedNsibidi == null || extractedNsibidi.isEmpty) &&
        json['attributes']?['nsibidi'] is String &&
        json['attributes']['nsibidi'].trim().isNotEmpty) {
      extractedNsibidi = json['attributes']['nsibidi'].trim();
    }
    final Map<String, String?>? tenses =
        json['tenses'] != null
            ? Map<String, String?>.from(json['tenses'])
            : null;
    final attributes =
        json['attributes'] != null
            ? Attributes.fromJson(json['attributes'])
            : null;
    final tags = (json['tags'] as List?)?.cast<String>();
    final relatedTerms = (json['relatedTerms'] as List?)?.cast<String>();
    final examples =
        (json['examples'] as List?)?.map((e) => Example.fromJson(e)).toList();
    return TranslationResult(
      id: json['id'] ?? '',
      igboWord: json['word'] ?? '',
      nsibidi: extractedNsibidi,
      definitions: definitions,
      audioUrl: json['pronunciation'],
      tenses: tenses,
      attributes: attributes,
      tags: tags,
      relatedTerms: relatedTerms,
      examples: examples,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'igboWord': igboWord,
      'nsibidi': nsibidi,
      'definitions': definitions.map((d) => d.toMap()).toList(),
      'audioUrl': audioUrl,
      'tenses': tenses,
      'attributes': attributes?.toMap(),
      'tags': tags,
      'relatedTerms': relatedTerms,
      'examples': examples?.map((e) => e.toMap()).toList(),
    };
  }

  factory TranslationResult.fromMap(Map<String, dynamic> map) {
    return TranslationResult(
      id: map['id'] ?? '',
      igboWord: map['igboWord'] ?? '',
      nsibidi: map['nsibidi'],
      definitions:
          (map['definitions'] as List?)?.map((d) {
            if (d is String) {
              // Old format: just a string, wrap in Definition
              return Definition(
                wordClass: null,
                definitions: [d],
                nsibidi: null,
              );
            } else if (d is Map<String, dynamic>) {
              // New format
              return Definition.fromMap(d);
            } else {
              return Definition(
                wordClass: null,
                definitions: [],
                nsibidi: null,
              );
            }
          }).toList() ??
          [],
      audioUrl: map['audioUrl'],
      tenses:
          map['tenses'] != null
              ? Map<String, String?>.from(map['tenses'])
              : null,
      attributes:
          map['attributes'] != null
              ? Attributes.fromMap(map['attributes'])
              : null,
      tags: (map['tags'] as List?)?.cast<String>(),
      relatedTerms: (map['relatedTerms'] as List?)?.cast<String>(),
      examples:
          (map['examples'] as List?)?.map((e) => Example.fromMap(e)).toList(),
    );
  }
}

class Attributes {
  final bool isStandardIgbo;
  final bool isAccented;
  final bool isSlang;
  final bool isConstructedTerm;
  final bool isBorrowedTerm;
  final bool isStem;
  final bool isCommon;

  Attributes({
    required this.isStandardIgbo,
    required this.isAccented,
    required this.isSlang,
    required this.isConstructedTerm,
    required this.isBorrowedTerm,
    required this.isStem,
    required this.isCommon,
  });

  factory Attributes.fromJson(Map<String, dynamic> json) {
    return Attributes(
      isStandardIgbo: json['isStandardIgbo'] ?? false,
      isAccented: json['isAccented'] ?? false,
      isSlang: json['isSlang'] ?? false,
      isConstructedTerm: json['isConstructedTerm'] ?? false,
      isBorrowedTerm: json['isBorrowedTerm'] ?? false,
      isStem: json['isStem'] ?? false,
      isCommon: json['isCommon'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isStandardIgbo': isStandardIgbo,
      'isAccented': isAccented,
      'isSlang': isSlang,
      'isConstructedTerm': isConstructedTerm,
      'isBorrowedTerm': isBorrowedTerm,
      'isStem': isStem,
      'isCommon': isCommon,
    };
  }

  static Attributes fromMap(Map<String, dynamic> map) {
    return Attributes(
      isStandardIgbo: map['isStandardIgbo'] ?? false,
      isAccented: map['isAccented'] ?? false,
      isSlang: map['isSlang'] ?? false,
      isConstructedTerm: map['isConstructedTerm'] ?? false,
      isBorrowedTerm: map['isBorrowedTerm'] ?? false,
      isStem: map['isStem'] ?? false,
      isCommon: map['isCommon'] ?? false,
    );
  }
}
