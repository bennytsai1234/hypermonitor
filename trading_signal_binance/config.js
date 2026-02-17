/**
 * Binance Trading Signal — Configuration
 */
require('dotenv').config();

module.exports = {
  // Worker API
  WORKER_URL: process.env.WORKER_URL || 'https://hyper-monitor-worker.bennytsai0711.workers.dev',

  // Binance API
  BINANCE_API_KEY: process.env.BINANCE_API_KEY || '',
  BINANCE_SECRET_KEY: process.env.BINANCE_SECRET_KEY || '',
  // Production: https://fapi.binance.com
  // Testnet:    https://demo-fapi.binance.com
  BINANCE_BASE_URL: process.env.BINANCE_TESTNET === 'true'
    ? 'https://demo-fapi.binance.com'
    : 'https://fapi.binance.com',
  BINANCE_TESTNET: process.env.BINANCE_TESTNET === 'true',

  // Trading parameters
  SIGNAL_SOURCE: process.env.SIGNAL_SOURCE || 'printer', // Options: 'printer' | 'smart'
  INST_ID: process.env.INST_ID || 'BTCUSDT',
  LEVERAGE: parseInt(process.env.LEVERAGE || '20'),
  // Margin ratio: delta × RATIO = margin amount
  // e.g. 100萬 × 0.00001 = $10 margin → $10 × 20x = $200 notional
  RATIO: parseFloat(process.env.RATIO || '0.00001'),
  MIN_DELTA: parseFloat(process.env.MIN_DELTA || '500000'),
  MAX_ORDER_USD: parseFloat(process.env.MAX_ORDER_USD || '2000'),
  POLL_INTERVAL: parseInt(process.env.POLL_INTERVAL || '10') * 1000,

  // Flags
  DRY_RUN: process.argv.includes('--dry-run'),
  ONCE: process.argv.includes('--once'),
};
