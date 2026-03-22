/**
 * Hyper Trading Signal — Configuration
 */
require('dotenv').config({ path: __dirname + '/.env' });

const CONFIG = {
  // Worker API
  WORKER_URL: process.env.WORKER_URL || 'https://hyper-monitor-worker.bennytsai0711.workers.dev',

  // OKX V5 API
  OKX_API_KEY: process.env.OKX_API_KEY || '',
  OKX_SECRET_KEY: process.env.OKX_SECRET_KEY || '',
  OKX_PASSPHRASE: process.env.OKX_PASSPHRASE || '',
  OKX_BASE_URL: 'https://www.okx.com',
  OKX_DEMO: process.env.OKX_DEMO === 'true',

  // Trading Parameters
  SIGNAL_SOURCE: process.env.SIGNAL_SOURCE || 'printer', // Options: 'printer' | 'smart'
  INST_ID: process.env.INST_ID || 'BTC-USDT-SWAP',
  LEVERAGE: parseInt(process.env.LEVERAGE || '10'),
  ORDER_USD: parseFloat(process.env.ORDER_USD || '40'),
  MIN_DELTA: parseFloat(process.env.MIN_DELTA || '4000000'),

  // Polling
  POLL_INTERVAL: parseInt(process.env.POLL_INTERVAL || '10') * 1000,
  DRY_RUN: process.argv.includes('--dry-run'),
  ONCE: process.argv.includes('--once'),

  // Email Notification
  GMAIL_USER: process.env.GMAIL_USER || '',
  GMAIL_APP_PASSWORD: process.env.GMAIL_APP_PASSWORD || '',
};

module.exports = CONFIG;
