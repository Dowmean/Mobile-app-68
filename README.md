
แอป Flutter สร้างทีมโปเกมอน (จำกัด 3 ตัว) ใช้ **GetX** + **GetStorage** และดึงข้อมูลจาก **PokeAPI**. รองรับ Web/Android


วิดีโอการทำงาน:([Click me!](https://drive.google.com/file/d/1bbEk6ohKuw77CSKM2FINZvz4-k1SxQGw/view?usp=sharing))

## คุณสมบัติ
- เลือกโปเกมอน 3 ตัวจากกริดด้านล่าง (แตะเพื่อเพิ่ม/แทนที่, กากบาทเพื่อลบ)
- ตั้งชื่อทีม / ปุ่มรีเฟรช (⟲) เคลียร์ช่องเลือก
- บันทึกทีม, แก้ไข, ลบ โปเกมอน(เมนู ⋮ บนการ์ดทีม)
- โหลดทีมล่าสุดอัตโนมัติ (persist ด้วย GetStorage)
- 
## Install
- Tools:
  - Dart 3.5.4
  - Flutter 3.27.3 
  - JDK: jdk-17.0.12
  
# How to run 
```bash
cd Mobile-app-68
flutter pub get
flutter run -d chrome      # รันบนเว็บ
# หรือ
flutter run                # รันบน Android emulator

