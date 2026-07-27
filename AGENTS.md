# fb-tools — viết vội vài câu

Auto đăng thơ, danh ngôn, truyện ngắn + ảnh lên Facebook Page, chạy GitHub Actions.

## Project info

- **Page name**: viết vội vài câu
- **Page ID**: 1133589166515175
- **GitHub**: https://github.com/Rochthii/fb-tools
- **Tech**: Composio (free tier) → Gemini 2.5 Flash (text) + Gemini 2.5 Flash Image
- **Schedule**: GitHub Actions cron 4 lần/ngày (0,6,12,18h UTC) + manual trigger

## File structure

```
fb-tools/
├── opencode.json          # opencode config
├── AGENTS.md              # hướng dẫn cho AI
├── .github/workflows/
│   ├── auto-post.yml      # workflow chính
│   └── analytics.yml      # workflow báo cáo thủ công
├── scripts/
│   ├── config.sh          # PAGE_ID, model, genres, weights, style
│   ├── themes.json        # 8 genres x 6-10 topics
│   ├── auto-post.sh       # pipeline chính (có fallback toàn bộ)
│   ├── auto-reply.sh      # quét + trả lời comment
│   ├── auto-hashtag.sh    # sinh hashtag standalone
│   └── analytics.sh       # thống kê từ logs/posts.csv
└── logs/
    └── posts.csv          # lịch sử bài đăng
```

## Scripts

- `auto-post.sh` — pipeline đầy đủ: chọn genre (weighted random) → sinh nội dung (Gemini) → hashtag → ảnh → đăng FB → comment → log
- `auto-reply.sh` — quét comment mới, reply tự động
- `auto-hashtag.sh "nội dung"` — sinh hashtag standalone
- `analytics.sh` — xem thống kê

## Các hạng mục đã làm

- [x] Multi-genre (8 thể loại) + weighted random selection
- [x] Genre-specific prompt templates
- [x] Image generation (Gemini 2.5 Flash Image)
- [x] Hashtag thông minh
- [x] Auto-comment dưới bài đăng
- [x] Auto-reply (quét + trả lời comment)
- [x] Analytics log (posts.csv) + script xem thống kê
- [x] Fallback toàn bộ (config thiếu, AI lỗi, ảnh lỗi, post lỗi → đều có đường lui)
- [x] Style ảnh watercolor storybook (Ghibli-inspired)

## Lưu ý khi làm việc

- COMPOSIO_API_KEY được lưu trong GitHub Secrets
- `scripts/config.sh` dùng path Composio Linux (`/root/.composio/composio`) — khi chạy WSL cần đảm bảo đúng path
- Nếu muốn test local: pull repo vào WSL, cài Composio, chạy `bash scripts/auto-post.sh`
- Nếu thêm genre mới: cập nhật cả `config.sh` (GENRES + GENRE_WEIGHTS) và `themes.json`, thêm prompt mới trong `auto-post.sh`
- `auto-reply.sh` dùng file `/tmp/ap_reply_last.txt` để track post đã reply
