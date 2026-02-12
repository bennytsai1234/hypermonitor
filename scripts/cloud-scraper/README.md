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

### 第四步：安裝環境

```bash
# 更新系統
sudo apt update && sudo apt upgrade -y

# 安裝 Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 安裝 Chromium 依賴 (Puppeteer 需要)
sudo apt install -y chromium-browser

# 驗證安裝
node -v   # 應顯示 v20.x
npm -v
```

### 第五步：上傳腳本

```bash
# 方法一：Git clone
git clone <你的repo> ~/hyper-monitor
cd ~/hyper-monitor/scripts/cloud-scraper

# 方法二：直接 scp 上傳
scp -r scripts/cloud-scraper ubuntu@<VPS_IP>:~/scraper
ssh ubuntu@<VPS_IP>
cd ~/scraper
```

### 第六步：安裝依賴 & 測試

```bash
npm install

# 測試單次執行
node scraper.js --once

# 確認看到類似輸出：
# [2026/02/13 07:52:33] 🚀 Hyper Monitor Cloud Scraper starting...
# [2026/02/13 07:52:38] ✅ Browser launched
# [2026/02/13 07:52:45] ✅ Pages loaded
# [2026/02/13 07:52:50] #1 Printer:✅ Range:✅
```

### 第七步：設定永久運行 (systemd)

```bash
# 建立 service 檔案
sudo tee /etc/systemd/system/hyper-scraper.service << 'EOF'
[Unit]
Description=Hyper Monitor Cloud Scraper
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/hyper-monitor/scripts/cloud-scraper
ExecStart=/usr/bin/node scraper.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# 啟動服務
sudo systemctl daemon-reload
sudo systemctl enable hyper-scraper
sudo systemctl start hyper-scraper

# 查看狀態
sudo systemctl status hyper-scraper

# 查看即時日誌
sudo journalctl -u hyper-scraper -f
```

### 常用管理指令

```bash
# 停止服務
sudo systemctl stop hyper-scraper

# 重啟服務
sudo systemctl restart hyper-scraper

# 查看最近 100 行日誌
sudo journalctl -u hyper-scraper -n 100

# 更新腳本後重啟
cd ~/hyper-monitor && git pull
sudo systemctl restart hyper-scraper
```

## 注意事項

- ARM 伺服器需要使用 `chromium-browser` 而非 Chrome
- 如果 Puppeteer 找不到 Chromium，設定環境變數：
  ```bash
  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
  ```
- 免費方案的出站流量限制：10TB/月（完全夠用）
- 建議設定 Swap 分區以避免 OOM：
  ```bash
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  ```
