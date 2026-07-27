# fb-tools — Bài Học Hôm Nay

> **GitHub**: https://github.com/Rochthii/fb-tools

Auto đăng thơ, danh ngôn, truyện ngắn + ảnh lên Facebook Page, chạy GitHub Actions.
Tích hợp Google Calendar + Gmail + Facebook Insights để lập lịch 30 ngày và báo cáo.

## Project info

- **Page name**: viết vội vài câu (chờ đổi → Bài Học Hôm Nay)
- **Page ID**: 1133589166515175
- **Tech**: Composio → Gemini 2.5 Flash (text/image) + Google Calendar + Gmail
- **Schedule**: GitHub Actions cron 4 lần/ngày + monthly scheduler

## File structure

```
fb-tools/
├── opencode.json              # opencode config
├── AGENTS.md                  # hướng dẫn cho AI
├── .github/workflows/
│   ├── auto-post.yml          # workflow chính (cron, gọi agent.sh)
│   ├── schedule-month.yml     # workflow lập lịch 30 ngày (manual)
│   └── analytics.yml          # workflow báo cáo thủ công
├── scripts/
│   ├── config.sh              # PAGE_ID, model, genres, weights, style + Calendar/Gmail
│   ├── themes.json            # 8 genres x 6-10 topics
│   ├── auto-post.sh           # pipeline chính (có fallback), nhận CLI args
│   ├── agent.sh               # Calendar → đọc event → post bài
│   ├── schedule-month.sh      # Insights → AI schedule → compose 30 bài → Calendar
│   ├── report-month.sh        # aggregate log → Insights → Gmail report
│   ├── connect-calendar.sh    # kiểm tra + verify kết nối Composio
│   ├── auto-reply.sh          # quét + trả lời comment
│   ├── auto-hashtag.sh        # sinh hashtag standalone
│   └── analytics.sh           # thống kê từ logs/posts.csv
└── logs/
    ├── posts.csv              # lịch sử bài đăng
    └── 30day-schedule.json    # lịch 30 ngày (backup)
```

## Scripts

- `auto-post.sh` — pipeline đầy đủ. Nhận `$1=genre $2=topic` từ CLI, nếu không có thì random.
- `agent.sh` — đọc Google Calendar hôm nay → lấy nội dung đã soạn → gen ảnh → đăng FB → comment → log
- `schedule-month.sh` — Insights → AI sinh lịch 30 ngày → compose nội dung → tạo Calendar events
- `report-month.sh` — aggregate log → Facebook Insights → Gmail gửi báo cáo
- `connect-calendar.sh` — verify kết nối + tìm Calendar ID
- `auto-reply.sh` — quét comment mới, reply tự động
- `auto-hashtag.sh "nội dung"` — sinh hashtag standalone
- `analytics.sh` — xem thống kê

## Scheduled workflows

- **auto-post.yml** → chạy cron `0 0,6,12,18 * * *` (4 lần/ngày), gọi `agent.sh`
- **schedule-month.yml** → chạy manual (`workflow_dispatch`), gọi `schedule-month.sh`

## Các hạng mục đã làm

- [x] Multi-genre (8 thể loại) + weighted random selection
- [x] Genre-specific prompt templates
- [x] Image generation (Gemini 2.5 Flash Image)
- [x] Hashtag thông minh
- [x] Auto-comment dưới bài đăng
- [x] Auto-reply (quét + trả lời comment)
- [x] Analytics log (posts.csv) + script xem thống kê
- [x] Fallback toàn bộ
- [x] Style ảnh watercolor storybook (Ghibli-inspired)
- [x] Google Calendar integration (đọc/tạo event)
- [x] AI Agent lập lịch 30 ngày (schedule-month.sh)
- [x] Calendar-based auto-poster (agent.sh)
- [x] Monthly report via Gmail (report-month.sh)
- [x] Facebook Insights thu thập (FACEBOOK_GET_PAGE_INSIGHTS)
- [x] auto-post.sh nhận genre+topic từ CLI args

## Lưu ý khi làm việc

- COMPOSIO_API_KEY được lưu trong GitHub Secrets
- `scripts/config.sh` có `CALENDAR_ID`, `TIMEZONE=Asia/Ho_Chi_Minh`, `PROJECT_NAME="Bài Học Hôm Nay"`
- Cần Composio connections: facebook, googlecalendar, gmail
- `connect-calendar.sh` để verify kết nối
- Lịch 30 ngày lưu ở `logs/30day-schedule.json`
- Chạy `bash scripts/schedule-month.sh` để lập lịch tháng mới
- Chạy `bash scripts/agent.sh` để đăng bài theo lịch
- Chạy `bash scripts/report-month.sh` để gửi báo cáo email
