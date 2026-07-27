#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die() { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

[ -z "$PAGE_ID" ]     && die "PAGE_ID chua duoc dat trong config.sh"
[ -z "$COMPOSIO" ]    && die "COMPOSIO chua duoc dat trong config.sh"
type python3 &>/dev/null || die "python3 chua duoc cai dat"

echo "=== $PROJECT_NAME — Lap lich 30 ngay ==="
echo ""

SCHEDULE_FILE="$DIR/../logs/30day-schedule.json"
mkdir -p "$DIR/../logs" 2>/dev/null || true

# ---- 1. Facebook Insights (thong tin tham khao) ----
echo "1. Thu thap du lieu tu Facebook Insights..."
PAGE_ID="$PAGE_ID" python3 > /tmp/ag_insights_payload.json << 'PYEOF'
import json, os
payload = {
    "page_id": os.environ.get('PAGE_ID', ''),
    "metrics": "page_impressions_unique,page_engaged_users",
    "period": "days_28"
}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
INSIGHTS_RAW=$($COMPOSIO execute FACEBOOK_GET_PAGE_INSIGHTS -d @/tmp/ag_insights_payload.json 2>/dev/null)

INSIGHTS_INFO=$(echo "$INSIGHTS_RAW" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        data = json.loads(data)
    insights = []
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = data.get('data', [data])
    else:
        items = []
    print(json.dumps(items, ensure_ascii=False))
except Exception as e:
    print('[]')
" 2>/dev/null)

echo "  Insights data collected."
echo ""

# ---- 2. AI sinh lich 30 ngay ----
echo "2. AI sinh lich 30 ngay..."

GENRES_JSON=$(python3 -c "
import json
genres = '${GENRES[*]}'.split()
weights = '${GENRE_WEIGHTS[*]}'.split()
items = [{'genre': g, 'weight': int(w)} for g, w in zip(genres, weights)]
print(json.dumps(items, ensure_ascii=False))
")

SCHEDULE_PROMPT=$(PROJECT_NAME="$PROJECT_NAME" MODEL_TEXT="$MODEL_TEXT" GENRES_JSON="$GENRES_JSON" python3 << 'PYEOF'
import json, os
genres = os.environ['GENRES_JSON']
project_name = os.environ['PROJECT_NAME']
model_text = os.environ['MODEL_TEXT']

prompt = f"""Bạn là chuyên gia lập lịch nội dung cho Facebook Page "viết vội vài câu" (dự án "{project_name}").

Tạo lịch đăng bài cho 30 ngày tới, mỗi ngày 1 bài.
Yêu cầu:
- Mỗi ngày chọn 1 thể loại từ danh sách, 1 chủ đề phù hợp, 1 khung giờ đăng
- Khung giờ gợi ý cho khán giả Việt Nam: 6h, 12h, 18h, 21h
- Đa dạng thể loại, không lặp nhiều
- Phân bố đều các thể loại theo tỉ trọng: các thể loại có weight cao xuất hiện nhiều hơn

Danh sách thể loại (kèm weight):
{genres}

Trả về JSON array, mỗi phần tử có: day (1-30), genre (ten genre), topic (chủ đề), hour (khung gio), label (tên hiển thị tiếng Việt)
Chỉ trả về JSON, không giải thích."""

try:
    glist = json.loads(genres)
    prompt += f"\n\nDanh sách thể loại: {json.dumps([g['genre'] for g in glist], ensure_ascii=False)}"
except:
    pass

print(json.dumps({"prompt": prompt, "model": model_text, "temperature": 0.7}))
PYEOF
)

echo "$SCHEDULE_PROMPT" > /tmp/ag_schedule_prompt.json
SCHEDULE_RAW=$($COMPOSIO execute GEMINI_GENERATE_CONTENT -d @/tmp/ag_schedule_prompt.json 2>/tmp/ag_stderr.log)
COM_EXIT=$?
echo "$SCHEDULE_RAW" > /tmp/ag_raw_response.json
echo "$COM_EXIT" > /tmp/ag_exit_code.txt
STDERR_LOG=$(cat /tmp/ag_stderr.log)
[ -n "$STDERR_LOG" ] && echo "[STDERR] $STDERR_LOG"

SCHEDULE_JSON=$(echo "$SCHEDULE_RAW" | python3 -c "
import json, sys, re
try:
    raw = sys.stdin.read()
    d = json.loads(raw)
    text = d.get('data', {}).get('text', '') or d.get('text', '')
    if not text:
        dd = d.get('data', {})
        if isinstance(dd, dict):
            text = dd.get('text', '') or dd.get('data', '')
    match = re.search(r'\[.*\]', text, re.DOTALL)
    if match:
        schedule = json.loads(match.group())
        print(json.dumps(schedule, ensure_ascii=False))
    else:
        print(json.dumps([], ensure_ascii=False))
except:
    print(json.dumps([], ensure_ascii=False))
" 2>/dev/null)

# Validate schedule
SCHEDULE_COUNT=$(echo "$SCHEDULE_JSON" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")

if [ "$SCHEDULE_COUNT" -lt 30 ]; then
  warn "AI chi sinh duoc $SCHEDULE_COUNT ngay — can thao tac thu cong"
  echo "[DEBUG] Exit code: $COM_EXIT"
  echo "[DEBUG] Raw response (first 1000 chars):"
  echo "$SCHEDULE_RAW" | python3 -c "import sys; print(sys.stdin.read()[:1000])" 2>/dev/null
  echo "$SCHEDULE_JSON" > "$SCHEDULE_FILE"
else
  echo "  Da sinh lich cho $SCHEDULE_COUNT ngay."
  echo "$SCHEDULE_JSON" > "$SCHEDULE_FILE"
fi

echo ""

# ---- 3. Compose content cho tung ngay ----
echo "3. Soan noi dung cho 30 ngay..."
echo "  (co the mat 2-3 phut...)"

TOTAL_DAYS=$(python3 -c "import json; s=json.load(open('$SCHEDULE_FILE')); print(len(s) if isinstance(s, list) else 0)" 2>/dev/null || echo "0")
[ "$TOTAL_DAYS" -eq 0 ] && die "Khong co lich de soan"

for i in $(seq 0 $((TOTAL_DAYS - 1))); do
  DAY_DATA=$(python3 -c "
import json
s = json.load(open('$SCHEDULE_FILE'))
d = s[$i]
print(json.dumps(d, ensure_ascii=False))
" 2>/dev/null)

  DAY=$(echo "$DAY_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['day'])")
  GENRE=$(echo "$DAY_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['genre'])")
  TOPIC=$(echo "$DAY_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['topic'])")
  HOUR=$(echo "$DAY_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hour', 18))")
  LABEL=$(echo "$DAY_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('label', ''))")
  [ -z "$LABEL" ] && LABEL="$GENRE"

  echo "  Ngay $DAY ($GENRE): $TOPIC..."

  CONTENT_PROMPT=$(TOPIC="$TOPIC" MODEL_TEXT="$MODEL_TEXT" TEMPERATURE="$TEMPERATURE" python3 << 'PYEOF'
import json, os
topic = os.environ['TOPIC']
model_text = os.environ['MODEL_TEXT']
temperature = float(os.environ.get('TEMPERATURE', '0.9'))

prompt = f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".
Chủ đề hôm nay: {topic}

Viết 1 bài thơ tiếng Việt 4-8 câu.
Phong cách: tự nhiên, nhẹ nhàng, giàu hình ảnh.
Gieo vần mềm, không gượng ép.
KHÔNG sáo rỗng, KHÔNG màu mè.

Sau đó thêm dòng: HASH: 3-5 hashtag tiếng Việt phù hợp
Sau đó thêm dòng: ANH: prompt tiếng Anh tạo ảnh minh họa (watercolor style, Ghibli-inspired, dreamy, soft pastel)

Chỉ viết nội dung, không giải thích."""

print(json.dumps({"prompt": prompt, "model": model_text, "temperature": temperature}))
PYEOF
  )

  echo "$CONTENT_PROMPT" > /tmp/ag_content_${i}.json
  CONTENT_RAW=$($COMPOSIO execute GEMINI_GENERATE_CONTENT -d @/tmp/ag_content_${i}.json 2>/dev/null)
  CONTENT_TEXT=$(echo "$CONTENT_RAW" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print((d.get('data', {}).get('text', '') or d.get('text', '')).strip())
except: pass
" 2>/dev/null)

  # Parse content into parts
  POST_BODY=$(echo "$CONTENT_TEXT" | python3 -c "
import sys
text = sys.stdin.read()
if 'HASH:' in text:
    text = text.split('HASH:')[0]
if 'ANH:' in text:
    text = text.split('ANH:')[0]
print(text.strip())
" 2>/dev/null)

  HASH_TAG=$(echo "$CONTENT_TEXT" | python3 -c "
import sys
text = sys.stdin.read()
if 'HASH:' in text:
    part = text.split('HASH:')[1]
    if 'ANH:' in part:
        part = part.split('ANH:')[0]
    print(part.strip())
else:
    print('#${LABEL// /} #tho #vietvoivaicau')
" 2>/dev/null)

  IMG_PROMPT=$(echo "$CONTENT_TEXT" | python3 -c "
import sys
text = sys.stdin.read()
if 'ANH:' in text:
    print(text.split('ANH:')[1].strip())
else:
    print('$STYLE_IMAGE')
" 2>/dev/null)

  [ -z "$POST_BODY" ] && POST_BODY="Mot ngay moi, mot niem vui nho."
  [ -z "$HASH_TAG" ] && HASH_TAG="#${LABEL// /} #tho #vietvoivaicau"
  [ -z "$IMG_PROMPT" ] && IMG_PROMPT="$STYLE_IMAGE"

  POST_BODY="$POST_BODY" HASH_TAG="$HASH_TAG" IMG_PROMPT="$IMG_PROMPT" LABEL="$LABEL" SCHEDULE_FILE="$SCHEDULE_FILE" IDX="$i" python3 << 'PYEOF'
import json, os
SCHEDULE_FILE = os.environ.get('SCHEDULE_FILE', '')
i = int(os.environ.get('IDX', '0'))
post_body = os.environ.get('POST_BODY', '')
hash_tag = os.environ.get('HASH_TAG', '')
img_prompt = os.environ.get('IMG_PROMPT', '')
label = os.environ.get('LABEL', '')

s = json.load(open(SCHEDULE_FILE))
d = s[i]
d['text'] = post_body
d['hashtags'] = hash_tag
d['image_prompt'] = img_prompt
d['label'] = label
s[i] = d
with open(SCHEDULE_FILE, 'w', encoding='utf-8') as f:
    json.dump(s, f, ensure_ascii=False, indent=2)
PYEOF

  echo "    OK"
done

echo "  Hoan thanh $TOTAL_DAYS bai."
echo ""

# ---- 4. Tạo Calendar events ----
echo "4. Tao $TOTAL_DAYS events tren Google Calendar..."

FIRST_DAY=$(python3 -c "
import json
s = json.load(open('$SCHEDULE_FILE'))
if isinstance(s, list) and len(s) > 0:
    print(s[0].get('day', 1))
else:
    print(1)
" 2>/dev/null || echo "1")

# Calculate start date: first day of next month at timezone
START_DATE=$(python3 -c "
from datetime import datetime, timezone, timedelta
import json
# Use current time in +07:00
now = datetime.now(timezone(timedelta(hours=7)))
# First day of next month
if now.month == 12:
    month = 1
    year = now.year + 1
else:
    month = now.month + 1
    year = now.year
print(f'{year}-{month:02d}-01')
" 2>/dev/null || echo "$(date -d '+1 month' +%Y-%m-01 2>/dev/null || echo "2026-08-01")")

CALENDAR_EVENTS=0
for i in $(seq 0 $((TOTAL_DAYS - 1))); do
  ENTRY=$(python3 -c "
import json
s = json.load(open('$SCHEDULE_FILE'))
print(json.dumps(s[$i], ensure_ascii=False))
" 2>/dev/null)

  DAY=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('day', $i+1))")
  GENRE=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('genre', ''))")
  LABEL=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('label', d.get('genre', '')))")
  HOUR=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hour', 18))")
  TOPIC=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('topic', ''))")
  POST_TEXT=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('text', ''))")
  HASHTAGS=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hashtags', ''))")
  IMG_PROMPT=$(echo "$ENTRY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('image_prompt', ''))")

  # Calculate date: START_DATE + (DAY - 1)
  EVENT_DATE=$(python3 -c "
from datetime import datetime, timezone, timedelta
import json
start = datetime.strptime('$START_DATE', '%Y-%m-%d')
day = int('$DAY') - 1
event_date = start + timedelta(days=day)
print(event_date.strftime('%Y-%m-%d'))
" 2>/dev/null)

  SUMMARY="[$PROJECT_NAME] $LABEL"
  DESCRIPTION=$(GENRE="$GENRE" TOPIC="$TOPIC" LABEL="$LABEL" POST_TEXT="$POST_TEXT" HASHTAGS="$HASHTAGS" IMG_PROMPT="$IMG_PROMPT" python3 << 'PYEOF'
import json, os
desc = json.dumps({
    "genre": os.environ.get('GENRE', ''),
    "topic": os.environ.get('TOPIC', ''),
    "label": os.environ.get('LABEL', ''),
    "text": os.environ.get('POST_TEXT', ''),
    "hashtags": os.environ.get('HASHTAGS', ''),
    "image_prompt": os.environ.get('IMG_PROMPT', '')
}, ensure_ascii=False)
print(desc)
PYEOF
  )

  START_DATETIME="${EVENT_DATE}T${HOUR}:00:00+07:00"

  CALENDAR_ID="$CALENDAR_ID" SUMMARY="$SUMMARY" DESCRIPTION="$DESCRIPTION" START_DATETIME="$START_DATETIME" TIMEZONE="$TIMEZONE" python3 > /tmp/ag_cal_event.json << 'PYEOF'
import json, os
payload = {
    "calendar_id": os.environ.get('CALENDAR_ID', 'primary'),
    "summary": os.environ.get('SUMMARY', ''),
    "description": os.environ.get('DESCRIPTION', ''),
    "start_datetime": os.environ.get('START_DATETIME', ''),
    "event_duration_minutes": 15,
    "timezone": os.environ.get('TIMEZONE', 'UTC'),
    "create_meeting_room": False
}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
  RESULT=$($COMPOSIO execute GOOGLECALENDAR_CREATE_EVENT -d @/tmp/ag_cal_event.json 2>/dev/null)

  EVENT_ID=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        data = json.loads(data)
    rd = data.get('response_data', {})
    print(rd.get('id', '') or data.get('id', '') or 'unknown')
except: print('unknown')
" 2>/dev/null)

  if [ "$EVENT_ID" != "unknown" ] && [ -n "$EVENT_ID" ]; then
    CALENDAR_EVENTS=$((CALENDAR_EVENTS + 1))
    echo "  [$CALENDAR_EVENTS/$TOTAL_DAYS] $(echo "$SUMMARY" | head -c 40) @ ${HOUR}:00"
  else
    warn "  Loi tao event ngay $DAY"
  fi
done

echo ""
echo "=== Ket qua ==="
echo "  Lich 30 ngay: $SCHEDULE_FILE"
echo "  Calendar events: $CALENDAR_EVENTS/$TOTAL_DAYS"
echo ""
echo "De kiem tra calendar:"
echo "  ~/.composio/composio execute GOOGLECALENDAR_EVENTS_LIST -d '{\"calendarId\":\"$CALENDAR_ID\",\"timeMin\":\"${START_DATE}T00:00:00+07:00\",\"orderBy\":\"startTime\",\"singleEvents\":true}'"
