/**
 * Binance USDⓈ-M Futures API Wrapper
 *
 * Handles authentication (HMAC-SHA256), market data, and order placement.
 */
const crypto = require('crypto');

let CONFIG;
try { CONFIG = require('./config'); } catch { CONFIG = {}; }

// ============================================
// Signing & Request Helpers
// ============================================

function sign(queryString) {
  return crypto.createHmac('sha256', CONFIG.BINANCE_SECRET_KEY)
    .update(queryString).digest('hex');
}

function getHeaders() {
  return {
    'X-MBX-APIKEY': CONFIG.BINANCE_API_KEY,
    'Content-Type': 'application/x-www-form-urlencoded',
  };
}

async function binanceGet(path, params = {}) {
  params.timestamp = Date.now();
  // Add recvWindow for testnet clock tolerance
  params.recvWindow = 10000;
  const qs = new URLSearchParams(params).toString();
  const signature = sign(qs);
  const url = `${CONFIG.BINANCE_BASE_URL}${path}?${qs}&signature=${signature}`;

  const res = await fetch(url, { headers: getHeaders() });
  const data = await res.json();

  if (data.code && data.code !== 200) {
    throw new Error(`Binance GET ${path} failed: ${data.msg} (code: ${data.code})`);
  }
  return data;
}

async function binancePost(path, params = {}) {
  params.timestamp = Date.now();
  params.recvWindow = 10000;
  const qs = new URLSearchParams(params).toString();
  const signature = sign(qs);
  const body = `${qs}&signature=${signature}`;

  const res = await fetch(`${CONFIG.BINANCE_BASE_URL}${path}`, {
    method: 'POST',
    headers: getHeaders(),
    body,
  });
  const data = await res.json();

  if (data.code && data.code !== 200) {
    throw new Error(`Binance POST ${path} failed: ${data.msg} (code: ${data.code})`);
  }
  return data;
}

// Public endpoint (no auth needed)
async function publicGet(path, params = {}) {
  const qs = new URLSearchParams(params).toString();
  const url = `${CONFIG.BINANCE_BASE_URL}${path}${qs ? '?' + qs : ''}`;
  const res = await fetch(url);
  return res.json();
}

// ============================================
// Market Data
// ============================================

/**
 * Get current price for a symbol
 */
async function getPrice(symbol) {
  const data = await publicGet('/fapi/v1/ticker/price', { symbol });
  return parseFloat(data.price);
}

/**
 * Get instrument info (filters, min qty, step size, etc.)
 */
async function getInstrumentInfo(symbol) {
  const data = await publicGet('/fapi/v1/exchangeInfo');
  const sym = data.symbols.find(s => s.symbol === symbol);
  if (!sym) throw new Error(`Symbol ${symbol} not found`);

  const lotFilter = sym.filters.find(f => f.filterType === 'LOT_SIZE');
  const priceFilter = sym.filters.find(f => f.filterType === 'PRICE_FILTER');
  const minNotional = sym.filters.find(f => f.filterType === 'MIN_NOTIONAL');

  return {
    // Binance futures qty is in BTC directly (not contracts)
    minQty: parseFloat(lotFilter?.minQty || '0.001'),
    stepSize: parseFloat(lotFilter?.stepSize || '0.001'),
    tickSize: parseFloat(priceFilter?.tickSize || '0.1'),
    minNotional: parseFloat(minNotional?.notional || '5'),
    contractType: sym.contractType,
    pricePrecision: sym.pricePrecision,
    tickSize: parseFloat(priceFilter?.tickSize || '0.1'),
    minNotional: parseFloat(minNotional?.notional || '5'),
    contractType: sym.contractType,
    pricePrecision: sym.pricePrecision,
    quantityPrecision: sym.quantityPrecision,
  };
}

/**
 * Get K-line (Candlestick) data
 * @param {string} symbol
 * @param {string} interval - e.g. '1m', '5m', '1h'
 * @param {number} limit - default 50
 */
async function getKlines(symbol, interval, limit = 50) {
  return publicGet('/fapi/v1/klines', { symbol, interval, limit });
}

// ============================================
// Account / Trading
// ============================================

/**
 * Set leverage for a symbol
 */
async function setLeverage(symbol, leverage) {
  return binancePost('/fapi/v1/leverage', { symbol, leverage });
}

/**
 * Set margin type (ISOLATED or CROSSED)
 */
async function setMarginType(symbol, marginType = 'CROSSED') {
  try {
    return await binancePost('/fapi/v1/marginType', { symbol, marginType });
  } catch (e) {
    // -4046 = "No need to change margin type" (already set)
    if (e.message.includes('-4046')) return;
    throw e;
  }
}

/**
 * Place an order
 * @param {string} symbol - e.g. 'BTCUSDT'
 * @param {string} side - 'BUY' or 'SELL'
 * @param {number} quantity - amount in BTC (e.g. 0.001)
 * @param {number} [price] - Optional. If provided, places LIMIT order. If null/undefined, places MARKET order.
 */
async function placeOrder(symbol, side, quantity, price = null) {
  const params = {
    symbol,
    side: side.toUpperCase(),
    quantity: String(quantity),
  };

  if (price) {
    params.type = 'LIMIT';
    params.price = String(price);
    params.timeInForce = 'GTC'; // Good Till Cancel
  } else {
    params.type = 'MARKET';
  }

  return binancePost('/fapi/v1/order', params);
}

/**
 * Get current position for a symbol
 */
async function getPosition(symbol) {
  const positions = await binanceGet('/fapi/v2/positionRisk', { symbol });
  if (!positions || positions.length === 0) return null;
  return positions.find(p => p.symbol === symbol) || positions[0];
}

/**
 * Get account balance
 */
async function getBalance() {
  const data = await binanceGet('/fapi/v2/balance');
  const usdt = data.find(b => b.asset === 'USDT');
  return usdt ? parseFloat(usdt.availableBalance) : 0;
}

module.exports = {
  getPrice,
  getInstrumentInfo,
  setLeverage,
  setMarginType,
  placeOrder,
  getPosition,
  getBalance,
  getKlines,
};
