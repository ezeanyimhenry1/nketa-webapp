import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiNsibidiScreen extends StatefulWidget {
  const AiNsibidiScreen({super.key});

  @override
  State<AiNsibidiScreen> createState() => _AiNsibidiScreenState();
}

class _AiNsibidiScreenState extends State<AiNsibidiScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  List<Map<String, String>> _segments = [];

  Future<void> _processInput(String input) async {
    if (input.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _segments.clear();
    });

    try {
      final brokenWords = await _breakIntoIgboWords(input);
      final results = await _fetchNsibidiForWords(brokenWords);

      setState(() {
        _segments = results;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _loading = false);
    }
  }

  Future<List<String>> _breakIntoIgboWords(String input) async {
    final prompt = '''
Break this Igbo name or phrase into a list of actual Igbo words only. 
Only respond in JSON list like: ["word1", "word2", "word3"]
Input: "$input"
''';

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY'] ?? ''}',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": prompt},
        ],
        "temperature": 0.4,
      }),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final content = body['choices'][0]['message']['content'];
      final list = json.decode(content);
      return List<String>.from(list);
    } else {
      throw Exception("OpenAI error: ${response.statusCode}");
    }
  }

  Future<List<Map<String, String>>> _fetchNsibidiForWords(
    List<String> words,
  ) async {
    List<Map<String, String>> results = [];

    for (final word in words) {
      final uri = Uri.parse(
        "${dotenv.env['IGBO_API_BASE_URL'] ?? ''}/words?keyword=$word",
      );
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['IGBO_API_KEY'] ?? ''}',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final items = (data['data'] as List?) ?? [];

        if (items.isNotEmpty) {
          final first = items[0];
          final nsibidi = first['definitions'][0]?['nsibidi'] ?? '';
          final defList =
              (first['definitions'][0]?['definitions'] as List?)
                  ?.cast<String>() ??
              [];
          results.add({
            'word': word,
            'nsibidi': nsibidi,
            'meaning': defList.isNotEmpty ? defList.first : '',
          });
        } else {
          results.add({'word': word, 'nsibidi': '', 'meaning': '[Not found]'});
        }
      } else {
        results.add({
          'word': word,
          'nsibidi': '',
          'meaning': '[Error fetching]',
        });
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onSubmitted: _processInput,
            decoration: InputDecoration(
              labelText: 'Enter Igbo sentence or name',
              suffixIcon: IconButton(
                icon: const Icon(Icons.translate),
                onPressed: () => _processInput(_controller.text),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading && _segments.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _segments.length,
                itemBuilder: (_, index) {
                  final seg = _segments[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        seg['word'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(seg['meaning'] ?? ''),
                      trailing: Text(
                        seg['nsibidi']?.isNotEmpty == true
                            ? seg['nsibidi']!
                            : '❌',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
