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
ssh -p 8022 u0_a192@192.168.2.8
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

## 🏃 第三階段：啟動與管理 (關鍵：防止 SSH 斷線死機)

這一步最重要！如果你直接啟動，SSH 斷線後爬蟲就會死掉。
我們必須使用 `tmux` (終端機多工器) 來讓它永遠在背景執行。

### 1. 安裝與啟動 tmux (在 Termux 層)
請先確保你在 Termux 的初始畫面 (如果已經在 Ubuntu 裡，請輸入 `exit` 退出來)。

```bash
# 安裝 tmux
pkg install tmux -y

# 啟動一個名為 "hyper" 的背景視窗
tmux new -s hyper-ubuntu
```
(此時畫面會清空，下方出現綠色狀態列，代表你已進入不死的背景視窗)

### 2. 在 tmux 裡面進入 Ubuntu 並啟動爬蟲
```bash
# 進入 Ubuntu
proot-distro login ubuntu

# 進入資料夾
cd hypermonitor/scripts/cloud-scraper

# 啟動爬蟲
pm2 delete hyper-scraper  # 清理舊的 (如果有的話)
pm2 start scraper.js --name "hyper-scraper" --hp /root
pm2 save
```

### 3. 分離視窗 (Detach) - 這步做完就可以關閉 SSH 了！
1. 按下鍵盤 `Ctrl` + `b` (按住 Ctrl 點一下 b)
2. 放開所有按鍵
3. 按一下 `d`

你會看到 `[detached]` 字樣，並且回到原本的 Termux 畫面。
**恭喜！現在你可以放心地關閉 SSH 或電腦，爬蟲會在手機背景永遠執行！**

### 4. 之後如何回來查看？
下次 SSH 連進手機後，輸入：
```bash
tmux attach -t hyper-ubuntu
```
你就會瞬間回到 Ubuntu 的畫面。

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
# 更新後建議重啟
pm2 restart hyper-scraper
```

---

## ⚠️ 故障排除 (Troubleshooting)

### 1. 爬蟲卡住不更新 (Hang)？
- **症狀**：`pm2 status` 顯示 online，但 `pm2 logs` 完全沒有新內容。
- **原因**：手機網路波動導致請求卡死。
- **解法**：最新版代碼已加入 **10秒強制超時 (Timeout)** 機制。請執行 `git pull` 更新代碼並重啟即可。

### 2. 錯誤：`Failed to launch the browser process`
- **原因**：Puppeteer 找不到 Chrome。
- **解法**：最新版代碼已 **硬編碼 (Hardcoded)** 指定使用 Termux 系統自帶的 `/usr/bin/chromium`。
    1.  確認已安裝 Chromium: `pkg install chromium -y` (在 Termux) 或 `apt install chromium-browser -y` (在 Ubuntu)。
    2.  執行 `git pull` 更新代碼。
    3.  刪除舊排程並重啟：`pm2 delete hyper-scraper && pm2 start scraper.js --name "hyper-scraper"`。

### 3. 連不上 SSH？
- 檢查手機和電腦是否在同一個 Wi-Fi。
- 檢查手機 Termux 是否開著 (且有 Acquire wakelock)。
- 檢查手機 IP 是否變了 (重開機可能會變)。

---
**Enjoy your high-performance mobile scraper! 🚀**
