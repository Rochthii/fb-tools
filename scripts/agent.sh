#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die() { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

[ -z "$PAGE_ID" ]     && die "PAGE_ID chua duoc dat trong config.sh"
[ -z "$COMPOSIO" ]    && die "COMPOSIO chua duoc dat trong config.sh"
type python3 &>/dev/null || die "python3 chua duoc cai dat"

echo "=== $PROJECT_NAME ==="

# ---- 0. Check if already posted today ----
echo "1. Kiem tra lich su hom nay..."

TODAY=$(date +%Y-%m-%d)
CURRENT_HOUR=$(date +%H | sed 's/^0//')
LOG_FILE="$DIR/../logs/posts.csv"

ALREADY_POSTED=$(grep -c "^$TODAY" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$ALREADY_POSTED" -gt 0 ]; then
  echo "  Hom nay da post roi — skip."
  echo ""
  echo "=== Xong (skip) ==="
  exit 0
fi

# ---- 1. Read today's events from Google Calendar ----
echo "2. Doc lich tu Google Calendar..."

TOMORROW=$(date -d "+1 day" +%Y-%m-%d)

TIME_MIN="${TODAY}T00:00:00+07:00"
TIME_MAX="${TOMORROW}T00:00:00+07:00"

EVENTS_RAW=$($COMPOSIO execute GOOGLECALENDAR_EVENTS_LIST \
  --calendar_id "$CALENDAR_ID" \
  --time_min "$TIME_MIN" \
  --time_max "$TIME_MAX" \
  --order_by "startTime" \
  --single_events true \
  2>/dev/null)

SCHEDULE_DATA=$(echo "$EVENTS_RAW" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        data = json.loads(data)
    items = data.get('items', [])
    prefix = '[$PROJECT_NAME]'
    for item in items:
        summary = item.get('summary', '')
        if summary.startswith(prefix):
            desc = item.get('description', '')
            start = item.get('start', {}).get('dateTime', '')
            print(f'DESC:{desc}')
            print(f'START:{start}')
            break
except:
    pass
" 2>/dev/null)

SCHEDULE_ENTRY=$(echo "$SCHEDULE_DATA" | grep "^DESC:" | sed 's/^DESC://')
EVENT_START=$(echo "$SCHEDULE_DATA" | grep "^START:" | sed 's/^START://')

if [ -z "$SCHEDULE_ENTRY" ]; then
  echo "  Khong co lich hom nay — dung random."
  echo ""
  exec bash "$DIR/auto-post.sh"
fi

# Check time window: only post if event hour matches current hour
EVENT_HOUR=$(echo "$EVENT_START" | python3 -c "
import sys, re
s = sys.stdin.read().strip()
# Parse RFC3339: 2026-08-01T18:00:00+07:00
m = re.search(r'T(\d{2})', s)
print(int(m.group(1)) if m else '')
" 2>/dev/null)

[ -z "$EVENT_HOUR" ] && EVENT_HOUR=-1

# Allow posting within ±2 hours of scheduled time
HOUR_DIFF=$((CURRENT_HOUR - EVENT_HOUR))
[ "${HOUR_DIFF#-}" -gt 2 ] && HOUR_DIFF=99

if [ "$HOUR_DIFF" -gt 2 ]; then
  echo "  Gio hien tai ($CURRENT_HOUR) khong khop voi event ($EVENT_HOUR) — skip."
  echo "  (Cho lan chay cron tiep theo)"
  echo ""
  echo "=== Xong (skip) ==="
  exit 0
fi

# Parse schedule entry (JSON in description)
GENRE=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('genre', ''))
except:
    pass
" 2>/dev/null)

TOPIC=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('topic', ''))
except:
    pass
" 2>/dev/null)

POST_TEXT=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('text', ''))
except:
    pass
" 2>/dev/null)

HASHTAGS=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('hashtags', ''))
except:
    pass
" 2>/dev/null)

IMG_PROMPT=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('image_prompt', ''))
except:
    pass
" 2>/dev/null)

LABEL=$(echo "$SCHEDULE_ENTRY" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('label', d.get('genre', '')))
except:
    pass
" 2>/dev/null)

[ -z "$GENRE" ] && GENRE="tho_tinh"
[ -z "$TOPIC" ] && TOPIC="ngay mua nho ai"
[ -z "$LABEL" ] && LABEL="$GENRE"

echo "  Hom nay: $LABEL - $TOPIC"
echo "  Gio: $EVENT_HOUR, Current: $CURRENT_HOUR"

# ---- 3. Use pre-composed text if available, otherwise generate ----
echo "3. Chuan bi noi dung..."

if [ -z "$POST_TEXT" ]; then
  echo "  (khong co text san — goi auto-post.sh)"
  exec bash "$DIR/auto-post.sh" "$GENRE" "$TOPIC"
fi

echo "  Noi dung da duoc soan san."
echo "$POST_TEXT" > /tmp/ap_post.txt

# ---- 4. Hashtag ----
echo ""
echo "4. Hashtag..."
if [ -z "$HASHTAGS" ]; then
  HASHTAGS="#${LABEL// /} #tho #vietvoivaicau"
fi
echo "  $HASHTAGS"

# ---- 5. Generate image ----
echo ""
echo "5. Tao anh..."
IMG_URL=""
IMG_PROMPT_FINAL="${IMG_PROMPT:-$STYLE_IMAGE}"

python3 > /tmp/ap_img_req.json << PYEOF
import json
prompt = """$IMG_PROMPT_FINAL"""
if not prompt:
    prompt = 'Watercolor storybook illustration, dreamy landscape, soft pastel colors'
with open('/tmp/ap_img_req.json', 'w') as f:
    json.dump({
        'prompt': prompt[:400],
        'aspect_ratio': '1:1',
        'model': 'gemini-2.5-flash-image'
    }, f)
PYEOF

if $COMPOSIO execute GEMINI_GENERATE_IMAGE -d @/tmp/ap_img_req.json > /tmp/ap_img_raw.json 2>/dev/null; then
  IMG_URL=$(python3 -c "
import json, sys
try:
    with open('/tmp/ap_img_raw.json') as f:
        d = json.load(f)
    url = d.get('data', {}).get('image', {}).get('s3url', '') or d.get('image', {}).get('s3url', '')
    print(url)
except: sys.exit(1)
" 2>/dev/null)
  if [ -n "$IMG_URL" ]; then
    echo "  Image URL: $IMG_URL"
  else
    warn "Khong lay duoc URL anh — dang text-only"
  fi
else
  warn "Image gen that bai — tien hanh dang text-only"
fi

# ---- 6. Build post body ----
echo ""
echo "6. Dang bai..."

cp /tmp/ap_post.txt /tmp/ap_body.txt
echo "" >> /tmp/ap_body.txt
echo "$HASHTAGS" >> /tmp/ap_body.txt

PAGE_ID="$PAGE_ID" IMG_URL="$IMG_URL" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_body.txt', encoding='utf-8') as f:
    body = f.read().strip()
payload = {"page_id": os.environ.get('PAGE_ID', ''), "message": body}
img_url = os.environ.get('IMG_URL', '')
if img_url:
    payload["url"] = img_url
with open('/tmp/ap_payload.json', 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=False)
PYEOF

POST_ID=""
if [ -n "$IMG_URL" ]; then
  echo "  Dang bai kem anh..."
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json 2>/dev/null
  RESULT_OK=$?
  if [ $RESULT_OK -ne 0 ]; then
    warn "Dang anh that bai — thu lai text-only"
    IMG_URL=""
  fi
fi

if [ -z "$IMG_URL" ]; then
  PAGE_ID="$PAGE_ID" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_body.txt', encoding='utf-8') as f:
    body = f.read().strip()
with open('/tmp/ap_payload.json', 'w', encoding='utf-8') as f:
    json.dump({"page_id": os.environ.get('PAGE_ID', ''), "message": body}, f, ensure_ascii=False)
PYEOF
  $COMPOSIO execute FACEBOOK_CREATE_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json 2>/dev/null
fi

POST_ID=$(python3 -c "
import json, sys
try:
    with open('/tmp/ap_result.json') as f:
        d = json.load(f)
    pid = d.get('data', {}).get('post_id', '') or d.get('data', {}).get('id', '') or d.get('post_id', '')
    print(pid)
except: sys.exit(1)
" 2>/dev/null)

if [ -z "$POST_ID" ]; then
  warn "Dang bai that bai hoac khong lay duoc POST_ID"
else
  echo "  Post ID: $POST_ID"
fi

# ---- 7. Comment ----
if [ -n "$POST_ID" ]; then
  echo ""
  echo "7. Viet comment..."

  COMMENT_RESULT=$($COMPOSIO execute GEMINI_GENERATE_CONTENT \
    -d '{"prompt":"Viet 1 cau binh luan bang tieng Viet that tu nhien, am ap cho bai tho Facebook vua dang. Giong nhu nguoi doc chia se cam nhan. Them 1-2 hashtag. Chi tra ve phan binh luan, khong giai thich.","model":"gemini-2.5-flash","temperature":0.7}' \
    2>/dev/null)

  COMMENT=$(echo "$COMMENT_RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print((d.get('data', {}).get('text', '') or d.get('text', '')).strip())
except: sys.exit(1)
" 2>/dev/null)

  if [ -n "$COMMENT" ]; then
    echo "  Comment: $COMMENT"
    echo "$COMMENT" > /tmp/ap_comment.txt
    POST_ID="$POST_ID" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_comment.txt', encoding='utf-8') as f:
    msg = f.read().strip()
with open('/tmp/ap_comment_payload.json', 'w', encoding='utf-8') as f:
    json.dump({"object_id": os.environ.get('POST_ID', ''), "message": msg}, f, ensure_ascii=False)
PYEOF
    $COMPOSIO execute FACEBOOK_CREATE_COMMENT -d @/tmp/ap_comment_payload.json 2>/dev/null || \
      warn "Comment that bai (khong anh huong)"
  fi
fi

# ---- 8. Log ----
echo ""
echo "8. Ghi log..."
LOG_DIR="$DIR/../logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
if [ ! -f "$LOG_FILE" ]; then
  echo "date,genre,topic,post_id,post_preview" > "$LOG_FILE" 2>/dev/null || true
fi
PREVIEW=$(cat /tmp/ap_post.txt 2>/dev/null | head -c 80 | tr '\n' ' ')
echo "$(date '+%Y-%m-%d %H:%M'),$LABEL,$TOPIC,$POST_ID,$PREVIEW..." >> "$LOG_FILE" 2>/dev/null || \
  warn "Ghi log that bai"

echo ""
echo "=== Xong ==="
