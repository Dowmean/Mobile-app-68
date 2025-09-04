import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
// เพื่อรู้ว่าเป็นเว็บหรือไม่
import 'package:flutter/foundation.dart' show kIsWeb;

class Pokemon {
  final int id;
  final String name;
  final String image; // official artwork url
  Pokemon({required this.id, required this.name, required this.image});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'image': image};
  factory Pokemon.fromMap(Map<String, dynamic> m) =>
      Pokemon(id: m['id'] as int, name: m['name'] as String, image: m['image'] as String);

  @override
  bool operator ==(Object other) => other is Pokemon && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class PokemonController extends GetxController {
  final isLoading = true.obs;
  final all = <Pokemon>[].obs;
  final filtered = <Pokemon>[].obs;
  final query = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPokemon(limit: 151);
    debounce(query, (_) => _applyFilter(), time: const Duration(milliseconds: 200));
  }

  Future<void> fetchPokemon({int limit = 90}) async {
    try {
      isLoading(true);

      final uri = Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=$limit');

      // ใส่ header ให้ http บน Android/iOS (ไม่ใส่บนเว็บ)
      final headers = <String, String>{'Accept': 'application/json'};
      if (!kIsWeb) {
        headers['User-Agent'] =
            'PokemonTeamBuilder/1.0 (student project; contact: you@example.com)';
      }

      final res = await http.get(uri, headers: headers);

      if (res.statusCode != 200) {
        Get.snackbar('Error', 'Fetch failed: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List).cast<Map<String, dynamic>>();

      final list = results.map((m) {
        final url = m['url'] as String; // .../pokemon/25/
        final parts = url.split('/');
        final id = int.tryParse(parts[parts.length - 2]) ?? 0;
        final image =
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
        return Pokemon(id: id, name: m['name'], image: image);
      }).toList();

      all.assignAll(list);
      _applyFilter();
    } catch (_) {
      Get.snackbar('Error', 'Network error');
    } finally {
      isLoading(false);
    }
  }

  void _applyFilter() {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) {
      filtered.assignAll(all);
    } else {
      filtered.assignAll(all.where((p) => p.name.toLowerCase().contains(q)));
    }
  }
}
