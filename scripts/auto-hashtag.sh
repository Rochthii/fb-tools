#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die()  { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

[ -z "$1" ] && die "Usage: $0 <noi_dung>"
[ -z "$COMPOSIO" ] && die "COMPOSIO chua duoc dat"

TEXT="$1"
echo "Sinh hashtag cho: ${TEXT:0:60}..."

RESULT=$($COMPOSIO execute GEMINI_GENERATE_CONTENT -d @- 2>/dev/null << ENDJSON
{
  "prompt": "Sinh 3-5 hashtag tieng Viet cho noi dung Facebook nay. Chi tra ve hashtag, khong giai thich. Noi dung: $TEXT",
  "model": "$MODEL_TEXT",
  "temperature": 0.5
}
ENDJSON
)

HASHTAGS=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    h = (d.get('data', {}).get('text', '') or d.get('text', '')).strip().replace('#', ' #').strip()
    print(h)
except:
    print('#tho #vietvoivaicau #camxuc')
" 2>/dev/null)

if [ -z "$HASHTAGS" ]; then
  warn "AI khong phan hoi — dung hashtag mac dinh"
  HASHTAGS="#tho #vietvoivaicau #camxuc"
fi

echo "$HASHTAGS"
