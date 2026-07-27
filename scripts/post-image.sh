#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Prompt tao anh: " prompt
read -p "Noi dung bai dang: " msg

echo "Dang tao anh..."
img=$($COMPOSIO execute GEMINI_GENERATE_IMAGE -d "{\"prompt\":\"$prompt\",\"aspect_ratio\":\"1:1\",\"model\":\"gemini-3-pro-image-preview\"}" 2>/dev/null | grep -o '"s3url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$img" ]; then
  echo "Loi: khong lay duoc anh"
  exit 1
fi

echo "Anh: $img"
echo "Dang dang bai..."
$COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d "{\"page_id\":\"$PAGE_ID\",\"url\":\"$img\",\"message\":\"$msg\"}"
