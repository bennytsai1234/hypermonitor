# 交易所 API 功能與調整指南 (API Capabilities & Tuning Guide)

本文件整理了 Binance 與 OKX 官方文檔中，與本策略最相關的進階功能。您可以根據這些資訊，對程式碼或設定進行更細緻的調整。

參考文檔:
- **Binance**: [Derivatives API Docs](https://developers.binance.com/docs/derivatives/)
- **OKX**: [V5 API Overview](https://www.okx.com/docs-v5/en/#overview)

---

## 1. 訂單類型 (Order Types)

目前的機器人主要使用 `LIMIT` (限價單) 與 `MARKET` (市價單)。根據 API 文檔，您還可以擴充以下類型：

| 功能 (Feature) | Binance 參數 | OKX 參數 | 說明 |
| :--- | :--- | :--- | :--- |
| **限價單** | `LIMIT` | `limit` | 指定價格買賣 (目前使用中)。 |
| **市價單** | `MARKET` | `market` | 以當前最優價立即成交。 |
| **只做 Maker** | `LIMIT` + `timeInForce: GTX` | `post_only` | **Post Only**。保證掛單不會立即成交 (吃單)，若會成交則自動取消。可節省手續費。 |
| **止損單** | `STOP` / `STOP_MARKET` | `conditional` | 當價格達到觸發價時才下單。用於 **止損 (Stop Loss)**。 |
| **追蹤止損** | `TRAILING_STOP_MARKET` | `move_order_stop` | 止損價會隨著獲利方向移動 (保住利潤)。 |

### 🛠 如何調整?
若要啟用 **Post Only (只做 Maker)**，需修改 API 請求參數：
- **Binance (`binance-api.js`)**: 在 `placeOrder` 的 params 中加入 `timeInForce: 'GTX'` (Good Till Crossing)。
- **OKX (`okx-api.js`)**: 將 `ordType` 改為 `post_only`。

---

## 2. 有效方式 (Time In Force)

控制限價單在訂單簿上的存活時間。

| 模式 | 說明 | 適用場景 |
| :--- | :--- | :--- |
| **GTC** (Good Till Cancel) | **訂單持續有效**，直到完全成交或被手動取消。(本機器人預設) | 一般掛單。 |
| **IOC** (Immediate Or Cancel) | 立即成交部分，未成交部分立即取消。 | 急需進場但不願等待掛單。 |
| **FOK** (Fill Or Kill) | 必須**全部**立即成交，否則全部取消。 | 大額交易，避免部分成交。 |

---

## 3. 倉位與保證金模式 (Position & Margin Settings)

這是風險管理的核心設定，通常在帳戶層級調整。

### A. 倉位模式 (Position Mode)
- **單向持倉 (One-way Mode)**: 一個合約只能有一個方向的倉位 (做多就不能做空，反之亦然)。簡單直觀。**(本機器人預設)**
- **雙向持倉 (Hedge Mode)**: 允許同時持有 **多單 (Long)** 與 **空單 (Short)**。適合對沖策略。

### B. 保證金模式 (Margin Mode)
- **全倉 (Cross Margin)**: 帳戶內所有餘額都作為保證金。優點是資金利用率高，缺點是一旦爆倉會虧光所有餘額。**(本機器人預設)**
- **逐倉 (Isolated Margin)**: 每個倉位獨立分配保證金。爆倉只會損失該倉位分配的資金，不影響帳戶其他餘額。

### 🛠 如何調整?
- **Binance**: 使用 `POST /fapi/v1/positionSide/dual` 切換持倉模式。
- **OKX**: 使用 `POST /api/v5/account/set-position-mode` 切換 (`net_mode` vs `long_short_mode`)。

---

## 4. 數據與延遲優化 (Data Streams)

目前機器人使用 **輪詢 (Polling)** 方式 (每 X 秒問一次 API)。若需要更極致的速度，可改用 **WebSocket**。

- **User Data Stream**:
    - **Binance**: 訂閱 `ListenKey`，當訂單成交時，伺服器會主動推播通知 (低延遲)。
    - **OKX**: 訂閱 `orders` 頻道。
- **調整建議**:
    - 若您的策略對 **秒級** 反應很敏感，建議未來將 `fetchLatest()` 改寫為 WebSocket 監聽模式。

---

## 總結
本機器人目前採用 **穩健型設定** (GTC 限價單、單向持倉、全倉模式)。
若您希望進一步優化 (例如節省手續費或增加止損保護)，可參考上述表格修改 `api.js` 中的相關參數。
