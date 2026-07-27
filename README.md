# viết vội vài câu 🤍

Auto đăng thơ, danh ngôn, truyện ngắn + ảnh lên Facebook Page — chạy GitHub Actions, không cần mở máy. Hoàn toàn **miễn phí**.

## Tính năng

| Tính năng | Mô tả |
|-----------|-------|
| 🎭 **Đa thể loại** | Thơ tình, thơ cuộc sống, gia đình, tâm trạng, vui, truyền cảm hứng, danh ngôn, truyện ngắn |
| 🎨 **Tạo ảnh tự động** | Gemini 2.5 Flash Image — free, phong cách watercolor |
| 🏷️ **Hashtag thông minh** | Tự động sinh hashtag theo nội dung |
| 💬 **Comment tự động** | Gemini bình luận tự nhiên dưới bài đăng |
| 📊 **Analytics** | Ghi log bài đăng, thống kê theo thể loại |
| 🔄 **Auto-reply** | Trả lời comment tự động (cần cấu hình thêm) |

## Setup

1. **Vào GitHub → Settings → Secrets → Actions → New secret**
   - Name: `COMPOSIO_API_KEY`
   - Secret: *(lấy từ https://dashboard.composio.dev/settings)*

2. **Vào GitHub → Actions → FB Auto Post → Run workflow** để chạy thủ công

3. **Hoặc tạo workflow cron** (2 lần/ngày):

```yaml
schedule:
  - cron: '0 0,12 * * *'
```

## Chạy local (WSL)

```bash
git clone https://github.com/Rochthii/fb-tools.git ~/fb-tools
cd ~/fb-tools/scripts
chmod +x *.sh
./auto-post.sh
```

## Cấu trúc

```
fb-tools/
├── scripts/
│   ├── config.sh         # Cấu hình: PAGE_ID, model, thể loại
│   ├── auto-post.sh      # Script chính: đa thể loại, hashtag, ảnh
│   ├── auto-reply.sh     # Trả lời comment tự động
│   ├── analytics.sh      # Xem thống kê
│   └── themes.json       # Kho chủ đề 8 thể loại
├── logs/
│   └── posts.csv         # Lịch sử bài đăng
└── README.md
```

## Tuỳ chỉnh

Sửa `scripts/config.sh` để thay đổi:
- `PAGE_ID` — ID page Facebook
- `GENRES` — danh sách thể loại
- `GENRE_WEIGHTS` — tỉ lệ xuất hiện mỗi thể loại
- `STYLE_IMAGE` — phong cách ảnh mặc định

Sửa `scripts/themes.json` để thêm/bớt chủ đề.
