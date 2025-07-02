import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiTranslateScreen extends StatefulWidget {
  const AiTranslateScreen({super.key});

  @override
  State<AiTranslateScreen> createState() => _AiTranslateScreenState();
}

class _AiTranslateScreenState extends State<AiTranslateScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _nsibidi;
  List<Map<String, String>> _segments = [];
  String? _contextNote;

  Future<void> _translateText() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _loading = true;
      _nsibidi = null;
      _segments = [];
      _contextNote = null;
    });

    try {
      final res = await http.post(
        Uri.parse('https://your-backend.com/ai/nsibidi-translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': input}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        setState(() {
          _nsibidi = data['nsibidi'] ?? '';
          _contextNote = data['note'];
          _segments =
              (data['segments'] as List<dynamic>)
                  .map<Map<String, String>>(
                    (item) => {
                      'word': (item['word'] ?? '').toString(),
                      'meaning': (item['meaning'] ?? '').toString(),
                      'nsibidi': (item['nsibidi'] ?? '').toString(),
                    },
                  )
                  .toList();
        });
      } else {
        throw Exception('AI service error: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Translation failed. Try again.')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildSegmentRow(Map<String, String> segment) {
    return Card(
      child: ListTile(
        title: Text(segment['word'] ?? ''),
        subtitle: Text(segment['meaning'] ?? ''),
        trailing: Text(
          segment['nsibidi'] ?? '',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nsibidi AI Translate')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _translateText(),
              decoration: InputDecoration(
                labelText: 'Enter Igbo name, word, or sentence',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _translateText,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const CircularProgressIndicator()
            else if (_nsibidi != null) ...[
              const Text(
                'Nsibidi Translation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(_nsibidi!, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 20),
              if (_segments.isNotEmpty) ...[
                const Text(
                  'Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ..._segments.map(_buildSegmentRow),
              ],
              if (_contextNote != null) ...[
                const SizedBox(height: 20),
                Text(
                  _contextNote!,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
