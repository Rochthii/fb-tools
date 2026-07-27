#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Ten album: " album_name
read -p "Mo ta: " album_desc
read -p "Danh sach URL anh (cach nhau bang space): " -a urls

echo "Tao album..."
album=$($COMPOSIO execute FACEBOOK_CREATE_PHOTO_ALBUM -d "{\"page_id\":\"$PAGE_ID\",\"name\":\"$album_name\",\"message\":\"$album_desc\"}" 2>/dev/null)
album_id=$(echo "$album" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "Album ID: $album_id"

for url in "${urls[@]}"; do
  echo "Dang: $url"
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d "{\"page_id\":\"$PAGE_ID\",\"url\":\"$url\",\"message\":\"$album_desc\"}"
done

echo "Xong! Album da tao."
