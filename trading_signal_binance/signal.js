/**
 * Hyper Trading Signal — Binance USDⓈ-M Futures Edition
 *
 * Reads Hyperliquid net pressure delta from Worker API,
 * converts it to Binance BTCUSDT perpetual orders.
 *
 * Ratio logic: margin = |delta| × RATIO, notional = margin × LEVERAGE
 * e.g. 100萬 delta → $10 margin × 20x = $200 position
 *
 * Usage:
 *   node signal.js              # Run continuously
 *   node signal.js --dry-run    # Log signals but don't trade
 *   node signal.js --once       # Run once and exit
 */
const CONFIG = require('./config');
const binance = require('./binance-api');
const { sendTelegram } = require('./telegram');

// ============================================
// State
// ============================================
let previousNet = null;
let instrumentInfo = null;
let leverageSet = false;
let lastTradeTime = Date.now();
let tradeIdleAlertSent = false;
let totalTraded = 0;
const TRADE_IDLE_LIMIT = 19 * 60 * 1000; // 19分鐘

// ============================================
// Logging
// ============================================
function log(msg) {
  const now = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false });
  console.log(`[${now}] ${msg}`);
}

// ============================================
// Fetch Latest Data from Worker
// ============================================
let cachedEtag = null;
let cachedData = null;

async function fetchLatest() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout

    const headers = {};
    if (cachedEtag) headers['If-None-Match'] = cachedEtag;

    const res = await fetch(`${CONFIG.WORKER_URL}/latest`, {
      signal: controller.signal,
      headers: headers
    });
    clearTimeout(timeoutId);

    // 304: Data unchanged, use cache
    if (res.status === 304) {
      if (cachedData) return cachedData;
    }

    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const data = await res.json();

    const newEtag = res.headers.get('ETag');
    if (newEtag) cachedEtag = newEtag;
    cachedData = data;

    return data;
  } catch (e) {
    if (e.name === 'AbortError') log(`⏱️ Fetch timeout (5s)`);
    else log(`❌ Fetch latest failed: ${e.message}`);
    return null;
  }
}

// ============================================
// Core Signal Logic
// ============================================
async function processSignal(data) {
  // Select Data Source based on Configuration
  const src = CONFIG.SIGNAL_SOURCE;
  let longVol, shortVol, sentiment, sourceName;

  switch (src) {
    case 'smart':
      sourceName = '🧠 Smart Money';
      longVol = parseFloat(data.smart_long_vol_num) || 0;
      shortVol = parseFloat(data.smart_short_vol_num) || 0;
      sentiment = data.smart_sentiment || '';
      break;
    case 'grinder':
      sourceName = '⚙️ 套利高手';
      longVol = parseFloat(data.grinder_long_vol_num) || 0;
      shortVol = parseFloat(data.grinder_short_vol_num) || 0;
      sentiment = data.grinder_sentiment || '';
      break;
    case 'humble':
      sourceName = '🐜 螞蟻玩家';
      longVol = parseFloat(data.humble_long_vol_num) || 0;
      shortVol = parseFloat(data.humble_short_vol_num) || 0;
      sentiment = data.humble_sentiment || '';
      break;
    case 'exitLiq':
      sourceName = '🤡 合約小白';
      longVol = parseFloat(data.exit_liq_long_vol_num) || 0;
      shortVol = parseFloat(data.exit_liq_short_vol_num) || 0;
      sentiment = data.exit_liq_sentiment || '';
      break;
    case 'semiRekt':
      sourceName = '🔪 割肉俠';
      longVol = parseFloat(data.semi_rekt_long_vol_num) || 0;
      shortVol = parseFloat(data.semi_rekt_short_vol_num) || 0;
      sentiment = data.semi_rekt_sentiment || '';
      break;
    case 'fullRekt':
      sourceName = '🩸 扛單狂人';
      longVol = parseFloat(data.full_rekt_long_vol_num) || 0;
      shortVol = parseFloat(data.full_rekt_short_vol_num) || 0;
      sentiment = data.full_rekt_sentiment || '';
      break;
    case 'gigaRekt':
      sourceName = '💀 爆倉達人';
      longVol = parseFloat(data.giga_rekt_long_vol_num) || 0;
      shortVol = parseFloat(data.giga_rekt_short_vol_num) || 0;
      sentiment = data.giga_rekt_sentiment || '';
      break;
    case 'printer':
    default:
      sourceName = '🖨️ Super Money';
      longVol = parseFloat(data.long_vol_num) || 0;
      shortVol = parseFloat(data.short_vol_num) || 0;
      sentiment = data.sentiment || '';
      break;
  }

  const currentNet = longVol - shortVol;

  // --- DATA ANOMALY GUARD ---
  if (Math.abs(longVol) < 1000000 && Math.abs(shortVol) < 1000000) {
    log(`🛑 Data Anomaly Filtered: Long ${formatUSD(longVol)}, Short ${formatUSD(shortVol)}. Skipping tick.`);
    return;
  }

  // First run: just record, don't trade
  if (previousNet === null) {
    previousNet = currentNet;
    log(`📊 Initial [${sourceName}]: Long ${formatUSD(longVol)} Short ${formatUSD(shortVol)} Net ${formatUSD(currentNet)} (${sentiment})`);
    return;
  }

  if (currentNet === previousNet) return;

  // Calculate delta
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
    return;
  }

  // Check maximum threshold (User template: > 2億 skip)
  const MAX_DELTA = 200000000;
  if (Math.abs(deltaH) > MAX_DELTA) {
    const msg = `🚫 Oversized Signal Blocked
Symbol: ${CONFIG.INST_ID}
Delta: ${formatUSD(deltaH)}
Max Allowed: ${formatUSD(MAX_DELTA)}
Action: Order Skipped
Time: ${new Date().toLocaleString()}`;

    log(msg);
    await sendTelegram(msg).catch(e => log(`❌ Telegram error: ${e.message}`));
    return;
  }

  // Calculate order:
  const marginUSD = Math.abs(deltaH) * CONFIG.RATIO;
  const notionalUSD = marginUSD * CONFIG.LEVERAGE;

  // Get instrument info if not available
  if (!instrumentInfo) {
    instrumentInfo = await binance.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Instrument: minQty=${instrumentInfo.minQty}, stepSize=${instrumentInfo.stepSize}, qtyPrecision=${instrumentInfo.quantityPrecision}`);
  }

  const price = await binance.getPrice(CONFIG.INST_ID);

  // Direction: delta > 0 = BUY, delta < 0 = SELL
  const side = deltaH > 0 ? 'BUY' : 'SELL';

  // Strategy Thresholds
  const MARKET_THRESHOLD = 4000000; // 400萬
  const absDelta = Math.abs(deltaH);

  let orderType = '';
  let orderOpts = {};
  let targetPrice = 0;
  let strategyNote = '';

  // Hybrid Strategy
  if (absDelta < MARKET_THRESHOLD) {
    // --- Case A: Small Delta (< 400萬) → Limit Strategy (6m Candle Price) ---
    let klines = [];
    try {
      klines = await binance.getKlines(CONFIG.INST_ID, '1m', 15);
    } catch (e) {
      log(`⚠️ Fetch klines failed: ${e.message}`);
    }

    const now = Date.now();
    const BLOCK_MS = 6 * 60 * 1000;
    const currentBlockStart = now - (now % BLOCK_MS);
    const prevBlockStart = currentBlockStart - BLOCK_MS;

    const targetCandles = klines.filter(k => {
      const openTime = k[0];
      return openTime >= prevBlockStart && openTime < currentBlockStart;
    });

    if (targetCandles.length > 0) {
      let blockHigh = -Infinity;
      let blockLow = Infinity;

      for (const c of targetCandles) {
        const h = parseFloat(c[2]);
        const l = parseFloat(c[3]);
        if (h > blockHigh) blockHigh = h;
        if (l < blockLow) blockLow = l;
      }

      if (side === 'BUY') {
        if (price < blockLow) {
          targetPrice = price;
          strategyNote = `(Curr ${price} < 6m Low ${blockLow} → Limit@Curr)`;
        } else {
          targetPrice = blockLow;
          strategyNote = `(Limit @ 6m Low ${blockLow})`;
        }
      } else {
        if (price > blockHigh) {
          targetPrice = price;
          strategyNote = `(Curr ${price} > 6m High ${blockHigh} → Limit@Curr)`;
        } else {
          targetPrice = blockHigh;
          strategyNote = `(Limit @ 6m High ${blockHigh})`;
        }
      }
      log(`🕯️ Prev 6m Candle [${new Date(prevBlockStart).toLocaleTimeString()}]: High ${blockHigh}, Low ${blockLow}, Curr ${price}`);
    } else {
      log(`⚠️ No complete 6m candle found. Fallback to Limit @ current.`);
      targetPrice = price;
    }

    const pricePrecision = instrumentInfo.pricePrecision;
    targetPrice = parseFloat(targetPrice.toFixed(typeof pricePrecision === 'number' ? pricePrecision : 2));

    orderType = 'LIMIT';
    orderOpts = { price: targetPrice };

  } else {
    // --- Case B: Large Delta (>= 400萬) → Market Strategy ---
    orderType = 'MARKET';
    targetPrice = price;
    strategyNote = `(🔥 Big Signal >= 400w → Immediate Entry)`;
    orderOpts = { type: 'MARKET' };
  }

  // Calculate quantity
  const finalPrice = targetPrice;
  const rawQty = notionalUSD / finalPrice;
  const qtyPrecision = instrumentInfo.quantityPrecision || 3;
  const qty = parseFloat(rawQty.toFixed(qtyPrecision));

  if (qty < instrumentInfo.minQty) {
    log(`⏳ qty ${qty} < minQty ${instrumentInfo.minQty}. Margin: $${marginUSD.toFixed(1)}, Notional: $${notionalUSD.toFixed(0)}. Skipped.`);
    return;
  }

  log(`📈 Delta: ${formatUSD(deltaH)} (${sentiment}) → ${orderType} ${side.toUpperCase()} ${qty} ${CONFIG.INST_ID.replace('USDT', '')} @ ~$${finalPrice} ${strategyNote} (margin: $${marginUSD.toFixed(1)}, notional: ~$${notionalUSD.toFixed(0)})`);

  // Execute or dry-run
  if (CONFIG.DRY_RUN) {
    log(`🔕 [DRY RUN] Would place ${orderType} ${side} ${qty}. Skipping.`);
  } else {
    try {
      const result = await binance.placeOrder(CONFIG.INST_ID, side, qty, orderOpts);
      if (result.orderId) {
        lastTradeTime = Date.now();
        tradeIdleAlertSent = false;

        log(`✅ ${orderType} Order placed! orderId: ${result.orderId} | status: ${result.status}`);
        totalTraded += notionalUSD;
        log(`📊 Session total traded: $${totalTraded.toFixed(0)}`);
      } else {
        const errMsg = `❌ Order Rejected
Symbol: ${CONFIG.INST_ID}
Reason: ${result.msg || JSON.stringify(result)}
Time: ${new Date().toLocaleString()}`;

        log(errMsg);
        await sendTelegram(errMsg).catch(e => log(`❌ Telegram error: ${e.message}`));
      }
    } catch (e) {
      const errMsg = `❌ Order Exception
Symbol: ${CONFIG.INST_ID}
Error: ${e.message}
Time: ${new Date().toLocaleString()}`;

      log(errMsg);
      await sendTelegram(errMsg).catch(e => log(`❌ Telegram error: ${e.message}`));
      return;
    }
  }
}

// ============================================
// Helpers
// ============================================
function formatUSD(v) {
  const abs = Math.abs(v);
  const sign = v >= 0 ? '+' : '';
  if (abs >= 1e8) return `${sign}$${(v / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `${sign}$${(v / 1e4).toFixed(0)}萬`;
  return `${sign}$${v.toFixed(0)}`;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================
// Main Loop
// ============================================
async function main() {
  log(`🚀 Hyper Trading Signal Engine (Binance) starting...`);
  log(`   Worker: ${CONFIG.WORKER_URL}`);
  log(`   Symbol: ${CONFIG.INST_ID}`);
  log(`   Leverage: ${CONFIG.LEVERAGE}x`);
  log(`   Ratio: 1/${(1 / CONFIG.RATIO).toFixed(0)} (margin)`);
  log(`   Min Delta: ${formatUSD(CONFIG.MIN_DELTA)}`);
  log(`   Order Type: Hybrid (≥400w Market, <400w Limit 6m)`);
  log(`   Mode: ${CONFIG.DRY_RUN ? '🔕 DRY RUN' : (CONFIG.BINANCE_TESTNET ? '🧪 TESTNET' : '🔴 LIVE')}`);
  log('');

  if (!CONFIG.BINANCE_API_KEY || !CONFIG.BINANCE_SECRET_KEY) {
    log('❌ Missing Binance API credentials. Check .env file.');
    process.exit(1);
  }

  if (!CONFIG.DRY_RUN) {
    try {
      await binance.setMarginType(CONFIG.INST_ID, 'CROSSED');
      log('✅ Margin type: CROSSED');
    } catch (e) {
      log(`⚠️ Set margin type: ${e.message} (may already be set)`);
    }
  }

  if (!CONFIG.DRY_RUN && !leverageSet) {
    try {
      const result = await binance.setLeverage(CONFIG.INST_ID, CONFIG.LEVERAGE);
      leverageSet = true;
      log(`✅ Leverage set to ${result.leverage}x`);
    } catch (e) {
      log(`⚠️ Set leverage failed: ${e.message}`);
      leverageSet = true;
    }
  }

  try {
    instrumentInfo = await binance.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Symbol: ${CONFIG.INST_ID}, minQty=${instrumentInfo.minQty}, stepSize=${instrumentInfo.stepSize}`);
  } catch (e) {
    log(`⚠️ Get instrument info failed: ${e.message}`);
  }

  if (!CONFIG.DRY_RUN) {
    try {
      const balance = await binance.getBalance();
      log(`💰 Available USDT: $${balance.toFixed(2)}`);
    } catch (e) {
      log(`⚠️ Get balance failed: ${e.message}`);
    }
  }

  log('');

  // Main loop
  let cycle = 0;
  while (true) {
    cycle++;
    const cycleStart = Date.now();

    try {
      const data = await fetchLatest();
      if (data) {
        await processSignal(data);
      }
    } catch (e) {
      log(`❌ Cycle ${cycle} error: ${e.message}`);
    }

    if (CONFIG.ONCE) break;

    const elapsed = Date.now() - cycleStart;
    const remaining = Math.max(1000, CONFIG.POLL_INTERVAL - elapsed);

    // Trade Idle Monitor
    if (!tradeIdleAlertSent && Date.now() - lastTradeTime > TRADE_IDLE_LIMIT) {
      tradeIdleAlertSent = true;
      const msg = `⏳ No Trade Alert
No successful order for 19 minutes.
Symbol: ${CONFIG.INST_ID}
Time: ${new Date().toLocaleString()}`;
      log(msg);
      await sendTelegram(msg).catch(e => log(`❌ Telegram error: ${e.message}`));
    }

    await sleep(remaining);
  }

  log('👋 Signal engine stopped.');
}

// ============================================
// Graceful Shutdown
// ============================================
process.on('SIGINT', () => {
  log(`⚠️ SIGINT — Total traded: $${totalTraded.toFixed(0)}`);
  process.exit(0);
});
process.on('SIGTERM', () => {
  log(`⚠️ SIGTERM — Total traded: $${totalTraded.toFixed(0)}`);
  process.exit(0);
});

main().catch(e => {
  log(`🔴 Fatal: ${e.message}`);
  process.exit(1);
});
