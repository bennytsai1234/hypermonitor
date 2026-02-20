/**
 * uninstall_service.js
 *
 * Removes the HyperliquidScraper Windows Service.
 * Run this script with Administrator privileges:
 *   node scripts/uninstall_service.js
 *
 * Or use the helper batch file: scripts/uninstall_service.bat
 */

const Service = require('node-windows').Service;
const path = require('path');

const scriptPath = path.resolve(__dirname, '../src/headless_scraper.js');

const svc = new Service({
    name: 'HyperliquidScraper',
    script: scriptPath
});

svc.on('uninstall', () => {
    console.log('✅ Service uninstalled successfully!');
    console.log('   HyperliquidScraper has been removed from Windows Services.');
});

svc.on('notinstalled', () => {
    console.log('⚠️  Service is not currently installed. Nothing to remove.');
});

svc.on('error', (err) => {
    console.error('❌ Uninstall error:', err);
});

console.log('🗑️  Uninstalling HyperliquidScraper Windows Service...');
svc.uninstall();
