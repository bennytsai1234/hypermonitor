/**
 * Close all positions and switch to net mode
 * Usage: node switch-net-mode.js
 */
const CONFIG = require('./config');
const okx = require('./okx-api');
const crypto = require('crypto');

function getHeaders(method, path, body = '') {
  const ts = new Date().toISOString();
  const sign = crypto.createHmac('sha256', CONFIG.OKX_SECRET_KEY)
    .update(ts + method + path + body).digest('base64');
  const h = {
    'OK-ACCESS-KEY': CONFIG.OKX_API_KEY, 'OK-ACCESS-SIGN': sign,
    'OK-ACCESS-TIMESTAMP': ts, 'OK-ACCESS-PASSPHRASE': CONFIG.OKX_PASSPHRASE,
    'Content-Type': 'application/json',
  };
  if (CONFIG.OKX_DEMO) h['x-simulated-trading'] = '1';
  return h;
}

(async () => {
  console.log('=== Switch to Net Mode ===\n');

  // 1. Check current position
  const pos = await okx.getPosition(CONFIG.INST_ID);
  if (pos && pos.pos !== 0) {
    console.log(`Current position: ${pos.pos} contracts, uPnL: $${pos.upl}`);

    // Close position
    const closePath = '/api/v5/trade/close-position';
    const closeBody = JSON.stringify({
      instId: CONFIG.INST_ID,
      mgnMode: 'cross',
      posSide: pos.pos > 0 ? 'long' : 'short',
    });
    const res = await fetch(CONFIG.OKX_BASE_URL + closePath, {
      method: 'POST',
      headers: getHeaders('POST', closePath, closeBody),
      body: closeBody,
    });
    const data = await res.json();
    if (data.code === '0') {
      console.log('✅ Position closed!');
    } else {
      console.log(`❌ Close failed: ${data.msg}`, data.data);
      return;
    }
  } else {
    console.log('No open position. ✅');
  }

  // Wait a moment for settlement
  await new Promise(r => setTimeout(r, 1000));

  // 2. Switch to net mode
  const modePath = '/api/v5/account/set-position-mode';
  const modeBody = JSON.stringify({ posMode: 'net_mode' });
  const res2 = await fetch(CONFIG.OKX_BASE_URL + modePath, {
    method: 'POST',
    headers: getHeaders('POST', modePath, modeBody),
    body: modeBody,
  });
  const data2 = await res2.json();
  if (data2.code === '0') {
    console.log('✅ Switched to net_mode!');
  } else {
    console.log(`❌ Switch failed: ${data2.msg}`, data2.data);
  }

  console.log('\nDone! You can now run: node signal.js');
})();
