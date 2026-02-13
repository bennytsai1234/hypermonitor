/**
 * Quick test: Place a single BUY 0.001 BTC on Binance Testnet
 */
const CONFIG = require('./config');
const binance = require('./binance-api');

(async () => {
  console.log('=== Binance Testnet Order Test ===');
  console.log(`Mode: ${CONFIG.BINANCE_TESTNET ? 'TESTNET' : 'LIVE'}`);
  console.log(`URL: ${CONFIG.BINANCE_BASE_URL}`);

  // 1. Set margin type
  try {
    await binance.setMarginType('BTCUSDT', 'CROSSED');
    console.log('Margin: ✅ CROSSED');
  } catch (e) {
    console.log('Margin:', e.message);
  }

  // 2. Set leverage
  try {
    const r = await binance.setLeverage('BTCUSDT', 20);
    console.log(`Leverage: ✅ ${r.leverage}x`);
  } catch (e) {
    console.log('Leverage:', e.message);
  }

  // 3. Get balance
  try {
    const bal = await binance.getBalance();
    console.log(`Balance: $${bal.toFixed(2)} USDT`);
  } catch (e) {
    console.log('Balance:', e.message);
  }

  // 4. Get price and instrument info
  const price = await binance.getPrice('BTCUSDT');
  const info = await binance.getInstrumentInfo('BTCUSDT');
  console.log(`BTC Price: $${price}`);

  // 5. Place LIMIT order: BUY 0.002 BTC
  const qty = 0.002;
  // Calculate price with precision
  const pricePrecision = info.pricePrecision || 2;
  const limitPrice = parseFloat(price.toFixed(pricePrecision));

  const notional = (qty * limitPrice).toFixed(2);
  console.log(`\nPlacing: LIMIT BUY ${qty} BTC @ $${limitPrice} (~$${notional})`);

  try {
    // Pass limitPrice to enable Limit Order
    const result = await binance.placeOrder('BTCUSDT', 'BUY', qty, limitPrice);
    console.log('Result:', JSON.stringify(result, null, 2));
    if (result.orderId) {
      console.log(`\n✅ SUCCESS! orderId: ${result.orderId} (Status: ${result.status})`);
    } else {
      console.log(`\n❌ FAILED: ${result.msg}`);
    }
  } catch (e) {
    console.log(`\n❌ ERROR: ${e.message}`);
  }
})();
