import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nketa/models/cosmology_item.dart';

class CosmologyService {
  // Replace with your actual GitHub raw URL
  static String cosmologyUrl =
      '${dotenv.env['JSON_URL']}igbo-cosmology/main/igbo_cosmology.json';

  Future<List<CosmologyItem>> fetchCosmologyItems() async {
    try {
      final response = await http.get(Uri.parse(cosmologyUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => CosmologyItem.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load cosmology data');
      }
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
}
