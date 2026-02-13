/**
 * Quick test: Place a single BUY LONG 0.01 contract on OKX Demo
 * Usage: node test-order.js
 */
const CONFIG = require('./config');
const okx = require('./okx-api');

(async () => {
  console.log('=== OKX Demo Order Test ===');
  console.log(`Mode: ${CONFIG.OKX_DEMO ? 'DEMO' : 'LIVE'}`);

  // 1. Set position mode
  try {
    const crypto = require('crypto');
    const ts = new Date().toISOString();
    const body = JSON.stringify({ posMode: 'long_short_mode' });
    const sign = crypto.createHmac('sha256', CONFIG.OKX_SECRET_KEY)
      .update(ts + 'POST' + '/api/v5/account/set-position-mode' + body).digest('base64');
    const h = {
      'OK-ACCESS-KEY': CONFIG.OKX_API_KEY, 'OK-ACCESS-SIGN': sign,
      'OK-ACCESS-TIMESTAMP': ts, 'OK-ACCESS-PASSPHRASE': CONFIG.OKX_PASSPHRASE,
      'Content-Type': 'application/json',
    };
    if (CONFIG.OKX_DEMO) h['x-simulated-trading'] = '1';
    const res = await fetch('https://www.okx.com/api/v5/account/set-position-mode', {
      method: 'POST', headers: h, body,
    });
    const data = await res.json();
    console.log('Position mode:', data.code === '0' ? '✅ long_short_mode' : data.msg);
  } catch (e) {
    console.log('Position mode error:', e.message);
  }

  // 2. Set leverage
  try {
    await okx.setLeverage(CONFIG.INST_ID, CONFIG.LEVERAGE);
    console.log(`Leverage: ✅ ${CONFIG.LEVERAGE}x`);
  } catch (e) {
    console.log('Leverage:', e.message);
  }

  // 3. Get price
  const price = await okx.getPrice(CONFIG.INST_ID);
  console.log(`BTC Price: $${price}`);

  // 4. Place order: BUY LONG 0.01 contract (最小單位)
  const sz = 0.01;
  const notional = (sz * 0.01 * price).toFixed(2);
  console.log(`\nPlacing: BUY LONG ${sz} contracts (~$${notional})`);

  try {
    const result = await okx.placeOrder(CONFIG.INST_ID, 'buy', 'long', sz);
    console.log('Result:', JSON.stringify(result, null, 2));
    if (result[0]?.sCode === '0') {
      console.log(`\n✅ SUCCESS! ordId: ${result[0].ordId}`);
    } else {
      console.log(`\n❌ FAILED: ${result[0]?.sMsg} (sCode: ${result[0]?.sCode})`);
    }
  } catch (e) {
    console.log(`\n❌ ERROR: ${e.message}`);
  }
})();
