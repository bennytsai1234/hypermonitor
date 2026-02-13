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
  // Use 全體 (ALL) net pressure directly from printer data
  const currentNet = parseFloat(data.net_vol_num) || 0;
  const sentiment = data.sentiment || '';

  // First run: just record, don't trade
  if (previousNet === null) {
    previousNet = currentNet;
    log(`📊 Initial 全體 net: ${formatUSD(currentNet)} (${sentiment})`);
    return;
  }

  // Only trade when 全體 net pressure changes
  if (currentNet === previousNet) return;

  // Calculate delta
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
    // Delta too small, skip
    return;
  }

  // Calculate order value (direct, no accumulation)
  let orderUSD = deltaH * CONFIG.RATIO;

  // Cap maximum order
  if (Math.abs(orderUSD) > CONFIG.MAX_ORDER_USD) {
    const sign = orderUSD > 0 ? 1 : -1;
    orderUSD = sign * CONFIG.MAX_ORDER_USD;
    log(`⚠️ Order capped to $${CONFIG.MAX_ORDER_USD}`);
  }

  log(`📈 Delta: ${formatUSD(deltaH)} → Order: $${orderUSD.toFixed(2)}`);

  // Get price and instrument info
  if (!instrumentInfo) {
    instrumentInfo = await okx.getInstrumentInfo(CONFIG.INST_ID);
    log(`📋 Instrument: ctVal=${instrumentInfo.ctVal}, lotSz=${instrumentInfo.lotSz}, minSz=${instrumentInfo.minSz}`);
  }

  const price = await okx.getPrice(CONFIG.INST_ID);
  const contractValueUSD = instrumentInfo.ctVal * price;  // Value of 1 contract in USD
  const rawSz = Math.abs(orderUSD) / contractValueUSD;
  // Fix floating point: round to lotSz precision (e.g. 0.01)
  const lotDecimals = Math.max(0, -Math.floor(Math.log10(instrumentInfo.lotSz)));
  const sz = parseFloat((Math.floor(rawSz / instrumentInfo.lotSz) * instrumentInfo.lotSz).toFixed(lotDecimals));

  if (sz < instrumentInfo.minSz) {
    log(`⏳ Order $${Math.abs(orderUSD).toFixed(0)} too small for min contract ($${contractValueUSD.toFixed(0)}/ct). Skipped.`);
    return;
  }

  // Determine direction (net mode: buy = increase long / decrease short, sell = opposite)
  const isBuy = orderUSD > 0;
  const side = isBuy ? 'buy' : 'sell';
  const actualUSD = sz * contractValueUSD;

  log(`🎯 Signal: ${side.toUpperCase()} ${sz} contracts @ $${price.toFixed(1)} (~$${actualUSD.toFixed(0)})`);

  // Execute or dry-run
  if (CONFIG.DRY_RUN) {
    log(`🔕 [DRY RUN] Would ${side} ${sz} contracts. Skipping.`);
  } else {
    try {
      const result = await okx.placeOrder(CONFIG.INST_ID, side, '', sz);
      const ordId = result[0]?.ordId || 'unknown';
      const sCode = result[0]?.sCode || '';
      const sMsg = result[0]?.sMsg || '';
      if (sCode !== '0' && sCode !== '') {
        log(`❌ Order rejected: ${sMsg} (sCode: ${sCode})`);
        return;
      }
      log(`✅ Order placed! ordId: ${ordId}`);
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
  log(`   Max Order: $${CONFIG.MAX_ORDER_USD}`);
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
