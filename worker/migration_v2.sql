-- 遷移腳本: 為那 6 個新群體新增 42 個欄位
-- 請在 Cloudflare Dashboard (D1 分頁) 執行，或透過 Wrangler 執行

-- Grinder ($1w - $10w)
ALTER TABLE printer_metrics ADD COLUMN grinder_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN grinder_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN grinder_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN grinder_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN grinder_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN grinder_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN grinder_sentiment TEXT;

-- Humble Earner (0 - $1w)
ALTER TABLE printer_metrics ADD COLUMN humble_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN humble_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN humble_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN humble_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN humble_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN humble_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN humble_sentiment TEXT;

-- Exit Liquidity (0 - -$1w)
ALTER TABLE printer_metrics ADD COLUMN exit_liq_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN exit_liq_sentiment TEXT;

-- Semi Rekt (-$1w - -$10w)
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN semi_rekt_sentiment TEXT;

-- Full Rekt (-$10w - -$100w)
ALTER TABLE printer_metrics ADD COLUMN full_rekt_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN full_rekt_sentiment TEXT;

-- Giga Rekt (-$100w - ∞)
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_wallet_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_profit_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_loss_count INTEGER;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_long_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_short_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_net_vol_num REAL;
ALTER TABLE printer_metrics ADD COLUMN giga_rekt_sentiment TEXT;
