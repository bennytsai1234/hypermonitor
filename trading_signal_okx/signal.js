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
const nodemailer = require('nodemailer');

// ============================================
// State
// ============================================
let previousNet = null;          // Last known net pressure value
let accumulatedOrderUSD = 0;     // Accumulated order value (for when delta is too small for 1 contract)
let instrumentInfo = null;       // Cached instrument info (ctVal, lotSz, etc.)
let leverageSet = false;         // Whether leverage has been configured
let totalTraded = 0;             // Total USD traded this session
let lastEmailTime = 0;           // Throttle email sending

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

  // Throttle to avoid spamming (e.g., max 1 email per minute per type?)
  // For critical alerts like > 20M, maybe we want every occurrence.
  // But let's add a small throttle just in case.
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
    subject: `🚨 Hyper Alert: ${subject}`,
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
    // If request failed entirely, maybe return cached data if fresh enough?
    // For now, log error and return null to be safe.
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

  // Calculate delta: positive = longs growing more than shorts, negative = shorts growing more
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  const NOTIFY_THRESHOLD = 20000000; // 2000萬
  if (Math.abs(deltaH) > NOTIFY_THRESHOLD) {
    const msg = `Market Pressure Delta > 2000萬!\nValue: ${formatUSD(deltaH)}\nTime: ${new Date().toLocaleString()}\nSentiment: ${sentiment}`;
    // Run in background so trading is not blocked
    sendEmail('Significant Market Move', msg).catch(console.error);
  }

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
    return;
  }

  // Check maximum threshold (Updated to 4000萬)
  const MAX_DELTA = 40000000;
  if (Math.abs(deltaH) > MAX_DELTA) {
    log(`⚠️ Delta ${formatUSD(deltaH)} > ${formatUSD(MAX_DELTA)} (Skip Trade).`);
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

  // 逆勢操作 (Reverse Trading): 大戶做多 (delta > 0) -> 我們做空 (sell)；大戶做空 (delta < 0) -> 我們做多 (buy)
  const side = deltaH > 0 ? 'sell' : 'buy';

  let orderType = 'MARKET';
  let orderOpts = { type: 'market' }; // API uses lowercase 'market' for OKX
  let targetPrice = price; // For estimation
  let strategyNote = `(🔥 Immediate Market Entry)`;

  const actualUSD = sz * contractValueUSD;

  log(`📈 Delta: ${formatUSD(deltaH)} (${sentiment}) → ${orderType} ${side.toUpperCase()} ${sz} ct @ ~$${targetPrice} ${strategyNote} (~$${actualUSD.toFixed(0)})`);

  // Execute or dry-run
  if (CONFIG.DRY_RUN) {
    log(`🔕 [DRY RUN] Would place MARKET ${side} ${sz} contracts. Skipping.`);
  } else {
    try {
      const result = await okx.placeOrder(CONFIG.INST_ID, side, '', sz, orderOpts);
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
  log(`   Source: ${CONFIG.SIGNAL_SOURCE || 'printer'}`);
  log(`   Instrument: ${CONFIG.INST_ID}`);
  log(`   Leverage: ${CONFIG.LEVERAGE}x`);
  log(`   Ratio: 1/${(1 / CONFIG.RATIO).toFixed(0)} (${formatUSD(1 / CONFIG.RATIO)} delta → $1 order)`);
  log(`   Min Delta: ${formatUSD(CONFIG.MIN_DELTA)}`);
  log(`   Order Type: Hybrid (≥400w Market, <400w Limit 6m)`);
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
