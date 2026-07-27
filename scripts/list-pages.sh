#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

$COMPOSIO execute FACEBOOK_LIST_MANAGED_PAGES -d "{}"
