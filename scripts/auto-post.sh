#!/usr/bin/env bash
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

die() { echo "[LOI] $*" >&2; exit 1; }
warn() { echo "[CANH BAO] $*" >&2; }

# ---- Kiểm tra config ----
[ -z "$PAGE_ID" ]     && die "PAGE_ID chua duoc dat trong config.sh"
[ -z "$COMPOSIO" ]    && die "COMPOSIO chua duoc dat trong config.sh"
[ ! -x "$COMPOSIO" ]  && warn "COMPOSIO ($COMPOSIO) khong ton tai hoac khong the chay — thu dung 'composio'"
type python3 &>/dev/null || die "python3 chua duoc cai dat"

echo "=== $PROJECT_NAME ==="

# ---- 1. Chọn thể loại + chủ đề (có fallback) ----
echo "1. Chon the loai..."

if [ -n "$1" ] && [ -n "$2" ]; then
  GENRE="$1"
  TOPIC="$2"
  LABEL=$(python3 -c "
import json, sys
try:
    with open('$DIR/themes.json', encoding='utf-8') as f:
        themes = json.load(f)
    print(themes.get('$1', {}).get('label', '$1'))
except:
    print('$1')
" 2>/dev/null)
  [ -z "$LABEL" ] && LABEL="$GENRE"
  echo "  (from schedule) $LABEL : $TOPIC"
else
  FALLBACK_GENRES=("tho_tinh" "tho_cuoc_song" "tho_vui" "danh_ngon")
  FALLBACK_TOPICS=("ngay mua nho ai" "ca phe sang" "tha thinh" "cuoc song")

  select_genre_fallback() {
    local i=$((RANDOM % ${#FALLBACK_GENRES[@]}))
    GENRE="${FALLBACK_GENRES[$i]}"
    TOPIC="${FALLBACK_TOPICS[$i]}"
    LABEL="$GENRE"
    echo "  (fallback) $LABEL : $TOPIC"
  }

  SELECTION=""
  if [ -f "$DIR/themes.json" ] && [ -s "$DIR/themes.json" ]; then
    SELECTION=$(python3 -c "
import json, random, sys
try:
    with open('$DIR/themes.json', encoding='utf-8') as f:
        themes = json.load(f)
except Exception as e:
    print('ERR', e, file=sys.stderr)
    sys.exit(1)

genres = '${GENRES[*]}'
weights = '${GENRE_WEIGHTS[*]}'
genre_list = genres.split()
weight_list = [int(w) for w in weights.split()]

genre = random.choices(genre_list, weights=weight_list, k=1)[0]
if genre not in themes:
    genre = list(themes.keys())[0]
topic = random.choice(themes[genre]['topics'])
label = themes[genre].get('label', genre)
print(f'{genre}|{topic}|{label}')
" 2>/dev/null)
  fi

  if [ -n "$SELECTION" ] && echo "$SELECTION" | grep -q '|'; then
    GENRE=$(echo "$SELECTION" | cut -d'|' -f1)
    TOPIC=$(echo "$SELECTION" | cut -d'|' -f2)
    LABEL=$(echo "$SELECTION" | cut -d'|' -f3)
    echo "  => $LABEL : $TOPIC"
  else
    warn "themes.json loi hoac trong — dung fallback"
    select_genre_fallback
  fi
fi

# ---- 2. Build prompt + gọi AI (có fallback nếu lỗi) ----
echo "2. Viet noi dung..."
FALLBACK_POST="Gio chieu tan, ngoai hien mua bay
Ta ngoi nghe do song day trong long
Mot chut buon lang lang…
De thay long minh nhe hon"

python3 > /tmp/ap_prompt.json << PYEOF
import json
genre = "$GENRE"
topic = "$TOPIC"
label = "$LABEL"

prompts = {
    "tho_tinh": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tình tiếng Việt 4-8 câu.
Chủ đề: {topic}
Phong cách: tự nhiên như lời tâm sự, nhẹ nhàng, giàu hình ảnh (mưa, cà phê, góc phố, nỗi nhớ...)
Gieo vần mềm, không gượng ép.
KHÔNG sáo rỗng, KHÔNG màu mè.
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "tho_cuoc_song": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tiếng Việt 4-6 câu về cuộc sống.
Chủ đề: {topic}
Phong cách: tự nhiên, chill, gần gũi, như đang kể chuyện
Dùng hình ảnh đời thường: cà phê, đường phố, nắng mưa...
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "tho_gia_dinh": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tiếng Việt 6-10 câu về gia đình.
Chủ đề: {topic}
Phong cách: ấm áp, cảm động, chân thành
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "tho_tam_trang": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tiếng Việt 2-4 câu về tâm trạng.
Chủ đề: {topic}
Phong cách: sâu lắng, nhẹ nhàng, hơi buồn, chạm vào cảm xúc
Ngắn gọn nhưng thấm.
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "tho_vui": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tiếng Việt 2-4 câu hài hước, vui vẻ.
Chủ đề: {topic}
Phong cách: trẻ trung, duyên dáng, có thể thả thính hoặc chế nhẹ
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "tho_truyen_cam_hung": f"""Bạn là nhà thơ Việt Nam, viết cho Facebook Page "viết vội vài câu".

Viết 1 bài thơ tiếng Việt 4-6 câu truyền cảm hứng.
Chủ đề: {topic}
Phong cách: tích cực, động lực, ấm áp, chữa lành
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết thơ, không giải thích.""",

    "danh_ngon": f"""Bạn viết cho Facebook Page "viết vội vài câu".

Viết 1 câu danh ngôn hay bằng tiếng Việt.
Chủ đề: {topic}
Phong cách: sâu sắc, ngắn gọn, đáng suy ngẫm
Nếu cần, thêm tên tác giả (có thể là danh ngôn Việt Nam).
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh (typography, minimalist)
Chỉ trả về nội dung, không giải thích.""",

    "truyen_ngan": f"""Bạn là người kể chuyện cho Facebook Page "viết vội vài câu".

Viết 1 câu chuyện siêu ngắn tiếng Việt 3-5 dòng.
Chủ đề: {topic}
Phong cách: cảm động, nhẹ nhàng, có chiều sâu
Kể một khoảnh khắc nhỏ trong cuộc sống.
Cuối cùng thêm dòng: ANH: + prompt tiếng Anh tạo ảnh minh họa
Chỉ viết truyện, không giải thích."""
}

prompt_text = prompts.get(genre, prompts["tho_tinh"])
print(json.dumps({
    "prompt": prompt_text,
    "model": "$MODEL_TEXT",
    "temperature": $TEMPERATURE
}))
PYEOF

RAW_TEXT=""
if $COMPOSIO execute GEMINI_GENERATE_CONTENT -d @/tmp/ap_prompt.json > /tmp/ap_raw.json 2>/dev/null; then
  RAW_TEXT=$(python3 -c "
import json, sys
try:
    with open('/tmp/ap_raw.json') as f:
        d = json.load(f)
    print(d.get('data', {}).get('text', '') or d.get('text', ''))
except: sys.exit(1)
" 2>/dev/null)
fi

if [ -z "$RAW_TEXT" ]; then
  warn "AI text gen that bai — dung bai viet fallback"
  RAW_TEXT="$FALLBACK_POST"
fi

# ---- 3. Parse nội dung + image prompt ----
echo "$RAW_TEXT" > /tmp/ap_raw_text.txt
STYLE_IMAGE="$STYLE_IMAGE" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_raw_text.txt', encoding='utf-8') as f:
    text = f.read()
parts = text.split('ANH:')
post = parts[0].strip() if parts else text
default_img = os.environ.get('STYLE_IMAGE', 'watercolor storybook illustration, dreamy landscape')
img = parts[1].strip() if len(parts) > 1 else default_img
with open('/tmp/ap_post.txt', 'w', encoding='utf-8') as f:
    f.write(post)
with open('/tmp/ap_img.txt', 'w', encoding='utf-8') as f:
    f.write(img)
print("Noi dung:")
print(post)
PYEOF

# ---- 4. Sinh hashtag (có fallback) ----
echo ""
echo "3. Sinh hashtag..."

HASHTAGS=""
HASH_RESULT=$($COMPOSIO execute GEMINI_GENERATE_CONTENT -d @- 2>/dev/null << ENDJSON
{
  "prompt": "Tu noi dung sau, hay sinh 3-5 hashtag tieng Viet phu hop de dang len Facebook. Chi tra ve danh sach hashtag, khong giai thich. Noi dung: $(cat /tmp/ap_post.txt 2>/dev/null)",
  "model": "$MODEL_TEXT",
  "temperature": 0.5
}
ENDJSON
)

if [ -n "$HASH_RESULT" ]; then
  HASHTAGS=$(echo "$HASH_RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    h = (d.get('data', {}).get('text', '') or d.get('text', '')).strip().replace('#', ' #').strip()
    print(h)
except: sys.exit(1)
" 2>/dev/null)
fi

if [ -z "$HASHTAGS" ]; then
  warn "Hashtag gen that bai — dung hashtag mac dinh"
  HASHTAGS="#${LABEL// /} #tho #vietvoivaicau"
fi
echo "  Hashtags: $HASHTAGS"

# ---- 5. Tạo ảnh (có fallback — bỏ qua nếu lỗi) ----
echo ""
echo "4. Tao anh..."
IMG_URL=""

python3 > /tmp/ap_img_req.json << 'PYEOF'
import json
with open('/tmp/ap_img.txt', encoding='utf-8') as f:
    prompt = f.read().strip()
if not prompt:
    prompt = 'Watercolor storybook illustration, dreamy landscape, soft pastel colors'
with open('/tmp/ap_img_req.json', 'w') as f:
    json.dump({
        'prompt': prompt[:400],
        'aspect_ratio': '1:1',
        'model': 'gemini-2.5-flash-image'
    }, f)
PYEOF

if $COMPOSIO execute GEMINI_GENERATE_IMAGE -d @/tmp/ap_img_req.json > /tmp/ap_img_raw.json 2>/dev/null; then
  IMG_URL=$(python3 -c "
import json, sys
try:
    with open('/tmp/ap_img_raw.json') as f:
        d = json.load(f)
    url = d.get('data', {}).get('image', {}).get('s3url', '') or d.get('image', {}).get('s3url', '')
    print(url)
except: sys.exit(1)
" 2>/dev/null)
  if [ -n "$IMG_URL" ]; then
    echo "  Image URL: $IMG_URL"
  else
    warn "Khong lay duoc URL anh — dang text-only"
    IMG_URL=""
  fi
else
  warn "Image gen that bai — tien hanh dang text-only"
fi

# ---- 6. Đăng bài (có retry: fallback text-only nếu ảnh lỗi) ----
echo ""
echo "5. Dang bai..."

POST_ID=""
cp /tmp/ap_post.txt /tmp/ap_body.txt
echo "" >> /tmp/ap_body.txt
echo "$HASHTAGS" >> /tmp/ap_body.txt

PAGE_ID="$PAGE_ID" IMG_URL="$IMG_URL" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_body.txt', encoding='utf-8') as f:
    body = f.read().strip()
payload = {"page_id": os.environ.get('PAGE_ID', ''), "message": body}
img_url = os.environ.get('IMG_URL', '')
if img_url:
    payload["url"] = img_url
with open('/tmp/ap_payload.json', 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=False)
PYEOF

if [ -n "$IMG_URL" ]; then
  echo "  Dang bai kem anh..."
  $COMPOSIO execute FACEBOOK_CREATE_PHOTO_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json 2>/dev/null
  RESULT_OK=$?
  if [ $RESULT_OK -ne 0 ]; then
    warn "Dang anh that bai — thu lai text-only"
    IMG_URL=""
  fi
fi

if [ -z "$IMG_URL" ]; then
  PAGE_ID="$PAGE_ID" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_body.txt', encoding='utf-8') as f:
    body = f.read().strip()
with open('/tmp/ap_payload.json', 'w', encoding='utf-8') as f:
    json.dump({"page_id": os.environ.get('PAGE_ID', ''), "message": body}, f, ensure_ascii=False)
PYEOF
  $COMPOSIO execute FACEBOOK_CREATE_POST -d @/tmp/ap_payload.json > /tmp/ap_result.json 2>/dev/null
fi

POST_ID=$(python3 -c "
import json, sys
try:
    with open('/tmp/ap_result.json') as f:
        d = json.load(f)
    pid = d.get('data', {}).get('post_id', '') or d.get('data', {}).get('id', '') or d.get('post_id', '')
    print(pid)
except: sys.exit(1)
" 2>/dev/null)

if [ -z "$POST_ID" ]; then
  warn "Dang bai that bai hoac khong lay duoc POST_ID"
else
  echo "  Post ID: $POST_ID"
fi

# ---- 7. Comment tự động (có fallback — skip nếu lỗi) ----
if [ -n "$POST_ID" ]; then
  echo ""
  echo "6. Viet comment..."

  COMMENT_RESULT=$($COMPOSIO execute GEMINI_GENERATE_CONTENT \
    -d '{"prompt":"Viet 1 cau binh luan bang tieng Viet that tu nhien, am ap cho bai tho Facebook vua dang. Giong nhu nguoi doc chia se cam nhan. Them 1-2 hashtag. Chi tra ve phan binh luan, khong giai thich.","model":"gemini-2.5-flash","temperature":0.7}' \
    2>/dev/null)

  COMMENT=$(echo "$COMMENT_RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print((d.get('data', {}).get('text', '') or d.get('text', '')).strip())
except: sys.exit(1)
" 2>/dev/null)

  if [ -n "$COMMENT" ]; then
    echo "  Comment: $COMMENT"
    echo "$COMMENT" > /tmp/ap_comment.txt
    POST_ID="$POST_ID" python3 << 'PYEOF'
import json, os
with open('/tmp/ap_comment.txt', encoding='utf-8') as f:
    msg = f.read().strip()
with open('/tmp/ap_comment_payload.json', 'w', encoding='utf-8') as f:
    json.dump({"object_id": os.environ.get('POST_ID', ''), "message": msg}, f, ensure_ascii=False)
PYEOF
    $COMPOSIO execute FACEBOOK_CREATE_COMMENT -d @/tmp/ap_comment_payload.json 2>/dev/null || \
      warn "Comment that bai (khong anh huong)"
  fi
fi

# ---- 8. Log analytics ----
echo ""
echo "7. Ghi log..."
LOG_DIR="$DIR/../logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="$LOG_DIR/posts.csv"
if [ ! -f "$LOG_FILE" ]; then
  echo "date,genre,topic,post_id,post_preview" > "$LOG_FILE" 2>/dev/null || true
fi
PREVIEW=$(cat /tmp/ap_post.txt 2>/dev/null | head -c 80 | tr '\n' ' ')
echo "$(date '+%Y-%m-%d %H:%M'),$LABEL,$TOPIC,$POST_ID,$PREVIEW..." >> "$LOG_FILE" 2>/dev/null || \
  warn "Ghi log that bai"

echo ""
echo "=== Xong ==="
