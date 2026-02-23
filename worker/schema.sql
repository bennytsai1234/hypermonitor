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
    net_display TEXT,
    -- Smart Money ($10w - $100w)
    smart_wallet_count INTEGER,
    smart_profit_count INTEGER,
    smart_loss_count INTEGER,
    smart_long_vol_num REAL,
    smart_short_vol_num REAL,
    smart_net_vol_num REAL,
    smart_sentiment TEXT,
    smart_long_display TEXT,
    smart_short_display TEXT,
    smart_net_display TEXT,
    -- Grinder ($1w - $10w)
    grinder_wallet_count INTEGER,
    grinder_profit_count INTEGER,
    grinder_loss_count INTEGER,
    grinder_long_vol_num REAL,
    grinder_short_vol_num REAL,
    grinder_net_vol_num REAL,
    grinder_sentiment TEXT,
    -- Humble Earner (0 - $1w)
    humble_wallet_count INTEGER,
    humble_profit_count INTEGER,
    humble_loss_count INTEGER,
    humble_long_vol_num REAL,
    humble_short_vol_num REAL,
    humble_net_vol_num REAL,
    humble_sentiment TEXT,
    -- Exit Liquidity (0 - -$1w)
    exit_liq_wallet_count INTEGER,
    exit_liq_profit_count INTEGER,
    exit_liq_loss_count INTEGER,
    exit_liq_long_vol_num REAL,
    exit_liq_short_vol_num REAL,
    exit_liq_net_vol_num REAL,
    exit_liq_sentiment TEXT,
    -- Semi Rekt (-$1w - -$10w)
    semi_rekt_wallet_count INTEGER,
    semi_rekt_profit_count INTEGER,
    semi_rekt_loss_count INTEGER,
    semi_rekt_long_vol_num REAL,
    semi_rekt_short_vol_num REAL,
    semi_rekt_net_vol_num REAL,
    semi_rekt_sentiment TEXT,
    -- Full Rekt (-$10w - -$100w)
    full_rekt_wallet_count INTEGER,
    full_rekt_profit_count INTEGER,
    full_rekt_loss_count INTEGER,
    full_rekt_long_vol_num REAL,
    full_rekt_short_vol_num REAL,
    full_rekt_net_vol_num REAL,
    full_rekt_sentiment TEXT,
    -- Giga Rekt (-$100w - ∞)
    giga_rekt_wallet_count INTEGER,
    giga_rekt_profit_count INTEGER,
    giga_rekt_loss_count INTEGER,
    giga_rekt_long_vol_num REAL,
    giga_rekt_short_vol_num REAL,
    giga_rekt_net_vol_num REAL,
    giga_rekt_sentiment TEXT
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
    price REAL,           -- OKX 實時價格
    long_display TEXT,
    short_display TEXT,
    total_display TEXT,
    net_display TEXT
);

CREATE INDEX IF NOT EXISTS idx_printer_time ON printer_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_range_time ON range_metrics(timestamp);

-- 複合索引：加速 WHERE symbol=? AND timestamp>? 的查詢
CREATE INDEX IF NOT EXISTS idx_range_symbol_time ON range_metrics(symbol, timestamp);




