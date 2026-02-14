/**
 * Hyper Trading Signal — Main Engine
 *
 * Reads Hyperliquid net pressure delta from Worker API,
 * converts it to OKX BTC-USDT-SWAP orders using linear ratio strategy.
 *
 * Usage:
 *   node signal.js              # Run continuously (live/demo based on .env)
 *   node signal.js --dry-run    # Run continuously, log signals but don't trade
 *   node signal.js --once       # Run once and exit (for testing)
 *   node signal.js --once --dry-run  # Single test run, no trading
 */
const CONFIG = require('./config');
const okx = require('./okx-api');

// ============================================
// State
// ============================================
let previousNet = null;          // Last known net pressure value
let accumulatedOrderUSD = 0;     // Accumulated order value (for when delta is too small for 1 contract)
let instrumentInfo = null;       // Cached instrument info (ctVal, lotSz, etc.)
let leverageSet = false;         // Whether leverage has been configured
let totalTraded = 0;             // Total USD traded this session

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
async function fetchLatest() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    const res = await fetch(`${CONFIG.WORKER_URL}/latest`, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    log(`❌ Fetch latest failed: ${e.message}`);
    return null;
  }
}

// ============================================
// Core Signal Logic
// ============================================
async function processSignal(data) {
  // Use 全體 (ALL) data: long_vol - short_vol = net direction
  const longVol = parseFloat(data.long_vol_num) || 0;
  const shortVol = parseFloat(data.short_vol_num) || 0;
  const currentNet = longVol - shortVol;  // 正=多頭佔優, 負=空頭佔優
  const sentiment = data.sentiment || '';

  // First run: just record, don't trade
  if (previousNet === null) {
    previousNet = currentNet;
    log(`📊 Initial 全體: 多${formatUSD(longVol)} 空${formatUSD(shortVol)} 淨${formatUSD(currentNet)} (${sentiment})`);
    return;
  }

  // Only trade when 全體 net pressure changes
  if (currentNet === previousNet) return;

  // Calculate delta: positive = longs growing more than shorts, negative = shorts growing more
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
    return;
  }

  // Check maximum threshold (User rule: > 8000萬 skip)
  const MAX_DELTA = 80000000;
  if (Math.abs(deltaH) > MAX_DELTA) {
    log(`⚠️ Delta ${formatUSD(deltaH)} > ${formatUSD(MAX_DELTA)} (Too volatile). Skipped.`);
    return;
  }

  // Calculate order value (direct, no accumulation)
  const orderUSD = Math.abs(deltaH) * CONFIG.RATIO;

  // Get price and instrument info
  if (!instrumentInfo) {
    instrumentInfo = await okx.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Instrument: ctVal=${instrumentInfo.ctVal}, lotSz=${instrumentInfo.lotSz}, minSz=${instrumentInfo.minSz}`);
  }

  const price = await okx.getPrice(CONFIG.INST_ID);
  const contractValueUSD = instrumentInfo.ctVal * price;
  const rawSz = orderUSD / contractValueUSD;
  const lotDecimals = Math.max(0, -Math.floor(Math.log10(instrumentInfo.lotSz)));
  const sz = parseFloat((Math.floor(rawSz / instrumentInfo.lotSz) * instrumentInfo.lotSz).toFixed(lotDecimals));

  if (sz < instrumentInfo.minSz) {
    log(`⏳ Order $${orderUSD.toFixed(0)} too small for min contract ($${contractValueUSD.toFixed(0)}/ct). Skipped.`);
    return;
  }

  // Direction: delta > 0 = longs increasing = BUY, delta < 0 = shorts increasing = SELL
  const side = deltaH > 0 ? 'buy' : 'sell';

  // Strategy Thresholds
  const MARKET_THRESHOLD = 5000000; // 500萬
  const absDelta = Math.abs(deltaH);

  let orderType = '';
  let orderOpts = {};
  let targetPrice = 0;
  let strategyNote = '';

  // ============================================
  // Hybrid Strategy
  // < 500萬: Maker (Post Only) via 6m Candle
  // >= 500萬: Market (Immediate)
  // ============================================

  if (absDelta < MARKET_THRESHOLD) {
    // --- Case A: Small Delta (< 500萬) → Maker Strategy ---
    let useCurrentPrice = false;

    try {
      // 1. Fetch recent 1m candles
      const klines = await okx.getKlines(CONFIG.INST_ID, '1m', 15);

      // 2. Aggregate "Previous 6m Candle"
      const now = Date.now();
      const BLOCK_MS = 6 * 60 * 1000;
      const currentBlockStart = now - (now % BLOCK_MS);
      const prevBlockStart = currentBlockStart - BLOCK_MS;

      const targetCandles = klines.filter(k => {
        const ts = parseInt(k[0]);
        return ts >= prevBlockStart && ts < currentBlockStart;
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

        if (side === 'buy') {
          if (price <= blockLow) {
            useCurrentPrice = true;
            targetPrice = price;
            strategyNote = `(Curr ${price} ≤ 6m Low ${blockLow} → Limit@Curr)`;
          } else {
            targetPrice = blockLow;
            strategyNote = `(Maker @ 6m Low ${blockLow})`;
          }
        } else {
          if (price >= blockHigh) {
            useCurrentPrice = true;
            targetPrice = price;
            strategyNote = `(Curr ${price} ≥ 6m High ${blockHigh} → Limit@Curr)`;
          } else {
            targetPrice = blockHigh;
            strategyNote = `(Maker @ 6m High ${blockHigh})`;
          }
        }
        log(`🕯️ Prev 6m Candle [${new Date(prevBlockStart).toLocaleTimeString()}]: High ${blockHigh}, Low ${blockLow}, Curr ${price}`);
      } else {
        log(`⚠️ No complete 6m candle found. Fallback to limit @ current.`);
        useCurrentPrice = true;
        targetPrice = price;
      }
    } catch (e) {
      log(`⚠️ Strategy error: ${e.message}. Fallback to limit @ current.`);
      useCurrentPrice = true;
      targetPrice = price;
    }

    // Configure Maker/Limit Order
    if (useCurrentPrice) {
      orderType = 'LIMIT';
      orderOpts = { price: targetPrice };
    } else {
      orderType = 'LIMIT (Post Only)';
      orderOpts = { price: targetPrice, postOnly: true };
    }

  } else {
    // --- Case B: Large Delta (>= 500萬) → Market Strategy ---
    orderType = 'MARKET';
    targetPrice = price; // For estimation
    strategyNote = `(🔥 Big Signal >= 500w → Immediate Entry)`;
    orderOpts = { type: 'market' };
  }

  const actualUSD = sz * contractValueUSD;

  log(`📈 Delta: ${formatUSD(deltaH)} (${sentiment}) → ${orderType} ${side.toUpperCase()} ${sz} ct @ ~$${targetPrice} ${strategyNote} (~$${actualUSD.toFixed(0)})`);

  // Execute or dry-run
  if (CONFIG.DRY_RUN) {
    log(`🔕 [DRY RUN] Would place MARKET ${side} ${sz} contracts. Skipping.`);
  } else {
    try {
      const result = await okx.placeOrder(CONFIG.INST_ID, side, '', sz, { type: 'market' });
      const ordId = result[0]?.ordId || 'unknown';
      const sCode = result[0]?.sCode || '';
      const sMsg = result[0]?.sMsg || '';
      if (sCode !== '0' && sCode !== '') {
        log(`❌ Order rejected: ${sMsg} (sCode: ${sCode})`);
        return;
      }
      log(`✅ Market order filled! ordId: ${ordId}`);
      totalTraded += actualUSD;
      log(`📊 Session total traded: $${totalTraded.toFixed(0)}`);
    } catch (e) {
      log(`❌ Order failed: ${e.message}`);
      return;
    }
  }

  // Clear accumulated after successful trade (or dry-run)
  accumulatedOrderUSD = 0;
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
  log('🚀 Hyper Trading Signal Engine starting...');
  log(`   Worker: ${CONFIG.WORKER_URL}`);
  log(`   Instrument: ${CONFIG.INST_ID}`);
  log(`   Leverage: ${CONFIG.LEVERAGE}x`);
  log(`   Ratio: 1/${(1 / CONFIG.RATIO).toFixed(0)} (${formatUSD(1 / CONFIG.RATIO)} delta → $1 order)`);
  log(`   Min Delta: ${formatUSD(CONFIG.MIN_DELTA)}`);
  log(`   Order Type: Hybird (≥500w Market, <500w Maker 6m)`);
  log(`   Mode: ${CONFIG.DRY_RUN ? '🔕 DRY RUN' : (CONFIG.OKX_DEMO ? '🧪 DEMO' : '🔴 LIVE')}`);
  log('');

  // Validate credentials
  if (!CONFIG.OKX_API_KEY || !CONFIG.OKX_SECRET_KEY || !CONFIG.OKX_PASSPHRASE) {
    log('❌ Missing OKX API credentials. Check .env file.');
    process.exit(1);
  }

  // Set leverage (once)
  if (!CONFIG.DRY_RUN && !leverageSet) {
    try {
      await okx.setLeverage(CONFIG.INST_ID, CONFIG.LEVERAGE);
      leverageSet = true;
      log(`✅ Leverage set to ${CONFIG.LEVERAGE}x`);
    } catch (e) {
      log(`⚠️ Set leverage failed: ${e.message} (may already be set)`);
      leverageSet = true; // Don't retry
    }
  }

  // Get instrument info
  try {
    instrumentInfo = await okx.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Contract: 1ct = ${instrumentInfo.ctVal} BTC, minSz = ${instrumentInfo.minSz}, lotSz = ${instrumentInfo.lotSz}`);
  } catch (e) {
    log(`⚠️ Get instrument info failed: ${e.message}`);
  }

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

    // Smart sleep
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
