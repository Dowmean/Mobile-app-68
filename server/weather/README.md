
> ตรวจให้ `WEATHER_SERVER_PATH` ใน `clients\app.py` ชี้ไปที่ `server\weather\weather.py` ให้ถูกต้อง

---

## ความต้องการ
- Windows + PowerShell/VS Code Terminal
- Python 3.10 ขึ้นไป
- อินเทอร์เน็ต (เรียก `api.weather.gov`)

---

## ติดตั้งและรัน

```powershell
cd C:\Mobileapp\clients

# 2) สร้างและเปิดใช้งาน venv
python -m venv venv
venv\Scripts\Activate

# 3) ติดตั้งไลบรารี
pip install fastapi uvicorn jinja2 mcp httpx python-dotenv

# 4) รันเว็บ (ไดเรกทอรีที่มี app.py)
cd C:\Mobileapp\clients\clients
..\venv\Scripts\Activate
uvicorn app:app --reload
