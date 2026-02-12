-- 資料表 A：超級印鈔機全體數據 (100% 欄位補齊)
CREATE TABLE IF NOT EXISTS printer_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    wallet_count INTEGER,
    profit_count INTEGER,
    loss_count INTEGER,
    long_vol_num REAL,    -- 原始數值
    short_vol_num REAL,   -- 原始數值
    net_vol_num REAL,     -- 原始數值
    sentiment TEXT,       -- 情緒字串
    long_display TEXT,    -- 格式化顯示 (如 $5.92億)
    short_display TEXT,
    net_display TEXT
);

-- 資料表 B：BTC/ETH 24h 範圍數據
CREATE TABLE IF NOT EXISTS range_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    symbol TEXT,          -- 'btc' 或 'eth'
    long_vol REAL,
    short_vol REAL,
    total_vol REAL,
    net_vol REAL,
    long_display TEXT,
    short_display TEXT,
    total_display TEXT,
    net_display TEXT
);

CREATE INDEX IF NOT EXISTS idx_printer_time ON printer_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_range_time ON range_metrics(timestamp);

-- 複合索引：加速 WHERE symbol=? AND timestamp>? 的查詢
CREATE INDEX IF NOT EXISTS idx_range_symbol_time ON range_metrics(symbol, timestamp);
