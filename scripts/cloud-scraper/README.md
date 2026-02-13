# Hyper Monitor — 雲端爬蟲部署指南

## 概述

這個爬蟲腳本使用 Node.js + Puppeteer，替代 Flutter App 的 WebView 抓取功能。
部署到雲端伺服器後，你的電腦就不需要 24/7 開機了。

## 本地測試

```bash
# 1. 安裝依賴
cd scripts/cloud-scraper
npm install

# 2. 測試單次執行
node scraper.js --once

# 3. 持續運行
node scraper.js
```

## 環境變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `API_URL` | `https://hyper-monitor-worker.bennytsai0711.workers.dev` | Worker API 位址 |
| `API_KEY` | (空) | 選填，若 Worker 有設定 API Key |
| `INTERVAL` | `10` | 抓取間隔（秒） |

## 部署到 Oracle Cloud Free VPS

### 第一步：申請 Oracle Cloud 帳號

1. 前往 [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
2. 點「Start for Free」註冊
3. 需要信用卡驗證（不會扣款）
4. 選擇 Region（建議選日本 `ap-osaka-1` 或新加坡 `ap-singapore-1`，延遲低）

### 第二步：建立免費 VM

1. 登入 Oracle Cloud Console
2. 點「Create a VM instance」
3. Image: **Ubuntu 22.04** (或 24.04)
4. Shape: **VM.Standard.A1.Flex** (ARM, 永久免費)
   - OCPU: 1 (最多可選 4)
   - RAM: 6GB (最多可選 24GB)
5. 增加 SSH Key (用來遠端登入)
6. 點「Create」建立

### 第三步：連線到 VPS

```bash
ssh ubuntu@<你的VPS公網IP>
```

### 第四步：新 VPS 快速部署 (懶人包)

連上 VPS 後，依序貼上以下指令即可：

```bash
# 1. 切換到 root 權限 (避免權限問題)
sudo -i

# 2. 更新系統 & 安裝必要套件
apt update && apt upgrade -y
apt install -y curl git chromium-browser

# 3. 安裝 Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 4. 建立目錄並下載程式碼 (從你的 GitHub 或直接上傳)
mkdir -p /home/ubuntu/scraper
cd /home/ubuntu/scraper

# 注意：這裡假設你已經把 scripts/cloud-scraper 的檔案上傳進來了。
# 如果你還沒上傳，請在你的電腦上執行 (記得替換 IP 和 Key 路徑)：
# scp -i your_key.key -r scripts/cloud-scraper/* ubuntu@<VPS_IP>:/home/ubuntu/scraper/

# 5. 安裝依賴 (Puppeteer)
# 設定環境變數讓 Puppeteer 知道用系統的 Chromium (ARM 架構必須)
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
npm install

# 6. 先跑一次測試，確認能抓到數據
node scraper.js --once

# 7. 設定永久自動執行 (建立 Systemd Service)
cat > /etc/systemd/system/hyper-scraper.service <<EOF
[Unit]
Description=Hyper Monitor Cloud Scraper
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/scraper
ExecStart=/usr/bin/node scraper.js
Restart=always
RestartSec=10
Environment=PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
Environment=API_URL=https://hyper-monitor-worker.bennytsai0711.workers.dev
# Environment=API_KEY=你的API_KEY (如果 Worker 有設)

[Install]
WantedBy=multi-user.target
EOF

# 8. 啟動並設定開機自啟
systemctl daemon-reload
systemctl enable hyper-scraper
systemctl start hyper-scraper

# 9. 檢查狀態 (應該要是綠色的 active (running))
systemctl status hyper-scraper

# 10. 查看即時日誌
journalctl -u hyper-scraper -f
```

---

## 💡 常見問題

### Q: 為什麼要用 ARM (VM.Standard.A1.Flex)？
A: Oracle 的 ARM 機器給 4 核心 / 24GB RAM，效能遠強於 AMD 免費機 (1/8 核心)。Puppeteer 跑爬蟲需要 RAM，ARM 是最佳選擇。

### Q: 為什麼 Puppeteer 安裝失敗？
Oracle ARM 架構下，直接 `npm install puppeteer` 預設下載的 Chromium (x86) 不能跑。
**解決方案**：
1. `apt install chromium-browser` (安裝 ARM 版 Chromium)
2. `export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true`
3. 執行時使用 `executablePath: '/usr/bin/chromium-browser'` (腳本通常會自動偵測，或手動指定)

### Q: 如何更新腳本？
在你的電腦修改好後，再次 SCP 上傳覆蓋，然後在 VPS 執行：
`sudo systemctl restart hyper-scraper`

---
