#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

echo "=== Auto Post ==="

echo "1. Viet noi dung..."
$COMPOSIO execute GEMINI_GENERATE_CONTENT \
  -d '{"prompt":"Ban la nha tho cho Facebook Page Bai Hoc Hom Nay. Hay viet 1 bai tho tieng Viet ngan 6-10 cau ve 1 chu de ngau nhien (tinh yeu, que huong, cuoc song, gia dinh, ban be, hy vong...). Tho tu do hoac luc bat, van tu nhien, am ap, dam chat tru cam. Chi viet tho, tuyet doi khong viet loi gioi thieu hay mo dau nao. Phan cuoi them 1 dong ANH: + prompt tao anh bang tieng Anh de minh hoa bai tho.","model":"gemini-2.5-flash","temperature":0.9}' \
  2>/dev/null > /tmp/ap_raw.json

python3 << 'PYEOF'
import json
with open('/tmp/ap_raw.json') as f:
    d = json.load(f)
text = d.get('data', {}).get('text', '')
parts = text.split('ANH:')
post = parts[0].strip() if parts else text
img = parts[1].strip() if len(parts) > 1 else 'Vietnamese inspirational scene, watercolor'
with open('/tmp/ap_post.txt', 'w', encoding='utf-8') as f:
    f.write(post)
with open('/tmp/ap_img.txt', 'w', encoding='utf-8') as f:
    f.write(img)
print(post)
PYEOF

echo "2. Tao anh..."
IMG_PROMPT=$(cat /tmp/ap_img.txt)
$COMPOSIO execute GEMINI_GENERATE_IMAGE \
  -d "{\"prompt\":\"$IMG_PROMPT\",\"aspect_ratio\":\"1:1\",\"model\":\"gemini-3-pro-image-preview\"}" \
  2>/dev/null > /tmp/ap_img_raw.json

IMG_URL=$(python3 -c "
import json
with open('/tmp/ap_img_raw.json') as f:
    d = json.load(f)
print(d.get('data', {}).get('image', {}).get('s3url', ''))
")

echo "3. Dang bai..."
PAGE_ID="$PAGE_ID" IMG_URL="$IMG_URL" python3 << 'PYEOF'
import json, os
post = open('/tmp/ap_post.txt', encoding='utf-8').read()
img_url = os.environ.get('IMG_URL', '')
page_id = os.environ.get('PAGE_ID', '')
if img_url:
    payload = {'page_id': page_id, 'url': img_url, 'message': post}
else:
    payload = {'page_id': page_id, 'message': post}
with open('/tmp/ap_payload.json', 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=False)
PYEOF

if [ -n "$IMG_URL" ]; then
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json
else
  $COMPOSIO execute FACEBOOK_CREATE_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json
fi

POST_ID=$(python3 -c "
import json
with open('/tmp/ap_result.json') as f:
    d = json.load(f)
print(d.get('data', {}).get('post_id', '') or d.get('data', {}).get('id', ''))
")
echo "Post ID: $POST_ID"

if [ -n "$POST_ID" ]; then
  echo "4. Viet comment..."
  $COMPOSIO execute GEMINI_GENERATE_CONTENT \
    -d '{"prompt":"Viet 1 cau binh luan bang tieng Viet that tu nhien, am ap cho bai tho Facebook vua dang. Giong nhu nguoi doc chia se cam nhan. Them 1-2 hashtag. Chi tra ve phan binh luan, khong giai thich.","model":"gemini-2.5-flash","temperature":0.7}' \
    2>/dev/null > /tmp/ap_comment_raw.json

  COMMENT=$(python3 -c "
import json
with open('/tmp/ap_comment_raw.json') as f:
    d = json.load(f)
print(d.get('data', {}).get('text', '').strip())
")

  if [ -n "$COMMENT" ]; then
    echo "Comment: $COMMENT"
    echo "$COMMENT" > /tmp/ap_comment.txt
    echo "5. Dang comment..."
    POST_ID="$POST_ID" python3 << 'PYEOF'
import json, os
comment = open('/tmp/ap_comment.txt', encoding='utf-8').read().strip()
with open('/tmp/ap_comment_payload.json', 'w', encoding='utf-8') as f:
    json.dump({'object_id': os.environ['POST_ID'], 'message': comment}, f, ensure_ascii=False)
PYEOF
    $COMPOSIO execute FACEBOOK_CREATE_COMMENT -d @/tmp/ap_comment_payload.json
  fi
fi

echo "=== Xong ==="
