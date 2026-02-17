-- Backfill 24 hours of data into aggregated tables
INSERT OR IGNORE INTO printer_1m (bucket, avg_long_vol_num, avg_short_vol_num, avg_net_vol_num, max_wallet_count, last_sentiment, sample_count)
SELECT
    strftime('%Y-%m-%d %H:%M:00', timestamp) as bucket,
    AVG(long_vol_num),
    AVG(short_vol_num),
    AVG(net_vol_num),
    MAX(wallet_count),
    MAX(sentiment),
    COUNT(*)
FROM printer_metrics
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY bucket;

INSERT OR IGNORE INTO range_1m (bucket, symbol, avg_long_vol, avg_short_vol, avg_total_vol, avg_net_vol, sample_count)
SELECT
    strftime('%Y-%m-%d %H:%M:00', timestamp) as bucket,
    symbol,
    AVG(long_vol),
    AVG(short_vol),
    AVG(total_vol),
    AVG(net_vol),
    COUNT(*)
FROM range_metrics
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY bucket, symbol;

-- Backfill 24h into 1h tables as well
INSERT OR IGNORE INTO printer_1h (bucket, avg_long_vol_num, avg_short_vol_num, avg_net_vol_num, max_wallet_count, last_sentiment, sample_count)
SELECT
    strftime('%Y-%m-%d %H:00:00', bucket) as h_bucket,
    AVG(avg_long_vol_num),
    AVG(avg_short_vol_num),
    AVG(avg_net_vol_num),
    MAX(max_wallet_count),
    MAX(last_sentiment),
    SUM(sample_count)
FROM printer_1m
WHERE bucket > datetime('now', '-24 hours')
GROUP BY h_bucket;

INSERT OR IGNORE INTO range_1h (bucket, symbol, avg_long_vol, avg_short_vol, avg_total_vol, avg_net_vol, sample_count)
SELECT
    strftime('%Y-%m-%d %H:00:00', bucket) as h_bucket,
    symbol,
    AVG(avg_long_vol),
    AVG(avg_short_vol),
    AVG(avg_total_vol),
    AVG(avg_net_vol),
    SUM(sample_count)
FROM range_1m
WHERE bucket > datetime('now', '-24 hours')
GROUP BY h_bucket, symbol;
