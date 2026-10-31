import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/services/api_service.dart';
import 'package:nketa/services/web_backend.dart';

class OpenAIService extends ApiService {
  OpenAIService()
    : super(
        baseUrl: WebBackend.isEnabled
            ? WebBackend.baseUrl
            : (dotenv.env['OPENAI_API_BASE_URL'] ?? 'https://api.openai.com/v1'),
        defaultHeaders: WebBackend.isEnabled
            ? const {'Content-Type': 'application/json'}
            : {
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

      if (WebBackend.isEnabled) {
        final response = await WebBackend.post('/openaiChat', body: body);
        final decoded = WebBackend.decode(response);
        if (decoded is Map && decoded['choices'] != null) {
          return decoded['choices'][0]['message']['content']?.toString().trim();
        }
        return null;
      }

      final response = await post('/chat/completions', body: body);
      if (response != null && response['choices'] != null) {
        return response['choices'][0]['message']['content']?.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
