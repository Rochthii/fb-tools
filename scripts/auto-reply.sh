#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die()  { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

[ -z "$PAGE_ID" ]  && die "PAGE_ID chua duoc dat"
[ -z "$COMPOSIO" ] && die "COMPOSIO chua duoc dat"
type python3 &>/dev/null || die "python3 chua duoc cai dat"

echo "=== Duyet comment moi ==="

LAST_CHECK_FILE="/tmp/ap_reply_last.txt"
[ ! -f "$LAST_CHECK_FILE" ] && echo "0" > "$LAST_CHECK_FILE"
LAST_ID=$(cat "$LAST_CHECK_FILE")

# Lấy bài viết gần nhất
RECENT_POSTS=$($COMPOSIO execute FACEBOOK_LIST_PAGE_POSTS \
  -d "{\"page_id\":\"$PAGE_ID\",\"limit\":3}" 2>/dev/null)

LATEST_POST_ID=$(echo "$RECENT_POSTS" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    posts = d.get('data', {}).get('posts', []) or d.get('data', {}).get('data', [])
    if posts:
        print(posts[0].get('id', ''))
except: pass
" 2>/dev/null)

if [ -z "$LATEST_POST_ID" ]; then
  echo "Khong lay duoc post nao."
  exit 0
fi

if [ "$LATEST_POST_ID" = "$LAST_ID" ]; then
  echo "Khong co post moi."
  exit 0
fi

echo "Post moi: $LATEST_POST_ID"

# Lấy comment
COMMENTS=$($COMPOSIO execute FACEBOOK_LIST_COMMENTS \
  -d "{\"post_id\":\"$LATEST_POST_ID\",\"limit\":5}" 2>/dev/null)

echo "$COMMENTS" | python3 -c "
import json, os, sys

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

comments = d.get('data', {}).get('comments', []) or d.get('data', {}).get('data', [])
page_id = \"$PAGE_ID\"

for c in comments:
    cid = c.get('id', '')
    msg = c.get('message', '')
    author = c.get('from', {}).get('id', '')
    name  = c.get('from', {}).get('name', '')

    if not msg or author == page_id:
        continue

    print(f'  Comment tu {name}: {msg[:60]}')

    # Gọi Gemini sinh reply
    import subprocess, tempfile
    payload = json.dumps({
        'prompt': f\"Nguoi dung Facebook vua comment: '{msg}' tren bai viet cua Page tho. Hay tra loi that tu nhien, am ap, nhe nhang, tieng Viet. Khong duoc qua dai. Chi tra ve phan tra loi.\",
        'model': 'gemini-2.5-flash',
        'temperature': 0.7
    }, ensure_ascii=False)

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
        f.write(payload)
        req_file = f.name

    result = subprocess.run(
        ['$COMPOSIO', 'execute', 'GEMINI_GENERATE_CONTENT', '-d', f'@{req_file}'],
        capture_output=True, text=True, timeout=30
    )
    os.unlink(req_file)

    if result.returncode != 0:
        print(f'    (loi goi AI)')
        continue

    try:
        reply_data = json.loads(result.stdout)
        reply_text = reply_data.get('data', {}).get('text', '') or reply_data.get('text', '')
        reply_text = reply_text.strip()
    except:
        reply_text = ''

    if not reply_text:
        print(f'    (phan hoi AI rong)')
        continue

    print(f'  Reply: {reply_text}')

    # Đăng reply
    comment_id = c.get('id', '')
    reply_payload = json.dumps({'comment_id': comment_id, 'message': reply_text}, ensure_ascii=False)
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
        f.write(reply_payload)
        reply_file = f.name

    subprocess.run(
        ['$COMPOSIO', 'execute', 'FACEBOOK_REPLY_TO_COMMENT', '-d', f'@{reply_file}'],
        capture_output=True, timeout=30
    )
    os.unlink(reply_file)
" 2>&1

echo "$LATEST_POST_ID" > "$LAST_CHECK_FILE"
echo "=== Xong ==="
