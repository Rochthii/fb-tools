#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Noi dung: " msg
read -p "Dang sau bao nhieu phut: " minutes
ts=$(( $(date +%s) + minutes * 60 ))
echo "Lich: $(date -d @$ts '+%Y-%m-%d %H:%M')"
$COMPOSIO execute FACEBOOK_CREATE_POST -d "{\"page_id\":\"$PAGE_ID\",\"message\":\"$msg\",\"published\":false,\"scheduled_publish_time\":$ts}"
