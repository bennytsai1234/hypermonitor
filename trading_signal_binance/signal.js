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
const nodemailer = require('nodemailer');

// ============================================
// State
// ============================================
let previousNet = null;
let instrumentInfo = null;
let leverageSet = false;
let totalTraded = 0;
let lastEmailTime = 0;

// ============================================
// Logging
// ============================================
function log(msg) {
  const now = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false });
  console.log(`[${now}] ${msg}`);
}

// ============================================
// Email Notification
// ============================================
async function sendEmail(subject, text) {
  if (!CONFIG.GMAIL_USER || !CONFIG.GMAIL_APP_PASSWORD) return;

  if (Date.now() - lastEmailTime < 60000) {
    log('⚠️ Email alert throttled (max 1 per minute).');
    return;
  }

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: CONFIG.GMAIL_USER,
      pass: CONFIG.GMAIL_APP_PASSWORD,
    },
  });

  const mailOptions = {
    from: CONFIG.GMAIL_USER,
    to: 'bennytsai0711@gmail.com',
    subject: `🚨 Hyper Alert (Binance): ${subject}`,
    text: text,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    log(`📧 Email sent: ${info.response}`);
    lastEmailTime = Date.now();
  } catch (error) {
    log(`❌ Email failed: ${error.message}`);
  }
}

// ============================================
// Fetch Latest Data from Worker
// ============================================
// ============================================
// Fetch Latest Data from Worker (Optimized with ETag)
// ============================================
let cachedEtag = null;
let cachedData = null;

async function fetchLatest() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 2000); // Faster timeout (2s)

    const headers = {};
    if (cachedEtag) headers['If-None-Match'] = cachedEtag;

    const res = await fetch(`${CONFIG.WORKER_URL}/latest`, {
      signal: controller.signal,
      headers: headers
    });
    clearTimeout(timeoutId);

    // 304: Data unchanged, use cache
    if (res.status === 304) {
      if (cachedData) return cachedData; // Return cached object
    }

    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    // 200: New data
    const data = await res.json();

    // Update cache
    const newEtag = res.headers.get('ETag');
    if (newEtag) cachedEtag = newEtag;
    cachedData = data;

    return data;
  } catch (e) {
    if (e.name === 'AbortError') log(`⏱️ Fetch timeout (2s)`);
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

  const currentNet = longVol - shortVol;  // 正=多頭佔優, 負=空頭佔優

  // --- DATA ANOMALY GUARD ---
  // If the fetched volume is suspiciously low (e.g. 0), it means the scraping failed
  // or Coinglass didn't render it properly. We must ignore this tick to prevent
  // artificial huge delta spikes when it recovers.
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

  // Only trade when 全體 net pressure changes
  if (currentNet === previousNet) return;

  // Calculate delta
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  const NOTIFY_THRESHOLD = 20000000; // 2000萬
  if (Math.abs(deltaH) > NOTIFY_THRESHOLD) {
    const msg = `Market Pressure Delta > 2000萬!\nValue: ${formatUSD(deltaH)}\nExchange: Binance\nTime: ${new Date().toLocaleString()}\nSentiment: ${sentiment}`;
    // Run in background
    sendEmail('Significant Market Move', msg).catch(console.error);
  }

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
    return;
  }

  // Check maximum threshold (User rule: > 4000萬 skip)
  const MAX_DELTA = 40000000;
  if (Math.abs(deltaH) > MAX_DELTA) {
    log(`⚠️ Delta ${formatUSD(deltaH)} > ${formatUSD(MAX_DELTA)} (Too volatile). Skipped.`);
    return;
  }

  // Calculate order:
  // Step 1: margin = |delta| × RATIO   (e.g. 100萬 × 0.00001 = $10 margin)
  // Step 2: notional = margin × LEVERAGE  (e.g. $10 × 20 = $200 position)
  const marginUSD = Math.abs(deltaH) * CONFIG.RATIO;
  const notionalUSD = marginUSD * CONFIG.LEVERAGE;

  // Get instrument info if not available
  if (!instrumentInfo) {
    instrumentInfo = await binance.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Instrument: minQty=${instrumentInfo.minQty}, stepSize=${instrumentInfo.stepSize}, qtyPrecision=${instrumentInfo.quantityPrecision}`);
  }

  const price = await binance.getPrice(CONFIG.INST_ID);

  // Direction: delta > 0 = longs increasing = BUY, delta < 0 = shorts increasing = SELL
  const side = deltaH > 0 ? 'BUY' : 'SELL';

  // Strategy Thresholds
  const MARKET_THRESHOLD = 4000000; // 400萬
  const absDelta = Math.abs(deltaH);

  let orderType = '';
  let orderOpts = {};
  let targetPrice = 0;
  let strategyNote = '';


  // ============================================
  // Hybrid Strategy
  // < 400萬: Limit via 6m Candle
  // >= 400萬: Market (Immediate)
  // ============================================



  if (absDelta < MARKET_THRESHOLD) {
    // --- Case A: Small Delta (< 400萬) → Limit Strategy (6m Candle Price) ---

    // 1. Fetch recent 1m candles
    let klines = [];
    try {
      klines = await binance.getKlines(CONFIG.INST_ID, '1m', 15);
    } catch (e) {
      log(`⚠️ Fetch klines failed: ${e.message}`);
    }

    // 2. Aggregate "Previous 6m Candle"
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
        // Buy: Limit at Lower of (Current, 6m Low)
        if (price < blockLow) {
          targetPrice = price;
          strategyNote = `(Curr ${price} < 6m Low ${blockLow} → Limit@Curr)`;
        } else {
          targetPrice = blockLow;
          strategyNote = `(Limit @ 6m Low ${blockLow})`;
        }
      } else {
        // Sell: Limit at Higher of (Current, 6m High)
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

    // Calculate Order Price (Apply precision)
    const pricePrecision = instrumentInfo.pricePrecision;
    targetPrice = parseFloat(targetPrice.toFixed(typeof pricePrecision === 'number' ? pricePrecision : 2));

    // Strategy A: Standard Limit Order (Not Post-Only)
    orderType = 'LIMIT';
    orderOpts = { price: targetPrice }; // Removed postOnly: true

  } else {
    // --- Case B: Large Delta (>= 400萬) → Market Strategy ---
    orderType = 'MARKET';
    targetPrice = price; // For estimation
    strategyNote = `(🔥 Big Signal >= 400w → Immediate Entry)`;
    orderOpts = { type: 'MARKET' };
  }

  // Calculate quantity in BTC
  const finalPrice = targetPrice;

  const rawQty = notionalUSD / finalPrice;
  const qtyPrecision = instrumentInfo.quantityPrecision || 3;
  const qty = parseFloat(rawQty.toFixed(qtyPrecision));

  if (qty < instrumentInfo.minQty) {
    log(`⏳ qty ${qty} < minQty ${instrumentInfo.minQty}. Margin: $${marginUSD.toFixed(1)}, Notional: $${notionalUSD.toFixed(0)}. Skipped.`);
    return;
  }

  log(`📈 Delta: ${formatUSD(deltaH)} (${sentiment}) → ${orderType} ${side.toUpperCase()} ${qty} BTC @ ~$${finalPrice} ${strategyNote} (margin: $${marginUSD.toFixed(1)}, notional: ~$${notionalUSD.toFixed(0)})`);

  // Execute or dry-run
  if (CONFIG.DRY_RUN) {
    log(`🔕 [DRY RUN] Would place ${orderType} ${side} ${qty} BTC. Skipping.`);
  } else {
    try {
      const result = await binance.placeOrder(CONFIG.INST_ID, side, qty, orderOpts);
      if (result.orderId) {
        log(`✅ ${orderType} Order placed! orderId: ${result.orderId} | status: ${result.status}`);
        totalTraded += notionalUSD;
        log(`📊 Session total traded: $${totalTraded.toFixed(0)}`);
      } else {
        log(`❌ Order rejected: ${result.msg || JSON.stringify(result)}`);
      }
    } catch (e) {
      log(`❌ Order failed: ${e.message}`);
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
  log('🚀 Hyper Trading Signal Engine (Binance) starting...');
  log(`   Worker: ${CONFIG.WORKER_URL}`);
  log(`   Symbol: ${CONFIG.INST_ID}`);
  log(`   Leverage: ${CONFIG.LEVERAGE}x`);
  log(`   Ratio: 1/${(1 / CONFIG.RATIO).toFixed(0)} (margin)`);
  log(`   Formula: margin = delta × ${CONFIG.RATIO}, position = margin × ${CONFIG.LEVERAGE}x`);
  log(`   Example: 100萬 delta → $${(1000000 * CONFIG.RATIO).toFixed(0)} margin → $${(1000000 * CONFIG.RATIO * CONFIG.LEVERAGE).toFixed(0)} position`);
  log(`   Min Delta: ${formatUSD(CONFIG.MIN_DELTA)}`);
  log(`   Order Type: Hybrid (≥400w Market, <400w Limit 6m)`);
  log(`   Mode: ${CONFIG.DRY_RUN ? '🔕 DRY RUN' : (CONFIG.BINANCE_TESTNET ? '🧪 TESTNET' : '🔴 LIVE')}`);
  log('');

  // Validate credentials
  if (!CONFIG.BINANCE_API_KEY || !CONFIG.BINANCE_SECRET_KEY) {
    log('❌ Missing Binance API credentials. Check .env file.');
    process.exit(1);
  }

  // Set margin type to CROSSED
  if (!CONFIG.DRY_RUN) {
    try {
      await binance.setMarginType(CONFIG.INST_ID, 'CROSSED');
      log('✅ Margin type: CROSSED');
    } catch (e) {
      log(`⚠️ Set margin type: ${e.message} (may already be set)`);
    }
  }

  // Set leverage
  if (!CONFIG.DRY_RUN && !leverageSet) {
    try {
      const result = await binance.setLeverage(CONFIG.INST_ID, CONFIG.LEVERAGE);
      leverageSet = true;
      log(`✅ Leverage set to ${result.leverage}x (maxNotionalValue: ${result.maxNotionalValue})`);
    } catch (e) {
      log(`⚠️ Set leverage failed: ${e.message}`);
      leverageSet = true;
    }
  }

  // Get instrument info
  try {
    instrumentInfo = await binance.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Symbol: ${CONFIG.INST_ID}, minQty=${instrumentInfo.minQty}, stepSize=${instrumentInfo.stepSize}`);
  } catch (e) {
    log(`⚠️ Get instrument info failed: ${e.message}`);
  }

  // Show balance
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
