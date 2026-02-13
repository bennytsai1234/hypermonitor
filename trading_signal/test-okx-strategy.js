const okx = require('./okx-api');
const CONFIG = require('./config');

(async () => {
  console.log('=== Testing OKX 6m K-line Strategy Logic ===');

  try {
    const instId = CONFIG.INST_ID || 'BTC-USDT-SWAP';
    console.log(`Fetching 1m klines for ${instId}...`);
    // OKX limit applies to number of candles
    const klines = await okx.getKlines(instId, '1m', 30);
    console.log(`Fetched ${klines.length} candles.`);

    if (klines.length === 0) {
      console.log('❌ No klines returned.');
      return;
    }

    // Current time
    const now = Date.now();
    // 6 minutes in ms
    const BLOCK_MS = 6 * 60 * 1000;
    // Align to 0, 6, 12, 18 ... minutes
    const currentBlockStart = now - (now % BLOCK_MS);
    const prevBlockStart = currentBlockStart - BLOCK_MS;

    console.log(`Current Time: ${new Date(now).toLocaleString()}`);
    console.log(`Prev 6m Block: ${new Date(prevBlockStart).toLocaleTimeString()} ~ ${new Date(currentBlockStart).toLocaleTimeString()}`);

    // Filter candles for the previous block
    // OKX timestamps are strings, need parseInt
    const targetCandles = klines.filter(k => {
      const ts = parseInt(k[0]);
      return ts >= prevBlockStart && ts < currentBlockStart;
    });

    console.log(`Found ${targetCandles.length} candles in previous block (Expected 6).`);

    if (targetCandles.length > 0) {
      // OKX Candle format: [ts, o, h, l, c, vol, volCcy, volCcyQuote, confirm]
      let blockHigh = -Infinity;
      let blockLow = Infinity;

      // Note: targetCandles might be in reverse chronological order if raw API response is used directly,
      // but for min/max logic order doesn't matter.
      targetCandles.forEach(c => {
        const ts = parseInt(c[0]);
        const t = new Date(ts).toLocaleTimeString();
        const h = parseFloat(c[2]);
        const l = parseFloat(c[3]);
        console.log(`  [${t}] High: ${h}, Low: ${l}`);

        if (h > blockHigh) blockHigh = h;
        if (l < blockLow) blockLow = l;
      });

      console.log(`\n✅ Calculated Targets:`);
      console.log(`  Prev 6m HIGH (Short Target): ${blockHigh}`);
      console.log(`  Prev 6m LOW  (Long Target):  ${blockLow}`);

      // Get current price for comparison
      const currentPrice = await okx.getPrice(instId);
      console.log(`\nCurrent Price: ${currentPrice}`);

      const diffHigh = ((blockHigh - currentPrice) / currentPrice * 100).toFixed(4);
      const diffLow = ((currentPrice - blockLow) / currentPrice * 100).toFixed(4);

      console.log(`  Dist to High: ${diffHigh}%`);
      console.log(`  Dist to Low:  ${diffLow}%`);

    } else {
      console.log('❌ No candles found for the previous block.');
      console.log('Debug Klines (First 3):', klines.slice(0, 3));
    }

  } catch (e) {
    console.error('❌ Error testing strategy:', e);
  }
})();
