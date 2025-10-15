# app.py
import json
from typing import Optional
from contextlib import AsyncExitStack

from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

# --- ปรับ path ให้ตรงกับไฟล์ server ของคุณ ---
WEATHER_SERVER_PATH = r"C:\Mobileapp\clients\server\weather\weather.py"

app = FastAPI()
templates = Jinja2Templates(directory="templates")

exit_stack = AsyncExitStack()
session: Optional[ClientSession] = None


# ---------- helpers ----------
def _to_text(content) -> str:
    """แปลงผลลัพธ์จาก FastMCP ให้เป็นข้อความล้วน อ่านง่าย"""
    # FastMCP มักคืนเป็นลิสต์ของ {type, text, ...}
    if isinstance(content, list):
        parts = []
        for item in content:
            txt = getattr(item, "text", None)
            if txt is None and isinstance(item, dict):
                txt = item.get("text") or item.get("content") or ""
            parts.append(str(txt))
        return "\n".join([p for p in parts if p])
    if isinstance(content, (dict, list)):
        return json.dumps(content, ensure_ascii=False, indent=2)
    return str(content)


# แมปชื่อรัฐแบบไทย -> รหัสรัฐ US (เพิ่มเองได้)
TH_STATE_MAP = {
    "แคลิฟอร์เนีย": "CA",
    "นิวยอร์ก": "NY",
    "เทกซัส": "TX",
    "ฟลอริดา": "FL",
    "วอชิงตัน": "WA",
}

# แปลคำหลักง่าย ๆ ให้เป็นไทย (ไม่ใช่การแปลอัตโนมัติทั้งประโยค)
BASIC_TH_REPLACE = {
    "Temperature:": "อุณหภูมิ:",
    "Wind:": "ลม:",
    "Forecast:": "พยากรณ์อากาศ:",
    "Overnight": "กลางดึก",
    "Tonight": "คืนนี้",
    "This Afternoon": "บ่ายนี้",
    "Today": "วันนี้",
    "Monday": "จันทร์",
    "Tuesday": "อังคาร",
    "Wednesday": "พุธ",
    "Thursday": "พฤหัสบดี",
    "Friday": "ศุกร์",
    "Saturday": "เสาร์",
    "Sunday": "อาทิตย์",
    "Chance of precipitation": "โอกาสฝน",
}

def _to_thai(text: str) -> str:
    for eng, th in BASIC_TH_REPLACE.items():
        text = text.replace(eng, th)
    return text


# ---------- lifecycle ----------
@app.on_event("startup")
async def startup():
    global session
    server_params = StdioServerParameters(
        command="python",
        args=[WEATHER_SERVER_PATH],
        env=None,
    )
    stdio_transport = await exit_stack.enter_async_context(stdio_client(server_params))
    stdio, write = stdio_transport
    session = await exit_stack.enter_async_context(ClientSession(stdio, write))
    await session.initialize()


@app.on_event("shutdown")
async def shutdown():
    await exit_stack.aclose()


# ---------- routes ----------
@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse(
        "index.html",
        {"request": request, "answer": None, "lang": "en"},
    )


@app.post("/ask", response_class=HTMLResponse)
async def ask(
    request: Request,
    tool: str = Form(...),
    state: str = Form(""),
    latitude: float = Form(0.0),
    longitude: float = Form(0.0),
    lang: str = Form("en"),  # <-- รับภาษาจากฟอร์ม
):
    assert session is not None, "MCP session not initialized"

    # แปลงชื่อรัฐไทย -> รหัสรัฐ (ถ้าผู้ใช้พิมพ์ไทยมา)
    state_code = TH_STATE_MAP.get(state.strip(), state.strip())

    if tool == "get_alerts":
        result = await session.call_tool("get_alerts", {"state": state_code})
    else:
        result = await session.call_tool(
            "get_forecast", {"latitude": latitude, "longitude": longitude}
        )

    raw_content = getattr(result, "content", result)
    text = _to_text(raw_content)  # ทำให้เป็นข้อความล้วน

    if lang.lower() == "th":
        text = _to_thai(text)     # แปลคำหลักเป็นไทยแบบรวดเร็ว

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "answer": text,
            "lang": lang.lower(),
        },
    )
