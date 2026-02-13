/**
 * Force switch to net mode: cancel all orders, close all positions, then switch
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

async function okxPost(path, body) {
  const bodyStr = JSON.stringify(body);
  const res = await fetch(CONFIG.OKX_BASE_URL + path, {
    method: 'POST', headers: getHeaders('POST', path, bodyStr), body: bodyStr,
  });
  return res.json();
}

async function okxGet(path) {
  const res = await fetch(CONFIG.OKX_BASE_URL + path, {
    headers: getHeaders('GET', path),
  });
  return res.json();
}

(async () => {
  console.log('=== Force Switch to Net Mode ===\n');

  // 1. Cancel ALL open orders
  console.log('Step 1: Cancel all open orders...');
  const orders = await okxGet(`/api/v5/trade/orders-pending?instId=${CONFIG.INST_ID}`);
  if (orders.data && orders.data.length > 0) {
    for (const o of orders.data) {
      const r = await okxPost('/api/v5/trade/cancel-order', { instId: CONFIG.INST_ID, ordId: o.ordId });
      console.log(`  Cancel ${o.ordId}: ${r.code === '0' ? '✅' : r.msg}`);
    }
  } else {
    console.log('  No open orders. ✅');
  }

  // 2. Close ALL positions (check both long and short)
  console.log('Step 2: Close all positions...');
  const posRes = await okxGet(`/api/v5/account/positions?instId=${CONFIG.INST_ID}`);
  if (posRes.data && posRes.data.length > 0) {
    for (const p of posRes.data) {
      if (parseFloat(p.pos) === 0) continue;
      const closeBody = { instId: CONFIG.INST_ID, mgnMode: 'cross' };
      if (p.posSide && p.posSide !== 'net') closeBody.posSide = p.posSide;
      const r = await okxPost('/api/v5/trade/close-position', closeBody);
      console.log(`  Close ${p.posSide || 'net'} ${p.pos}: ${r.code === '0' ? '✅' : r.msg}`);
    }
  } else {
    console.log('  No positions. ✅');
  }

  // 3. Wait for settlement
  console.log('Step 3: Waiting 3 seconds for settlement...');
  await new Promise(r => setTimeout(r, 3000));

  // 4. Switch to net mode
  console.log('Step 4: Switch to net_mode...');
  const r = await okxPost('/api/v5/account/set-position-mode', { posMode: 'net_mode' });
  if (r.code === '0') {
    console.log('  ✅ SUCCESS! Switched to net_mode');
  } else {
    console.log(`  ❌ Failed: ${r.msg}`);
  }

  console.log('\nDone!');
})();
