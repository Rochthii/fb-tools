#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Post ID: " post_id
read -p "Noi dung moi: " msg
$COMPOSIO execute FACEBOOK_UPDATE_POST -d "{\"post_id\":\"$post_id\",\"message\":\"$msg\"}"
