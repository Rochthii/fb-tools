#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die() { echo "[LOI] $*" >&2; exit 1; }

echo "=== Connect Google Calendar ==="
echo "Project: $PROJECT_NAME"
echo "Looking for calendar: $CALENDAR_NAME"
echo ""

# List all calendars
CAL_RAW=$($COMPOSIO execute GOOGLECALENDAR_LIST_CALENDARS 2>/dev/null)

# Try to find our calendar by name
CAL_ID=$(echo "$CAL_RAW" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    data = d.get('data', d)
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except:
            data = {'items': []}
    items = data.get('items', []) or data.get('calendars', []) or []
    if isinstance(items, dict):
        items = [items]
    name = '$CALENDAR_NAME'
    for cal in items:
        if cal.get('summary', '') == name or cal.get('summaryOverride', '') == name:
            print(cal.get('id', 'primary'))
            break
except:
    pass
" 2>/dev/null)

if [ -n "$CAL_ID" ]; then
  echo "Calendar '$CALENDAR_NAME' found!"
  echo "Calendar ID: $CAL_ID"
  echo ""
  echo "Add this line to scripts/config.sh:"
  echo "  CALENDAR_ID=\"$CAL_ID\""
  echo ""
  # Save to a temp file that other scripts can read
  echo "$CAL_ID" > /tmp/ag_calendar_id.txt
else
  echo "Calendar '$CALENDAR_NAME' not found."
  echo ""
  echo "Please create a calendar named '$CALENDAR_NAME' in Google Calendar,"
  echo "then run this script again."
  echo ""
  echo "Or run this command to list all your calendars and find the right ID:"
  echo "  composio execute GOOGLECALENDAR_LIST_CALENDARS"
  echo ""
  echo "Using 'primary' calendar as fallback."
  echo "primary" > /tmp/ag_calendar_id.txt
fi

echo ""
echo "=== Verification ==="
echo "Facebook: $($COMPOSIO execute FACEBOOK_GET_CURRENT_USER 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('name','') or d.get('name','OK'))" 2>/dev/null || echo "Not connected")"
echo "Gmail: $($COMPOSIO execute GMAIL_LIST_INBOX 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if d.get('successful') or d.get('data') else 'Not connected')" 2>/dev/null || echo "Not connected")"
echo "Google Calendar: $($COMPOSIO execute GOOGLECALENDAR_LIST_CALENDARS 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if d.get('successful') or d.get('data') else 'Not connected')" 2>/dev/null || echo "Not connected")"
echo "Gemini: $($COMPOSIO execute GEMINI_GENERATE_CONTENT -d '{\"prompt\":\"hi\",\"model\":\"gemini-2.5-flash\",\"temperature\":0}' 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if (d.get('data',{}).get('text','') or d.get('text','')) else 'Not connected')" 2>/dev/null || echo "Not connected")"
