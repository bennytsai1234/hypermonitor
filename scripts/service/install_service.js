/**
 * install_service.js
 *
 * Installs the Hyperliquid Headless Scraper as a Windows Service.
 * Run this script ONCE with Administrator privileges:
 *   node scripts/install_service.js
 *
 * Or use the helper batch file: scripts/install_service.bat
 */

const Service = require('node-windows').Service;
const path = require('path');

const scriptPath = path.resolve(__dirname, '../src/headless_scraper.js');

const svc = new Service({
    name: 'HyperliquidScraper',
    description: 'Hyperliquid CoinGlass Headless Scraper — auto-uploads market data every 10s.',
    script: scriptPath,

    // Optional: environment variables for the service
    // env: [
    //   { name: 'CHROME_PATH', value: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe' },
    //   { name: 'PRINTER_ENDPOINT', value: 'https://...' },
    // ],

    // Auto-restart settings
    wait: 2,      // Wait 2 seconds before restarting
    grow: 0.25,   // Grow wait time by 25% each restart (backoff)
    maxRestarts: 5 // Give up after 5 consecutive restarts in a short period
});

svc.on('install', () => {
    console.log('✅ Service installed successfully!');
    svc.start();
    console.log('🚀 Service started. You can now manage it via services.msc');
    console.log('   Service Name: HyperliquidScraper');
});

svc.on('alreadyinstalled', () => {
    console.log('⚠️  Service is already installed. Start it from services.msc');
    console.log('   Or run: node scripts/uninstall_service.js first.');
});

svc.on('error', (err) => {
    console.error('❌ Installation error:', err);
});

console.log('📦 Installing HyperliquidScraper as Windows Service...');
console.log(`   Script: ${scriptPath}`);
svc.install();
