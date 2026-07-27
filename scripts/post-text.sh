#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Noi dung: " msg
$COMPOSIO execute FACEBOOK_CREATE_POST -d "{\"page_id\":\"$PAGE_ID\",\"message\":\"$msg\"}"
