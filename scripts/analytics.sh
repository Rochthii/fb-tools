#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$DIR/../logs"
LOG_FILE="$LOG_DIR/posts.csv"

echo "=== Thong ke ==="
echo ""

if [ ! -f "$LOG_FILE" ]; then
  echo "Chua co du lieu."
  exit 0
fi

TOTAL=$(tail -n +2 "$LOG_FILE" 2>/dev/null | wc -l)
echo "Tong bai dang: $TOTAL"

if [ "$TOTAL" -gt 0 ]; then
  echo ""
  echo "Theo the loai:"
  tail -n +2 "$LOG_FILE" 2>/dev/null | cut -d',' -f2 | sort | uniq -c | sort -rn | awk '{print "  " $2 ": " $1 " bai"}'

  echo ""
  echo "7 bai gan day:"
  tail -7 "$LOG_FILE" 2>/dev/null | tail -n +2 | awk -F',' '{print "  " $1 " | " $2 " | " $5}'
fi

echo ""
echo "=== Het ==="
