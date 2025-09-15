// lib/models/product.dart
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;

DateTime? _asDateTime(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class Product {
  final String id;
  final String name;
  final double price;
  final String? image;             // ถ้าอนาคตมี field file ชื่อ "image"
  final String? imageUrl;          // URL หรือ path assets
  final String? resolvedImageUrl;  // ลิงก์พร้อมแสดง (ไฟล์ PB > imageUrl)
  final DateTime? created;
  final DateTime? updated;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.imageUrl,
    this.resolvedImageUrl,
    this.created,
    this.updated,
  });

  Map<String, dynamic> toBody() => {
        'name': name,
        'price': price,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };

  static Product fromRecord(RecordModel r, PocketBase pb) {
    final d = r.data;
    final imgFile = (d['image'] as String?)?.trim();
    final displayUrl = (imgFile != null && imgFile.isNotEmpty)
        ? pb.files.getUrl(r, imgFile).toString()
        : (d['imageUrl'] as String?);

    return Product(
      id: r.id,
      name: (d['name'] ?? '') as String,
      price: (d['price'] is num)
          ? (d['price'] as num).toDouble()
          : double.tryParse('${d['price']}') ?? 0.0,
      image: imgFile,
      imageUrl: d['imageUrl'] as String?,
      resolvedImageUrl: displayUrl,
      created: _asDateTime(r.created),
      updated: _asDateTime(r.updated),
    );
  }
}

class ProductRepository {
  final PocketBase pb;
  final String collection;
  const ProductRepository(this.pb, {this.collection = 'products'});

  Future<List<Product>> list({int page = 1, int perPage = 50}) async {
    final res =
        await pb.collection(collection).getList(page: page, perPage: perPage);
    return res.items.map((r) => Product.fromRecord(r, pb)).toList();
  }

  Future<Product> getById(String id) async {
    final r = await pb.collection(collection).getOne(id);
    return Product.fromRecord(r, pb);
  }

  Future<Product> create({
    required String name,
    required double price,
    List<http.MultipartFile> files = const [], // non-nullable
    String? imageUrl,
  }) async {
    final body = {
      'name': name,
      'price': price,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    };
    final r = await pb.collection(collection).create(body: body, files: files);
    return Product.fromRecord(r, pb);
  }

  Future<Product> update(
    String id, {
    String? name,
    double? price,
    List<http.MultipartFile> files = const [], // non-nullable
    String? imageUrl,
    bool clearImage = false,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (clearImage) 'image': null,
    };
    final r = await pb.collection(collection).update(
      id,
      body: body,
      files: files,
    );
    return Product.fromRecord(r, pb);
  }

  Future<void> delete(String id) => pb.collection(collection).delete(id);
}
