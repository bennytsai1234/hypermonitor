/**
 * OKX V5 REST API Wrapper
 * Handles HMAC-SHA256 signing, price queries, leverage, and order placement.
 */
const crypto = require('crypto');
const CONFIG = require('./config');

// ============================================
// HMAC-SHA256 Signing (OKX V5 Standard)
// ============================================
function sign(timestamp, method, requestPath, body = '') {
  const prehash = timestamp + method.toUpperCase() + requestPath + body;
  return crypto
    .createHmac('sha256', CONFIG.OKX_SECRET_KEY)
    .update(prehash)
    .digest('base64');
}

function getHeaders(method, requestPath, body = '') {
  const timestamp = new Date().toISOString();
  const signature = sign(timestamp, method, requestPath, body);

  const headers = {
    'OK-ACCESS-KEY': CONFIG.OKX_API_KEY,
    'OK-ACCESS-SIGN': signature,
    'OK-ACCESS-TIMESTAMP': timestamp,
    'OK-ACCESS-PASSPHRASE': CONFIG.OKX_PASSPHRASE,
    'Content-Type': 'application/json',
  };

  // Demo trading mode
  if (CONFIG.OKX_DEMO) {
    headers['x-simulated-trading'] = '1';
  }

  return headers;
}

// ============================================
// Generic HTTP Requests
// ============================================
async function okxGet(path) {
  const url = CONFIG.OKX_BASE_URL + path;
  const headers = getHeaders('GET', path);

  const res = await fetch(url, { headers });
  const data = await res.json();

  if (data.code !== '0') {
    throw new Error(`OKX GET ${path} failed: ${data.msg} (code: ${data.code})`);
  }
  return data.data;
}

async function okxPost(path, body) {
  const url = CONFIG.OKX_BASE_URL + path;
  const bodyStr = JSON.stringify(body);
  const headers = getHeaders('POST', path, bodyStr);

  const res = await fetch(url, { method: 'POST', headers, body: bodyStr });
  const data = await res.json();

  if (data.code !== '0') {
    // Log detailed error info
    const detail = data.data ? JSON.stringify(data.data) : '';
    throw new Error(`OKX POST ${path} failed: ${data.msg} (code: ${data.code}) ${detail}`);
  }
  return data.data;
}

// ============================================
// Market Data
// ============================================

/** Get current BTC price */
async function getPrice(instId) {
  const path = `/api/v5/market/ticker?instId=${instId}`;
  const data = await okxGet(path);
  if (!data || data.length === 0) throw new Error('No ticker data');
  return parseFloat(data[0].last);
}

/** Get instrument info (contract size, min lot, etc.) */
async function getInstrumentInfo(instId) {
  const path = `/api/v5/public/instruments?instType=SWAP&instId=${instId}`;
  const data = await okxGet(path);
  if (!data || data.length === 0) throw new Error('No instrument data');
  const inst = data[0];
  return {
    ctVal: parseFloat(inst.ctVal),     // Contract value (0.01 BTC for BTC-USDT-SWAP)
    lotSz: parseFloat(inst.lotSz),     // Minimum order increment
    minSz: parseFloat(inst.minSz),     // Minimum order size
    tickSz: parseFloat(inst.tickSz),   // Price tick size
    ctMult: parseFloat(inst.ctMult || '1'),
  };
}

/** Get candles (K-lines) */
async function getKlines(instId, bar = '1m', limit = 50) {
  const path = `/api/v5/market/candles?instId=${instId}&bar=${bar}&limit=${limit}`;
  const data = await okxGet(path);
  if (!data) return [];
  // OKX Candle format: [ts, o, h, l, c, vol, volCcy]
  return data;
}

// ============================================
// Account & Position
// ============================================

/** Get current position for instrument */
async function getPosition(instId) {
  const path = `/api/v5/account/positions?instId=${instId}`;
  const data = await okxGet(path);
  if (!data || data.length === 0) return null;  // No position
  return {
    pos: parseFloat(data[0].pos),           // Contract count (+ for long, - for short)
    avgPx: parseFloat(data[0].avgPx),       // Average entry price
    upl: parseFloat(data[0].upl),           // Unrealized P&L
    lever: data[0].lever,                    // Current leverage
    mgnMode: data[0].mgnMode,               // Margin mode
  };
}

/** Set leverage */
async function setLeverage(instId, lever, mgnMode = 'cross') {
  const path = '/api/v5/account/set-leverage';
  return okxPost(path, {
    instId,
    lever: String(lever),
    mgnMode,
  });
}

// ============================================
// Order Placement
// ============================================

/**
 * Place a market order
 * @param {string} instId - e.g. 'BTC-USDT-SWAP'
 * @param {string} side - 'buy' or 'sell'
 * @param {string} posSide - 'long' or 'short'
 * @param {string} sz - Number of contracts (string)
 */
/**
 * Place an order
 * @param {string} instId - e.g. 'BTC-USDT-SWAP'
 * @param {string} side - 'buy' or 'sell'
 * @param {string} posSide - 'long' or 'short'
 * @param {string} sz - Number of contracts (string)
 * @param {string} [px] - Optional price for Limit Order
 */
async function placeOrder(instId, side, posSide, sz, px = null) {
  const path = '/api/v5/trade/order';
  const body = {
    instId,
    tdMode: 'cross',     // Cross margin
    side,                 // buy / sell
    sz: String(sz),
  };

  if (px) {
    body.ordType = 'limit';
    body.px = String(px);
  } else {
    body.ordType = 'market';
  }

  // Only include posSide for hedge mode (if needed, though typically net mode is default for simple bots)
  if (posSide) body.posSide = posSide;

  return okxPost(path, body);
}

module.exports = {
  getPrice,
  getInstrumentInfo,
  getPosition,
  setLeverage,
  placeOrder,
  getKlines,
};
