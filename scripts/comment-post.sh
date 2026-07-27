#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

read -p "Post ID (vd: 1133589166515175_122097800427292018): " object_id
read -p "Noi dung comment (co the kem link): " msg
read -p "Dinh kem URL anh (enter de bo qua): " img_url

if [ -n "$img_url" ]; then
  $COMPOSIO execute FACEBOOK_CREATE_COMMENT -d "{\"object_id\":\"$object_id\",\"message\":\"$msg\",\"attachment_url\":\"$img_url\"}"
else
  $COMPOSIO execute FACEBOOK_CREATE_COMMENT -d "{\"object_id\":\"$object_id\",\"message\":\"$msg\"}"
fi
