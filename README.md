# ⚡ Hyperliquid 超級印鈔機監控終端 (v1.2.0)

## 1. 專案概述 (Project Overview)
本系統為專為專業加密貨幣交易員設計的 Windows 桌面端監控程式。旨在實時追蹤 Coinglass 上的「超級印鈔機 (Super Money Printer)」策略動向，透過可視化數據揭示大戶資金流向與對沖狀態。

*   **核心目標**：捕捉大戶資金的即時跳變 (Delta)，提供比網頁更靈敏的視覺反饋。
*   **技術架構**：Flutter (Dart) + Headless WebView (Windows)。
*   **語言環境**：全繁體中文 (Traditional Chinese)。

---

## 2. 核心邏輯與數據流 (Core Logic & Data Flow)

### 2.1 數據採集 (Scraping Architecture)
系統採用 **雙路獨立採集** 架構，確保不同來源的數據互不干擾，解決了「數據覆蓋/歸零」的問題。

*   **來源 A (Printer Source)**：
    *   **目標**：抓取全體多空規模、盈虧帳戶數、市場情緒。
    *   **頻率**：10 秒。
    *   **邏輯**：精確定位「超級印鈔機」所在行，直接抓取多/空與淨壓單元格。
    *   **情緒抓取**：精確鎖定 `button.tag-but` 內的文字（看漲/看跌）。

*   **來源 B (Range Source)**：
    *   **目標**：抓取 BTC 與 ETH 的詳細持倉。
    *   **頻率**：10 秒。
    *   **邏輯**：針對 Material UI 結構，透過類名與內容過濾，精確提取行內持倉數值。
    *   **防錯機制**：嚴格避開「當前價格」單元格，防止將價格誤判為持倉量。

### 2.2 數據更新與通知 (Update & Notification)
為防止數據互相覆蓋，系統採用 **分流更新機制**：

1.  **全體更新 (`_onPrinterData`)**：僅更新 UI 的左欄（全體數據），保留中/右欄現有資產數據。
2.  **資產更新 (`_onRangeData`)**：僅更新右欄（BTC/ETH）與中欄（核心對沖計算），保留左欄數據。

### 2.3 增量計算與噪點過濾 (Delta & Noise Filter)
*   **計算公式**：`Delta = Current Value - Previous Value`
*   **顏色邏輯**：
    *   **紅色卡片 (空頭/賣壓)**：增加顯示紅色 +，減少顯示綠色 -。
    *   **綠色卡片 (多頭/買壓)**：增加顯示綠色 +，減少顯示紅色 -。
*   **噪點過濾**：變動量（Delta）必須大於 **$50,000 USD** 才會顯示標籤並觸發大閃爍，有效過濾網頁渲染誤差。
*   **持久化顯示 (Sticky Deltas)**：Delta 標籤具有「黏性」。只有發生「真實跳變」時才會更新，否則標籤會維持在畫面上或根據變動規則清零。

---

## 3. UI/UX 設計規範 (Design Specifications)

### 3.1 視覺風格 (Visual Style)
*   **主題**：**OLED 極致純黑** (Background: `#000000`, Card: `#080808`)。
*   **配色**：霓虹綠 (`#00FF9D`)、霓虹紅 (`#FFFF2E2E`)、比特幣橙 (`#F7931A`)。
*   **字體**：全介面高清晰白字，座標軸數值調亮確保量化觀察。

### 3.2 佈局結構：三柱擎天 (Tri-Pillar Layout)
由左至右垂直排列，資訊層級分明：

| 區域 | 內容 | 關鍵視覺 |
| :--- | :--- | :--- |
| **左欄** | **全體印鈔機狀況** | 全體淨壓(帶霓虹框)、全體多空比例、全體資金趨勢圖 |
| **中欄** | **核心對沖 (BTC+ETH)** | 對沖淨壓(帶霓虹框)、核心多空比例、對沖淨值趨勢圖 |
| **右欄** | **BTC / ETH 監控** | 單幣淨壓(帶霓虹框)、持倉佔比、各別資金趨勢圖 |

### 3.3 交互與警示 (Interaction & Alerts)
*   **全螢幕**：按 **F11** 切換。支援從最大化狀態直接一鍵全螢幕。
*   **大閃爍 (The Big Flash)**：
    *   觸發條件：任一有效數據變動 (> $50k)。
    *   效果：全螢幕 **40% 透明度** 彩虹霓虹閃爍 + 25px 彩色邊框提醒。

---

## 4. 檔案結構 (File Structure)

```
lib/
├── main.dart                  # 程式入口，視窗管理器初始化
├── core/
│   ├── data_model.dart        # 數據模型定義
│   └── data_scraper.dart      # 雙路爬蟲引擎 (帶自動簡轉繁)
└── ui/
    ├── dashboard_screen.dart  # 主畫面邏輯 (分流更新, 閃爍控制)
    └── widgets/
        ├── metric_card.dart   # 數據卡片 (支援彩色邊框與高對比)
        ├── trend_chart.dart   # 經典趨勢圖 (帶數值座標軸)
        ├── tug_of_war_bar.dart# 多空比例條 (帶 50% 戰線)
        └── sentiment_badge.dart # 情緒勳章
```

---

## 5. 開發備註
*   本程式依賴 Coinglass 的網頁 DOM 結構，若該網站改版，需更新 `data_scraper.dart` 中的 JS 選擇器。
*   Windows 版運行時需要 WebView2 Runtime 支援。