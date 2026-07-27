PAGE_ID="1133589166515175"

# Auto-detect composio: PATH -> ~/.composio/ -> /root/.composio/
COMPOSIO=""
for c in "$(command -v composio 2>/dev/null)" "$HOME/.composio/composio" "/root/.composio/composio" "/usr/local/bin/composio"; do
  [ -n "$c" ] && [ -x "$c" ] && { COMPOSIO="$c"; break; }
done
[ -z "$COMPOSIO" ] && COMPOSIO="composio"

# COMPOSIO_API_KEY must be set in environment (GitHub Secret or .env)
# Facebook + Gemini must be connected via: composio link facebook

MODEL_TEXT="gemini-2.5-flash"
MODEL_IMAGE="gemini-2.5-flash-image"
TEMPERATURE=0.9

GENRES=("tho_tinh" "tho_cuoc_song" "tho_gia_dinh" "tho_tam_trang" "tho_vui" "tho_truyen_cam_hung" "danh_ngon" "truyen_ngan")

GENRE_WEIGHTS=(25 20 10 15 10 10 5 5)

STYLE_IMAGE="Watercolor storybook illustration, traditional watercolor painting, children's book illustration style, impressionistic watercolor, dreamy landscape, soft Ghibli-inspired atmosphere, magical gentle mood, soft pastel colors"
