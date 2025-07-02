import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  ApiService({required this.baseUrl, required this.defaultHeaders});

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: defaultHeaders);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'GET request failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? queryParams,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);
    final response = await http.post(
      uri,
      headers: defaultHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'POST request failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // PUT, DELETE if needed later
}
