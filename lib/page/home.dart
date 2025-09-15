// lib/page/home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/product.dart';
import '../utils/product_faker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String pbBaseUrl = 'http://127.0.0.1:8090';

  // DEV only: ล็อกอินก่อนดึง ถ้า collection ไม่เปิด public
  static const bool kUseDevLogin = true;
  static const String _devEmail = 'admin@gmail.com';
  static const String _devPassword = '12345678';

  late final PocketBase _pb;
  late final ProductRepository _repo;

  List<Product> _products = [];
  bool _loading = false;
  bool _didDevLogin = false;
  bool _subscribed = false;

  final List<Map<String, String>> topCarousel = const [
    {
      'title': 'Hello Kitty Collection',
      'price': 'from \$12.90',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/HelloKittyShoes.jpg/960px-HelloKittyShoes.jpg',
    },
    {
      'title': 'Kuromi Street Style',
      'price': 'from \$15.90',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Kuromi_clothing_and_accessories.jpg/960px-Kuromi_clothing_and_accessories.jpg',
    },
    {
      'title': 'Pompompurin Café',
      'price': 'from \$10.90',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Sanrio%2C_Pompompurin_Caf%C3%A9._Orchard_Central%2C_Singapore%2C_July_2017.jpg/1024px-Sanrio%2C_Pompompurin_Caf%C3%A9._Orchard_Central%2C_Singapore%2C_July_2017.jpg',
    },
  ];

  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _current = 0;
  Timer? _timer;

  final List<Map<String, String>> popularReviews = const [
    {'user': 'A', 'review': 'Super cute and good quality!', 'product': 'Cinnamoroll Plush'},
    {'user': 'B', 'review': 'Colors are vibrant. Love it.', 'product': 'Kuromi Hoodie'},
    {'user': 'C', 'review': 'Great for gifting!', 'product': 'Hello Kitty Mug'},
  ];

  @override
  void initState() {
    super.initState();
    _pb = PocketBase(pbBaseUrl);
    _repo = ProductRepository(_pb);
    _bootstrap();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _current = (_current + 1) % topCarousel.length;
      _pageController.animateToPage(_current, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    if (kUseDevLogin) {
      await _devLoginFallback();
    }
    await _loadProducts();
    _subscribeRealtime(); // ⟵ subscribe หลังโหลดครั้งแรก
  }

  /// ล็อกอิน fallback: superusers → admins (รองรับหลายรุ่นของ PB)
  Future<void> _devLoginFallback() async {
    Future<bool> _try(String path) async {
      try {
        final res = await _pb.send(path, method: 'POST', body: {
          'identity': _devEmail,
          'password': _devPassword,
        });
        final token = res['token'] as String;
        final model = res['superuser'] ?? res['admin'] ?? res['record'];
        _pb.authStore.save(token, model);
        _didDevLogin = true;
        debugPrint('Dev login OK via $path');
        return true;
      } catch (e) {
        debugPrint('Dev login failed at $path -> $e');
        return false;
      }
    }

    if (await _try('/api/superusers/auth-with-password')) return;
    await _try('/api/admins/auth-with-password');
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.list(perPage: 100);
      debugPrint('Loaded ${list.length} products');
      setState(() => _products = list);
    } catch (e) {
      final msg = '$e';
      final needsAuth = msg.contains('401') || msg.contains('403');
      if (needsAuth && !_didDevLogin && kUseDevLogin) {
        await _devLoginFallback();
        try {
          final list = await _repo.list(perPage: 100);
          setState(() => _products = list);
        } catch (e2) {
          _showError('Load failed (auth): $e2');
        }
      } else {
        _showError('Load failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Realtime: sync create/update/delete
  void _subscribeRealtime() {
    if (_subscribed) return;
    _subscribed = true;

    _pb.collection('products').subscribe('*', (e) {
      if (e.record == null) return;
      final p = Product.fromRecord(e.record!, _pb);
      setState(() {
        final idx = _products.indexWhere((x) => x.id == p.id);
        if (e.action == 'create' || e.action == 'update') {
          if (idx >= 0) {
            _products[idx] = p;
          } else {
            _products.insert(0, p);
          }
        } else if (e.action == 'delete') {
          if (idx >= 0) _products.removeAt(idx);
        }
      });
    });
  }

  Future<void> _seedProducts() async {
    setState(() => _loading = true);
    try {
      final fakerSvc = ProductFaker();
      await fakerSvc.seedPocketBase(_repo, count: 10);
      _showSnack('Seeded 10 products.');
      // ไม่ต้องเรียก _loadProducts(); realtime จะดันรายการใหม่เข้ามาเอง
    } catch (e) {
      _showError('Seed failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${p.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.delete(p.id);
      // realtime จะลบให้เอง
      _showSnack('Deleted.');
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _openEdit(Product p) async {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(2));
    final imageUrlCtrl = TextEditingController(text: p.imageUrl ?? p.resolvedImageUrl ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imageUrlCtrl,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim());
                        final imageUrl = imageUrlCtrl.text.trim();
                        if (name.isEmpty || price == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill name and valid price')),
                          );
                          return;
                        }
                        try {
                          await _repo.update(
                            p.id,
                            name: name,
                            price: price,
                            imageUrl: imageUrl.isEmpty ? null : imageUrl,
                          );
                          // realtime จะอัปเดตให้เอง
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (saved == true) _showSnack('Saved.');
  }

  void _showError(String m) {
    debugPrint(m);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _showSnack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_subscribed) {
      _pb.collection('products').unsubscribe('*');
    }
    _pageController.dispose();
    super.dispose();
  }

  Widget _smartImage(String? urlOrAsset) {
    if (urlOrAsset == null || urlOrAsset.isEmpty) {
      return const Center(child: Icon(Icons.image, size: 40, color: Colors.grey));
    }
    if (urlOrAsset.startsWith('assets/')) {
      return Image.asset(urlOrAsset, fit: BoxFit.cover);
    }
    return Image.network(
      urlOrAsset,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1F6),
      appBar: AppBar(
        title: const Text('EcomShop'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Seed 10',
            onPressed: _loading ? null : _seedProducts,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // ----- TOP: CAROUSEL -----
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: topCarousel.length,
                itemBuilder: (context, i) {
                  final item = topCarousel[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _smartImage(item['image']),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16, right: 16, bottom: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title']!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(item['price']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                                  child: const Text('Shop now', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  topCarousel.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i ? Colors.deepPurple : Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),

            // ----- PRODUCTS (with kebab) -----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('All Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (_loading) const SizedBox(width: 16),
                  if (_loading) const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
            if (_products.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No products yet. Tap the ⭐ “Seed 10” button to generate sample items.',
                  style: TextStyle(color: Colors.black.withOpacity(0.6)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (_, i) {
                  final p = _products[i];
                  return _ProductCard(
                    product: p,
                    smartImage: _smartImage,
                    onEdit: () => _openEdit(p),
                    onDelete: () => _deleteProduct(p),
                  );
                },
              ),
            ),

            // ----- Reviews -----
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Popular Reviews', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: popularReviews.length,
              itemBuilder: (context, index) {
                final r = popularReviews[index];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.pink.shade100, child: Text(r['user']!)),
                  title: Text(r['review']!),
                  subtitle: Text('on ${r['product']}'),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      Icon(Icons.star_half, size: 18, color: Colors.amber),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final Widget Function(String? urlOrAsset) smartImage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.smartImage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(aspectRatio: 1, child: smartImage(product.resolvedImageUrl)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text('\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        // kebab button
        Positioned(
          right: 4,
          top: 4,
          child: PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete'))),
            ],
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [
                BoxShadow(blurRadius: 6, color: Colors.black12),
              ]),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.more_vert),
            ),
          ),
        ),
      ],
    );
  }
}
