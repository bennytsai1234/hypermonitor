# Android (Termux) 部署指南

利用您舊有的 Android 手機運行交易機器人是一個非常棒的選擇！手機本身就是一個自帶 UPS (電池)、低功耗、且 24 小時聯網的伺服器。

雖然您安裝了 Linux (Proot)，但我建議直接使用 **Termux 原生環境** 運行 Node.js，因為它對硬體資源 (CPU 喚醒鎖) 的控制更好，更省電且穩定。

以下是完整的部署步驟：

## 1. 環境準備 (在 Termux 中執行)

首先，確保 Termux 是最新的，並安裝 Node.js 和 Git。

```bash
# 更新套件列表
pkg update && pkg upgrade -y

# 安裝 Node.js (LTS 版本), Git, 和 OpenSSH
pkg install nodejs-lts git openssh -y

# 安裝 PM2 (進程管理器，讓機器人在後台長駐)
npm install pm2 -g
```

## 2. 獲取代碼

您可以選擇通過 Git 下載，或者如果您已經在電腦上寫好，可以通過 SFTP 傳輸。最簡單的是直接 Clone 您的 Repo (如果有的話)，或是創建資料夾手動複製文件。

假設您將代碼放在 `~/hyper-bots` 目錄：

```bash
# 建立目錄
mkdir -p ~/hyper-bots
cd ~/hyper-bots

# (選項 A) 如果您有 GitHub Repo
git clone <您的_repo_url> .

# (選項 B) 如果您要手動將電腦上的檔案傳過去
# 1. 在 Termux 啟動 SSH server:
#    passwd (設定密碼)
#    sshd
# 2. 在電腦上使用 FileZilla 或 scp 連線到手機 IP (Port 8022) 上傳檔案
```

## 3. 安裝依賴與設定

針對兩個機器人分別進行設定。

### 設定 Hyperliquid (OKX) 機器人
```bash
cd ~/hyper-bots/trading_signal

# 安裝依賴
npm install

# 設定環境變數 (複製範例並編輯)
cp .env.example .env
nano .env
# -> 在這裡填入您的 OKX API Key 和配置
# -> 按 Ctrl+X, Y, Enter 存檔離開
```

### 設定 Binance 機器人
```bash
cd ~/hyper-bots/trading_signal_binance

# 安裝依賴
npm install

# 設定環境變數
cp .env.example .env
nano .env
# -> 在這裡填入您的 Binance API Key 和配置
```

## 4. 啟動機器人 (使用 PM2)

PM2 能確保機器人在背景執行，崩潰自動重啟，並生成日誌。

```bash
# 回到根目錄或分別進入目錄啟動
cd ~/hyper-bots

# 啟動 OKX 機器人
pm2 start trading_signal/signal.js --name "okx-bot"

# 啟動 Binance 機器人
pm2 start trading_signal_binance/signal.js --name "binance-bot"

# 查看狀態
pm2 list

# 查看即時日誌 (想看在做什麼時用這個)
pm2 logs
# (按 Ctrl+C 退出日誌檢視，機器人不會停)
```

## 5. 關鍵步驟：防止手機休眠 (Wake Lock)

Android 系統非常積極地想讓手機休眠以省電。如果不鎖定 CPU，螢幕關閉幾分鐘後機器人就會停止運作。

### 方法 A: 通知列鎖定 (推薦)
1. 在 Termux 畫面中，下拉通知列。
2. 找到 Termux 的通知，點擊 "Acquire wakelock" (獲取喚醒鎖)。
3. 當顯示 "Wake lock held" 時，即使螢幕關閉，CPU 也會保持連線運作。

### 方法 B: 指令鎖定
在 Termux 中執行：
```bash
termux-wake-lock
```
(要解除使用 `termux-wake-unlock`)

## 6. 其他優化建議

*   **電池優化白名單**:
    進入 Android 設定 -> 應用程式 -> Termux -> 電池 -> 設為 "不受限制" (Unrestricted) 或 "關閉電池最佳化"。這是**必須**的，否則系統可能會強行殺掉 Termux。
*   **開機自啟**:
    如果您希望手機重開機後自動跑：
    ```bash
    pm2 save
    pm2 startup
    # 複製它顯示的指令並執行 (但在 Termux 中可能需要額外配置 boot script，通常手動開 pm2 resurrect 即可)
    ```

## 常見問題

*   **Q: 我需要用 Linux (Ubuntu) 系統嗎？**
    *   A: **不需要**。這兩個腳本非常輕量，直接在 Termux 原生環境跑效率最高。Linux 容器會增加額外的資源消耗。
*   **Q: 網路斷了怎麼辦？**
    *   A: 機器人會報錯 (Fetch failed)，PM2 會保持它運行，網路恢復後它會在下一次輪詢 (Polling) 時自動恢復正常。確保手機連上穩定的 WiFi。

祝您交易順利！
