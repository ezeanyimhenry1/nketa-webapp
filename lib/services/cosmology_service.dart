import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/models/cosmology_item.dart';
import 'package:nketa/services/json_content_loader.dart';

class CosmologyService {
  static String cosmologyUrl =
      '${dotenv.env['JSON_URL']}igbo-cosmology/main/igbo_cosmology.json';

  static const String _assetPath = 'assets/data/igbo_cosmology.json';

  Future<List<CosmologyItem>> fetchCosmologyItems() async {
    try {
      final body = await JsonContentLoader.load(
        remoteUrl: cosmologyUrl,
        assetPath: _assetPath,
      );
      final List<dynamic> data = json.decode(body);
      return data.map((e) => CosmologyItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
