# fb-tools

Auto đăng thơ + ảnh lên Facebook Page **Bài Học Hôm Nay** — chạy GitHub Actions, không cần mở máy.

## Setup

1. **Vào GitHub → Settings → Secrets → Actions → New secret**
   - Name: `COMPOSIO_API_KEY`
   - Secret: *(lấy từ https://dashboard.composio.dev/settings)*

2. Workflow tự động chạy **7h sáng + 7h tối** mỗi ngày

3. Chạy tay: tab **Actions** → **FB Auto Post** → **Run workflow**

## Chạy local (WSL)

```bash
git clone https://github.com/Rochthii/fb-tools.git ~/fb-tools
cd ~/fb-tools/scripts
./auto-post.sh
```
