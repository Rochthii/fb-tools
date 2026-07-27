#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die() { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

[ -z "$PAGE_ID" ]     && die "PAGE_ID chua duoc dat trong config.sh"
[ -z "$COMPOSIO" ]    && die "COMPOSIO chua duoc dat trong config.sh"
type python3 &>/dev/null || die "python3 chua duoc cai dat"

echo "=== $PROJECT_NAME — Bao cao thang ==="
echo ""

LOG_FILE="$DIR/../logs/posts.csv"
if [ ! -f "$LOG_FILE" ]; then
  die "Chua co bai dang nao (khong tim thay $LOG_FILE)"
fi

# ---- 1. Doc danh sach post tu log ----
echo "1. Doc log bai dang..."
POSTS=$(tail -n +2 "$LOG_FILE" 2>/dev/null | head -30)
TOTAL=$(echo "$POSTS" | grep -c . 2>/dev/null || echo "0")
echo "  Tong so bai: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  die "Khong co bai dang nao trong log"
fi

# ---- 2. Lay insights cho tung bai ----
echo "2. Thu thap thong ke tung bai..."

REPORT_LINES=""
COUNT=0
while IFS=',' read -r DATE LABEL TOPIC POST_ID PREVIEW; do
  COUNT=$((COUNT + 1))
  echo "  [$COUNT/$TOTAL] $LABEL..."

  if [ -z "$POST_ID" ] || [ "$POST_ID" = "N/A" ]; then
    REPORT_LINES="$REPORT_LINES
- $LABEL: Khong co Post ID (dang that bai?)"
    continue
  fi

  INSIGHT_RAW=$($COMPOSIO execute FACEBOOK_GET_POST_INSIGHTS \
    --post_id "$POST_ID" \
    2>/dev/null)

  METRICS=$(echo "$INSIGHT_RAW" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        data = json.loads(data)
    items = data if isinstance(data, list) else data.get('data', [])
    likes = 0
    comments = 0
    shares = 0
    impressions = 0
    reach = 0
    for item in items:
        name = item.get('name', '')
        vals = item.get('values', [])
        if vals:
            val = vals[-1].get('value', 0)
            if name == 'post_impressions_unique':
                reach = val
            elif name == 'post_impressions':
                impressions = val
            elif name == 'post_engaged_users':
                pass
        # Try direct fields
        if name == 'post_reactions_like_total':
            likes = val if vals else 0
    # If no structured data, try flat response
    if not items:
        likes = d.get('data', {}).get('likes', {}).get('summary', {}).get('total_count', 0)
        comments = d.get('data', {}).get('comments', {}).get('summary', {}).get('total_count', 0)
    print(f'like:{likes}|cmt:{comments}|reach:{reach}')
except:
    print('like:0|cmt:0|reach:0')
" 2>/dev/null)

  LIKES=$(echo "$METRICS" | cut -d'|' -f1 | cut -d':' -f2)
  CMTS=$(echo "$METRICS" | cut -d'|' -f2 | cut -d':' -f2)
  REACH=$(echo "$METRICS" | cut -d'|' -f3 | cut -d':' -f2)

  [ -z "$LIKES" ] && LIKES="?"
  [ -z "$CMTS" ] && CMTS="?"
  [ -z "$REACH" ] && REACH="?"

  REPORT_LINES="$REPORT_LINES
  - $LABEL: $LIKES likes, $CMTS comments, $REACH reach"
done <<< "$POSTS"

# ---- 3. Tinh tong quan ----
echo "3. Tong quan..."

SUMMARY=$(echo "$REPORT_LINES" | python3 -c "
import sys
lines = sys.stdin.read().strip()
likes_total = 0
cmts_total = 0
reach_total = 0
count = 0
for line in lines.split('\n'):
    if 'likes' in line:
        count += 1
        parts = line.split(':')
        for i, p in enumerate(parts):
            p = p.strip()
            if 'likes' in p:
                try:
                    likes_total += int(parts[i-1].strip().split()[-1])
                except: pass
            if 'comments' in p:
                try:
                    cmts_total += int(parts[i-1].strip().split()[-1])
                except: pass
            if 'reach' in p:
                try:
                    reach_total += int(parts[i-1].strip().split()[-1])
                except: pass
print(f'Tong: {count} bai, {likes_total} likes, {cmts_total} comments, {reach_total} reach')
" 2>/dev/null)

echo "  $SUMMARY"
echo ""

# ---- 4. Gui email bao cao ----
echo "4. Gui email bao cao..."

REPORT_BODY="===== $PROJECT_NAME — Bao cao thang =====

$SUMMARY

Chi tiet tung bai:
$REPORT_LINES

-----
Tu dong tao boi $PROJECT_NAME
https://github.com/Rochthii/fb-tools"

# Gửi email qua Composio Gmail
EMAIL_RESULT=$($COMPOSIO execute GMAIL_SEND_EMAIL \
  --to "$REPORT_EMAIL" \
  --subject "[$PROJECT_NAME] Bao cao thang" \
  --body "$REPORT_BODY" \
  2>/dev/null)

SENT=$(echo "$EMAIL_RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        data = json.loads(data)
    print('OK' if data.get('id','') or data.get('successful') else 'FAIL')
except: print('FAIL')
" 2>/dev/null)

if [ "$SENT" = "OK" ]; then
  echo "  Email da gui toi $REPORT_EMAIL"
else
  warn "  Gui email that bai. Noi dung bao cao:"
  echo ""
  echo "$REPORT_BODY"
fi

echo ""
echo "=== Xong ==="
