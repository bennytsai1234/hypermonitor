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

// ============================================
// State
// ============================================
let previousNet = null;
let instrumentInfo = null;
let leverageSet = false;
let totalTraded = 0;

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

  // Calculate delta
  const deltaH = currentNet - previousNet;
  previousNet = currentNet;

  // Check minimum threshold
  if (Math.abs(deltaH) < CONFIG.MIN_DELTA) {
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
      // 1. Fetch recent 1m candles (enough to cover last 12 mins)
      const klines = await binance.getKlines(CONFIG.INST_ID, '1m', 15);

      // 2. Aggregate to find "Previous 6m Candle"
      // Valid 6m blocks start at :00, :06, :12 ...
      const now = Date.now();
      const BLOCK_MS = 6 * 60 * 1000;
      const currentBlockStart = now - (now % BLOCK_MS);
      const prevBlockStart = currentBlockStart - BLOCK_MS;

      // Filter candles that belong to the previous completed 6m block
      const targetCandles = klines.filter(k => {
        const openTime = k[0];
        return openTime >= prevBlockStart && openTime < currentBlockStart;
      });

      if (targetCandles.length > 0) {
        // Find High and Low of this 6m block
        // Candle format: [ openTime, open, high, low, close, ... ]
        let blockHigh = -Infinity;
        let blockLow = Infinity;

        for (const c of targetCandles) {
          const h = parseFloat(c[2]);
          const l = parseFloat(c[3]);
          if (h > blockHigh) blockHigh = h;
          if (l < blockLow) blockLow = l;
        }

        if (side === 'BUY') {
          if (price <= blockLow) {
            // Price already dropped below 6m Low → better for buyer → Limit at current price
            useCurrentPrice = true;
            targetPrice = price;
            strategyNote = `(Curr ${price} ≤ 6m Low ${blockLow} → Limit@Curr)`;
          } else {
            // Price still above 6m Low → Maker at 6m Low for better entry
            targetPrice = blockLow;
            strategyNote = `(Maker @ 6m Low ${blockLow})`;
          }
        } else {
          if (price >= blockHigh) {
            // Price already spiked above 6m High → better for seller → Limit at current price
            useCurrentPrice = true;
            targetPrice = price;
            strategyNote = `(Curr ${price} ≥ 6m High ${blockHigh} → Limit@Curr)`;
          } else {
            // Price still below 6m High → Maker at 6m High for better entry
            targetPrice = blockHigh;
            strategyNote = `(Maker @ 6m High ${blockHigh})`;
          }
        }

        log(`🕯️ Prev 6m Candle [${new Date(prevBlockStart).toLocaleTimeString()}]: High ${blockHigh}, Low ${blockLow}, Curr ${price}`);

      } else {
        log(`⚠️ Could not find complete previous 6m candle data. Using current price.`);
        useCurrentPrice = true;
        targetPrice = price;
      }

    } catch (e) {
      log(`⚠️ Strategy error: ${e.message}. Using current price.`);
      useCurrentPrice = true;
      targetPrice = price;
    }

    // Configure Maker/Limit Order
    // Calculate Order Price (Apply precision)
    const pricePrecision = instrumentInfo.pricePrecision;
    targetPrice = parseFloat(targetPrice.toFixed(typeof pricePrecision === 'number' ? pricePrecision : 2));

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
    orderOpts = { type: 'MARKET' };
  }

  // Calculate quantity in BTC
  // Note: For market orders, execution price might vary, but we define quantity based on current estimation
  const pricePrecision = instrumentInfo.pricePrecision;
  const finalPrice = parseFloat(targetPrice.toFixed(typeof pricePrecision === 'number' ? pricePrecision : 2));

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
  log(`   Order Type: Hybird (≥500w Market, <500w Maker 6m)`);
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
