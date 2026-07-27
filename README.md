# fb-tools — Facebook Page Automation

Auto post bài lên Facebook Page **Bài Học Hôm Nay** bằng Composio CLI + Gemini AI.

## Tính năng

| Script | Mô tả |
|--------|-------|
| `auto-post.sh` | 🤖 Tự động: chọn chủ đề → làm thơ → tạo ảnh → đăng |
| `comment-post.sh` | Bình luận dưới bài viết (kèm link/ảnh) |
| `post-text.sh` | Đăng bài text |
| `post-image.sh` | Tạo ảnh Gemini + đăng kèm bài |
| `quick-post.sh` | Đăng nhanh 1 câu |
| `schedule.sh` | Hẹn giờ đăng bài |
| `post-carousel.sh` | Tạo album nhiều ảnh |
| `edit-post.sh` | Sửa bài đã đăng |
| `ai-poem.sh` | Nhập chủ đề → tự viết thơ + vẽ ảnh + đăng |
| `list-pages.sh` | Xem danh sách Page |

## Setup

1. **Clone repo**
2. **Tạo GitHub Secret:** `COMPOSIO_API_KEY` (lấy từ https://dashboard.composio.dev/settings)
3. Workflow sẽ tự động đăng mỗi ngày lúc **7h sáng (giờ VN)**
4. Có thể chạy tay từ tab **Actions** → **FB Auto Post** → **Run workflow**

## Chạy local (WSL)

```bash
cd scripts
./auto-post.sh        # tự động
./post-text.sh        # đăng text
```
