# 📱 Hyper Monitor 手機版部署指南 (Termux + Ubuntu)

這份指南教你如何將閒置的 Android 手機 (推薦 Snapdragon 845 或更高) 變成 **24/7 超高效能爬蟲伺服器**。實測比免費 VPS 快 4 倍！

---

## 🚀 第一階段：手機端準備 (Termux)

### 1. 安裝 Termux
請至 [F-Droid 下載 Termux](https://f-droid.org/en/packages/com.termux/) (不要用 Google Play 版本)。

### 2. 初始化環境 & 安裝 SSH
打開 Termux，輸入以下指令：

```bash
# 更新套件
pkg update -y && pkg upgrade -y

# 安裝基礎工具
pkg install openssh proot-distro -y

# 設定 SSH 密碼 (電腦連線用)
passwd
# 輸入兩次密碼 (輸入時不會顯示)

# 查詢使用者名稱 & IP
whoami    # 記下這個名字 (例如 u0_a231)
ifconfig  # 找到 wlan0 的 inet IP (例如 192.168.1.105)

# 啟動 SSH 服務
sshd
```

### 3. 設定手機保活 (關鍵!)
為防止 Android 殺後台：
1.  **Termux 通知欄**：點擊 **"Acquire wakelock"** (確保它一直亮著)。
2.  **電池設定**：手機設定 -> 應用程式 -> Termux -> 電池 -> **無限制 / 不受限制**。

---

## 💻 第二階段：電腦端連線與部署

### 1. SSH 連線
回到電腦 (Windows PowerShell)，輸入：

```powershell
# 格式: ssh -p 8022 [使用者]@[IP]
# 範例:
ssh -p 8022 u0_a231@192.168.1.105
```
輸入剛剛設定的密碼，看到 `$` 符號即連線成功。

### 2. 安裝 Ubuntu 環境 (Proot)
在 Termux (SSH) 裡面輸入：

```bash
# 安裝 Ubuntu
proot-distro install ubuntu

# 登入 Ubuntu
proot-distro login ubuntu
```
(游標變成 `root@localhost` 代表已進入 Ubuntu)

### 3. 安裝爬蟲環境 (在 Ubuntu 內)

```bash
# 更新 Ubuntu & 安裝工具
apt update && apt upgrade -y
apt install -y curl git chromium-browser nano

# 安裝 Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 安裝 PM2 (進程管理器)
npm install -g pm2
```

### 4. 下載程式碼 & 安裝依賴

```bash
# 下載專案 (Public Repo)
git clone https://github.com/bennytsai1234/hypermonitor.git
cd hypermonitor/scripts/cloud-scraper

# 安裝依賴 (告知 Puppeteer 使用系統 Chromium)
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
npm install
```

---

## 🏃 第三階段：啟動與管理

### 1. 啟動爬蟲 (PM2 背景執行)
```bash
# 啟動 (每 3 秒檢查一次，極速模式)
pm2 start scraper.js --name "hyper-scraper" --env PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# 保存設定 (讓 PM2 記得)
pm2 save
```

### 2. 驗證是否成功
```bash
# 查看即時日誌
pm2 logs hyper-scraper
```
如果看到綠色的 `Printer:✅ Range:✅` 並且時間持續更新，就成功了！可以按 `Ctrl+C` 退出日誌，**直接關閉 SSH 視窗**，手機會繼續跑。

---

## 🛠️ 日常維護指令

### 重連 Ubuntu
```bash
# 1. 電腦 SSH 連進手機
ssh -p 8022 u0_a231@192.168.1.xxx

# 2. 進入 Ubuntu
proot-distro login ubuntu
```

### PM2 管理指令
```bash
pm2 status              # 查看狀態
pm2 logs hyper-scraper  # 查看日誌
pm2 stop hyper-scraper  # 停止爬蟲
pm2 restart hyper-scraper # 重啟爬蟲
```

### 更新程式碼
```bash
cd ~/hypermonitor/scripts/cloud-scraper
git pull
pm2 restart hyper-scraper
```

---

### ⚠️ 常見問題
1.  **連不上 SSH？**
    -   檢查手機和電腦是否在同一個 Wi-Fi。
    -   檢查手機 Termux 是否開著 (且有 Acquire wakelock)。
    -   檢查手機 IP 是否變了 (重開機可能會變)。
2.  **爬蟲掛了 (Error)？**
    -   檢查 Internet 連線。
    -   `pm2 logs` 看錯誤訊息。
    -   如果是 `Browser launch failed`，確認 `PUPPETEER_EXECUTABLE_PATH` 環境變數是否正確。

---
**Enjoy your high-performance mobile scraper! 🚀**
