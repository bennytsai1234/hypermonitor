const binance = require('./binance-api');

(async () => {
  console.log('=== Testing 6m K-line Strategy Logic ===');

  try {
    const symbol = 'BTCUSDT';
    console.log(`Fetching 1m klines for ${symbol}...`);
    const klines = await binance.getKlines(symbol, '1m', 30); // Fetch a bit more to be safe
    console.log(`Fetched ${klines.length} candles.`);

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
    const targetCandles = klines.filter(k => {
      const openTime = k[0];
      return openTime >= prevBlockStart && openTime < currentBlockStart;
    });

    console.log(`Found ${targetCandles.length} candles in previous block (Expected 6).`);

    if (targetCandles.length > 0) {
      // Basic Candle format: [ openTime, open, high, low, close, volume, ... ]
      let blockHigh = -Infinity;
      let blockLow = Infinity;

      targetCandles.forEach((c, index) => {
        const t = new Date(c[0]).toLocaleTimeString();
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
      const currentPrice = await binance.getPrice(symbol);
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
