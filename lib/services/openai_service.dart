import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:the_igbo_bible/services/api_service.dart';

class OpenAIService extends ApiService {
  OpenAIService()
    : super(
        baseUrl:
            dotenv.env['OPENAI_API_BASE_URL'] ?? 'https://api.openai.com/v1',
        defaultHeaders: {
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY'] ?? ''}',
          'Content-Type': 'application/json',
        },
      );

  Future<String?> generateTranslation(String prompt, {int? maxTokens}) async {
    try {
      final body = {
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      };
      if (maxTokens != null) {
        body['max_tokens'] = maxTokens;
      }
      final response = await post('/chat/completions', body: body);
      // print("openai response: ${response['choices']}");
      if (response != null && response['choices'] != null) {
        return response['choices'][0]['message']['content']?.trim();
      } else {
        return null;
      }
    } catch (e) {
      // print('OpenAIService error: $e');
      return null;
    }
  }
}
