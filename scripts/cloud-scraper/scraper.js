/**
 * Hyper Monitor — Cloud Scraper
 *
 * Replaces the Flutter App's WebView scraping with a headless Puppeteer browser.
 * Runs on any Linux server (e.g. Oracle Cloud Free VPS).
 *
 * Usage:
 *   node scraper.js          # Run continuously (every 10 seconds)
 *   node scraper.js --once   # Run once and exit (for testing)
 *
 * Environment Variables:
 *   API_URL   - Worker API base URL (default: https://hyper-monitor-worker.bennytsai0711.workers.dev)
 *   API_KEY   - Optional API key for authentication
 *   INTERVAL  - Scrape interval in seconds (default: 10)
 */

const puppeteer = require('puppeteer');

// ============================================
// Configuration
// ============================================
const CONFIG = {
  API_URL: process.env.API_URL || 'https://hyper-monitor-worker.bennytsai0711.workers.dev',
  API_KEY: process.env.API_KEY || '',
  INTERVAL: parseInt(process.env.INTERVAL || '10') * 1000,
  ONCE: process.argv.includes('--once'),

  URLS: {
    printer: 'https://www.coinglass.com/zh/hl',
    range: 'https://www.coinglass.com/zh/hl/range/9',
  },

  // Wait for page data to load (milliseconds)
  PAGE_LOAD_WAIT: 5000,
  // Wait after reload for data to refresh
  RELOAD_WAIT: 3000,
};

// ============================================
// Scrape JavaScript (same logic as Flutter)
// ============================================
const PRINTER_JS = `
  (function() {
    const rows = document.querySelectorAll('tr');
    for (const row of rows) {
      const text = row.innerText;
      if (text.includes('超级印钞機') || text.includes('超級印鈔機') || text.includes('超级印钞机')) {
        const cells = row.querySelectorAll('td');
        if (cells.length < 8) continue;
        const volDivs = cells[4].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
        const plDivs = cells[7].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
        const sentimentBtn = row.querySelector('button.tag-but');
        return JSON.stringify({
          found: true,
          walletCount: cells[2].innerText.trim(),
          longVol: volDivs[0] ? volDivs[0].innerText.trim() : "0",
          shortVol: volDivs[1] ? volDivs[1].innerText.trim() : "0",
          netVol: cells[5].innerText.trim(),
          profitCount: plDivs[0] ? plDivs[0].innerText.trim() : "0",
          lossCount: plDivs[1] ? plDivs[1].innerText.trim() : "0",
          sentiment: sentimentBtn ? sentimentBtn.innerText.trim() : ""
        });
      }
    }
    return null;
  })();
`;

const RANGE_JS = `
  (function() {
    const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
    let data = { btc: null, eth: null };
    for (const row of allDivs) {
      const text = row.innerText;
      let symbol = "";
      if (text.includes('BTC') && !text.includes('WBTC')) symbol = "btc";
      else if (text.includes('ETH') && !text.includes('WETH')) symbol = "eth";
      if (symbol) {
        const amounts = row.querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by, div.Number');
        if (amounts.length >= 2) {
          data[symbol] = {
            symbol: symbol.toUpperCase(),
            long: amounts[0].innerText.trim(),
            short: amounts[1].innerText.trim(),
            total: amounts[amounts.length - 1].innerText.trim()
          };
        }
      }
    }
    return JSON.stringify(data);
  })();
`;

// ============================================
// Data Parsing (same logic as Flutter)
// ============================================

/** Convert simplified Chinese → traditional Chinese */
function toTC(s) {
  if (!s) return '';
  return s
    .replace(/超级/g, '超級').replace(/印钞机/g, '印鈔機')
    .replace(/亿/g, '億').replace(/万/g, '萬')
    .replace(/涨/g, '漲').replace(/强/g, '強')
    .replace(/势/g, '勢').replace(/态/g, '態');
}

/** Parse Chinese numeric strings like "$5.92億" → 592000000 */
function parseValue(raw) {
  if (!raw) return 0;
  let clean = raw.replace(/[\$¥,]/g, '').trim();
  let multiplier = 1;
  if (/[億B亿]/.test(clean)) { multiplier = 1e8; clean = clean.replace(/[億B亿]/g, ''); }
  else if (/[萬M万]/.test(clean)) { multiplier = 1e4; clean = clean.replace(/[萬M万]/g, ''); }
  return (parseFloat(clean) || 0) * multiplier;
}

/** Extract integer from string like "1,234 (56%)" → 1234 */
function toInt(v) {
  if (!v) return 0;
  return parseInt(v.toString().replace(/,/g, '').replace(/[^0-9]/g, '')) || 0;
}

/** Format net volume display */
function formatNet(v) {
  const sign = v >= 0 ? '+' : '';
  const abs = Math.abs(v);
  if (abs >= 1e8) return `${sign}${(v / 1e8).toFixed(2)}億`;
  return `${sign}${(v / 1e4).toFixed(0)}萬`;
}

// ============================================
// API Upload
// ============================================

async function postData(endpoint, data) {
  const url = `${CONFIG.API_URL}${endpoint}`;
  const headers = { 'Content-Type': 'application/json' };
  if (CONFIG.API_KEY) headers['X-API-Key'] = CONFIG.API_KEY;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      log(`❌ POST ${endpoint} failed: ${res.status} ${res.statusText}`);
      return false;
    }
    return true;
  } catch (e) {
    log(`❌ POST ${endpoint} error: ${e.message}`);
    return false;
  }
}

// ============================================
// Logging
// ============================================

function log(msg) {
  const now = new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false });
  console.log(`[${now}] ${msg}`);
}

// ============================================
// Main Scraper
// ============================================

async function main() {
  log('🚀 Hyper Monitor Cloud Scraper starting...');
  log(`   API: ${CONFIG.API_URL}`);
  log(`   Interval: ${CONFIG.INTERVAL / 1000}s`);
  log(`   Mode: ${CONFIG.ONCE ? 'Single run' : 'Continuous'}`);

  // Launch browser
  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-default-apps',
      '--no-first-run',
      '--single-process',
    ],
  });

  log('✅ Browser launched');

  // Open two pages (like the Flutter app's two WebViews)
  const pagePrinter = await browser.newPage();
  const pageRange = await browser.newPage();

  // Set viewport & user agent
  const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  await pagePrinter.setUserAgent(ua);
  await pageRange.setUserAgent(ua);
  await pagePrinter.setViewport({ width: 1920, height: 1080 });
  await pageRange.setViewport({ width: 1920, height: 1080 });

  // Initial page load
  log('📄 Loading Coinglass pages...');
  await Promise.all([
    pagePrinter.goto(CONFIG.URLS.printer, { waitUntil: 'networkidle2', timeout: 30000 }),
    pageRange.goto(CONFIG.URLS.range, { waitUntil: 'networkidle2', timeout: 30000 }),
  ]);

  // Wait for data to render
  await sleep(CONFIG.PAGE_LOAD_WAIT);
  log('✅ Pages loaded');

  // Scrape loop
  let cycle = 0;
  let consecutiveErrors = 0;
  const MAX_CONSECUTIVE_ERRORS = 10;

  while (true) {
    cycle++;
    try {
      await scrapeAndUpload(pagePrinter, pageRange, cycle);
      consecutiveErrors = 0;
    } catch (e) {
      consecutiveErrors++;
      log(`❌ Scrape cycle ${cycle} failed: ${e.message}`);

      if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
        log(`🔴 ${MAX_CONSECUTIVE_ERRORS} consecutive errors, reloading pages...`);
        try {
          await Promise.all([
            pagePrinter.goto(CONFIG.URLS.printer, { waitUntil: 'networkidle2', timeout: 30000 }),
            pageRange.goto(CONFIG.URLS.range, { waitUntil: 'networkidle2', timeout: 30000 }),
          ]);
          await sleep(CONFIG.PAGE_LOAD_WAIT);
          consecutiveErrors = 0;
          log('✅ Pages reloaded');
        } catch (reloadErr) {
          log(`🔴 Page reload failed: ${reloadErr.message}`);
        }
      }
    }

    if (CONFIG.ONCE) break;
    await sleep(CONFIG.INTERVAL);
  }

  await browser.close();
  log('👋 Scraper stopped');
}

async function scrapeAndUpload(pagePrinter, pageRange, cycle) {
  // Reload pages to get fresh data (same as Flutter's approach)
  await Promise.all([
    pagePrinter.reload({ waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {}),
    pageRange.reload({ waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {}),
  ]);
  await sleep(CONFIG.RELOAD_WAIT);

  // --- Scrape Printer Data ---
  let printerOk = false;
  const printerRaw = await pagePrinter.evaluate(PRINTER_JS).catch(() => null);

  if (printerRaw) {
    const d = typeof printerRaw === 'string' ? JSON.parse(printerRaw) : printerRaw;
    if (d && d.found) {
      const longNum = parseValue(d.longVol);
      const shortNum = parseValue(d.shortVol);
      const netNum = parseValue(d.netVol);

      const payload = {
        walletCount: toInt(d.walletCount),
        profitCount: toInt(d.profitCount),
        lossCount: toInt(d.lossCount),
        longVolNum: longNum,
        shortVolNum: shortNum,
        netVolNum: netNum,
        sentiment: toTC(d.sentiment),
        longDisplay: toTC(d.longVol),
        shortDisplay: toTC(d.shortVol),
        netDisplay: toTC(d.netVol),
      };

      printerOk = await postData('/update-printer', payload);
    }
  }

  // --- Scrape Range Data ---
  let rangeOk = false;
  const rangeRaw = await pageRange.evaluate(RANGE_JS).catch(() => null);

  if (rangeRaw) {
    const d = typeof rangeRaw === 'string' ? JSON.parse(rangeRaw) : rangeRaw;
    if (d) {
      const payload = {};

      for (const sym of ['btc', 'eth']) {
        if (d[sym]) {
          const l = parseValue(d[sym].long);
          const s = parseValue(d[sym].short);
          const t = parseValue(d[sym].total);
          const n = l - s;
          payload[sym] = {
            longVol: l,
            shortVol: s,
            totalVol: t,
            netVol: n,
            longDisplay: toTC(d[sym].long),
            shortDisplay: toTC(d[sym].short),
            totalDisplay: toTC(d[sym].total),
            netDisplay: formatNet(n),
          };
        }
      }

      if (Object.keys(payload).length > 0) {
        rangeOk = await postData('/update-range', payload);
      }
    }
  }

  // Log status
  const pStatus = printerOk ? '✅' : (printerRaw ? '⚠️' : '❌');
  const rStatus = rangeOk ? '✅' : (rangeRaw ? '⚠️' : '❌');
  log(`#${cycle} Printer:${pStatus} Range:${rStatus}`);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================
// Graceful Shutdown
// ============================================
process.on('SIGINT', () => { log('⚠️ SIGINT received, shutting down...'); process.exit(0); });
process.on('SIGTERM', () => { log('⚠️ SIGTERM received, shutting down...'); process.exit(0); });

// ============================================
// Run
// ============================================
main().catch(e => {
  log(`🔴 Fatal error: ${e.message}`);
  process.exit(1);
});
