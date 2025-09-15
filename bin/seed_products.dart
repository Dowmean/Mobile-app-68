// bin/seed_products.dart
import 'dart:math';
import 'package:pocketbase/pocketbase.dart';
import 'package:faker/faker.dart';

const pbBaseUrl = 'http://127.0.0.1:8090';   // เปลี่ยนตามเซิร์ฟเวอร์คุณ
const superEmail = 'admin@gmail.com';
const superPassword = '12345678';
const collection = 'products';

Future<void> main() async {
  final pb = PocketBase(pbBaseUrl);
  await _loginAdminOrSuperuser(pb, superEmail, superPassword);

  final rnd = Random();
  final faker = Faker();

  String img(String seed) => 'https://picsum.photos/seed/$seed/600/600';
  double price() => ((rnd.nextInt(4301) + 690) / 100.0);
  const characters = ['Hello Kitty','My Melody','Kuromi','Pompompurin','Cinnamoroll'];
  const items = ['Plush','Mug','Hoodie','Tote Bag','Phone Case','Keychain','Notebook','Figure'];

  for (var i = 1; i <= 100; i++) {
    final c  = characters[rnd.nextInt(characters.length)];
    final it = items[rnd.nextInt(items.length)];
    final name = '$c $it';
    final imageUrl = img('$c-$it-$i-${faker.guid.guid()}');

    try {
      await pb.collection(collection).create(body: {
        'name': name,
        'price': price(),
        'imageUrl': imageUrl,
      });
      print('[$i/100] ✓ $name');
    } catch (e) {
      print('[$i/100] ✗ $name -> $e');
    }
  }

  print('Done.');
}

/// ล็อกอินให้ครอบจักรวาล:
/// 1) พยายาม superusers (สำหรับ PB ใหม่)
/// 2) ถ้าไม่มี superusers ใน SDK → ลอง admins (PB เก่า)
/// 3) ถ้ายังไม่ได้ → ยิง raw POST ไปที่ /api/superusers/auth-with-password แล้ว save token เอง
Future<void> _loginAdminOrSuperuser(PocketBase pb, String email, String password) async {
  // 1) superusers ผ่าน dynamic (กันกรณี SDK เก่าไม่มี getter)
  try {
    await (pb as dynamic).superusers.authWithPassword(email, password);
    print('Superuser authenticated (SDK).');
    return;
  } catch (_) {
    // ผ่านไปลองวิธีถัดไป
  }

  // 2) admins (สำหรับเซิร์ฟเวอร์รุ่นเก่า)
  try {
    await pb.admins.authWithPassword(email, password);
    print('Admin authenticated (SDK).');
    return;
  } catch (_) {
    // ผ่านไปลองวิธีถัดไป
  }

  // 3) raw call → /api/superusers/auth-with-password (สำหรับเซิร์ฟเวอร์ใหม่ + SDK เก่า)
  try {
    final res = await pb.send(
      '/api/superusers/auth-with-password',
      method: 'POST',
      body: {'identity': email, 'password': password},
    );
    final token = res['token'] as String;
    // model ใส่อะไรก็ได้/ไม่ใส่ก็ได้—สำคัญคือ token
    pb.authStore.save(token, res['superuser'] ?? res['admin'] ?? res['record']);
    print('Superuser authenticated (raw).');
    return;
  } catch (e) {
    // ถ้ายังพัง แสดงว่า baseUrl ไม่ตรง/บัญชีไม่ถูก/เซิร์ฟเวอร์ไม่ใช่รุ่นที่คิด
    rethrow;
  }
}
