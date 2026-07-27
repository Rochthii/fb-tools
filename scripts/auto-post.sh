#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

echo "=== Auto Post ==="

echo "1. Viet noi dung..."
$COMPOSIO execute GEMINI_GENERATE_CONTENT \
  -d '{"prompt":"Ban la nha tho cho Facebook Page Bai Hoc Hom Nay. Hay viet 1 bai tho tieng Viet ngan 6-10 cau ve 1 chu de ngau nhien (tinh yeu, que huong, cuoc song, gia dinh, ban be, hy vong...). Tho tu do hoac luc bat, van tu nhien, am ap, dam chat tru cam. Giong tho giong nhu bay gio dang tam su. Tranh gio tai, dung tu sach. Phan cuoi them 1 dong ANH: + prompt tao anh bang tieng Anh de minh hoa bai tho.","model":"gemini-2.5-flash","temperature":0.9}' \
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
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d @/tmp/ap_payload.json
else
  $COMPOSIO execute FACEBOOK_CREATE_POST -d @/tmp/ap_payload.json
fi

echo "=== Xong ==="
