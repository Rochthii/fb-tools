#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Chu de: " topic

echo "Viet tho..."
poem_raw=$($COMPOSIO execute GEMINI_GENERATE_CONTENT -d "{\"prompt\":\"Viet mot bai tho tieng Viet ngan khoang 6-10 cau ve chu de: $topic. Chi tra ve phan tho, khong giai thich.\",\"model\":\"gemini-2.5-flash\"}" 2>/dev/null)
poem=$(echo "$poem_raw" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('text',''))" 2>/dev/null)

echo "====="
echo "$poem"
echo "====="

echo "Tao anh..."
img_raw=$($COMPOSIO execute GEMINI_GENERATE_IMAGE -d "{\"prompt\":\"Vietnamese poem illustration: $topic, romantic watercolor style, soft lighting, no text\",\"aspect_ratio\":\"1:1\",\"model\":\"gemini-3-pro-image-preview\"}" 2>/dev/null)
img_url=$(echo "$img_raw" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('image',{}).get('s3url',''))" 2>/dev/null)

if [ -z "$img_url" ]; then
  echo "Khong tao duoc anh, dang text..."
  $COMPOSIO execute FACEBOOK_CREATE_POST -d "{\"page_id\":\"$PAGE_ID\",\"message\":\"$poem\"}"
else
  echo "Dang bai..."
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d "{\"page_id\":\"$PAGE_ID\",\"url\":\"$img_url\",\"message\":\"$poem\"}"
fi
