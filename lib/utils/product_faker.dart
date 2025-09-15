// lib/utils/product_faker.dart
import 'dart:math';
import 'package:faker/faker.dart';
import '../models/product.dart';

class ProductFaker {
  final _rng = Random();
  final _faker = Faker();

  static const characters = [
    'Hello Kitty', 'My Melody', 'Kuromi', 'Pompompurin', 'Cinnamoroll',
  ];
  static const items = [
    'Plush', 'Mug', 'Hoodie', 'Tote Bag', 'Phone Case', 'Keychain', 'Notebook',
  ];

  String _img(String seed) => 'https://picsum.photos/seed/$seed/600/600';
  double _price() => ((_rng.nextInt(4301) + 690) / 100.0); // 6.90..49.90
  T _pick<T>(List<T> xs) => xs[_rng.nextInt(xs.length)];

  Future<List<Product>> seedPocketBase(
    ProductRepository repo, {
    int count = 20,
  }) async {
    final out = <Product>[];
    for (var i = 0; i < count; i++) {
      final c = _pick(characters);
      final it = _pick(items);
      final name = '$c $it';
      final img = _img('$c-$it-$i-${_faker.guid.guid()}');

      final p = await repo.create(
        name: name,
        price: _price(),
        imageUrl: img, // ใช้ url อย่างเดียว ตามสคีมาปัจจุบัน
      );
      out.add(p);
    }
    return out;
  }
}
