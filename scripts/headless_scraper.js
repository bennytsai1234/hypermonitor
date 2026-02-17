const puppeteer = require('puppeteer');

// --- Configuration ---
const CONFIG = {
    intervalMs: 10000, // Scrape every 10 seconds
    heartbeatMs: 60000, // Force upload every 60 seconds (Heartbeat)
    urls: {
        printer: 'https://www.coinglass.com/zh/hl',
        range: 'https://www.coinglass.com/zh/hl/range/9' // Adjust ID if needed
    },
    endpoints: {
        printer: 'https://hyper-monitor-worker.bennytsai0711.workers.dev/update-printer',
        range: 'https://hyper-monitor-worker.bennytsai0711.workers.dev/update-range'
    }
};

// --- State Tracking ---
let state = {
    printer: { lastData: null, lastUpload: 0 },
    range: { lastData: null, lastUpload: 0 }
};

// --- Scraping Logic (Optimized) ---
const SCRIPTS = {
    printer: `
    (function() {
      const getRow = (key) => document.querySelector(\`tr[data-row-key="\${key}"]\`);

      const parseRow = (row) => {
        if (!row) return null;
        const cells = row.querySelectorAll('td');
        if (cells.length < 8) return null;

        const getLines = (idx) => cells[idx] ? cells[idx].innerText.trim().split('\\n') : [];
        const clean = (s) => s ? s.trim() : "0";

        const volLines = getLines(4);
        const plLines = getLines(6);
        const sentBtn = cells[7] ? cells[7].querySelector('button') : null;

        return {
          walletCount: clean(cells[2]?.innerText),
          longVol: volLines[0] || "0",
          shortVol: volLines[1] || "0",
          netVol: clean(cells[5]?.innerText),
          profitCount: plLines[0] || "0",
          lossCount: plLines[1] || "0",
          sentiment: sentBtn ? sentBtn.innerText.trim() : ""
        };
      };

      // Force scroll just in case
      window.scrollTo(0, 500);

      const printerRow = getRow('Money_Printer');
      const smartRow = getRow('Smart_Money');

      if (!printerRow && !smartRow) return null;

      const printerData = parseRow(printerRow);
      const smartData = parseRow(smartRow);

      return JSON.stringify({
        found: true,
        ...(printerData || {}),
        smart: smartData
      });
    })();
    `,
    range: `
    (function() {
      const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      let data = { btc: null, eth: null };
      for (const row of allDivs) {
        const text = row.innerText;
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "btc";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "eth";

        if (symbol) {
          const amounts = row.querySelectorAll('div[class*="cg-style-3a6fvj"], div[class*="cg-style-zuy5by"], div[class*="Number"]');
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
    `
};

// --- Comparison Logic ---
function isDifferent(oldData, newData) {
    if (!oldData && newData) return true;
    if (oldData && !newData) return true;
    return JSON.stringify(oldData) !== JSON.stringify(newData);
}

// --- Helper: Data Cleaning (Matches Dart Logic) ---
function parseValue(raw) {
    if (!raw) return 0.0;
    let clean = raw.toString().replace(/[\$¥,]/g, '').trim();
    let multiplier = 1.0;

    if (clean.includes('億') || clean.includes('B') || clean.includes('亿')) {
        multiplier = 1e8;
        clean = clean.replace(/[億B亿]/g, '');
    } else if (clean.includes('萬') || clean.includes('M') || clean.includes('万')) {
        multiplier = 1e4;
        clean = clean.replace(/[萬M万]/g, '');
    }

    return (parseFloat(clean) || 0.0) * multiplier;
}

function parseIntClean(v) {
    if (!v) return 0;
    return parseInt(v.toString().replace(/,/g, '').replace(/[^0-9]/g, ''), 10) || 0;
}

// --- Upload Logic ---
async function uploadData(type, data) {
    const url = CONFIG.endpoints[type];
    const now = Date.now();

    // --- 1. Check Deduplication & Heartbeat ---
    const currentState = state[type];
    const changed = isDifferent(currentState.lastData, data);
    const heartbeat = (now - currentState.lastUpload) > CONFIG.heartbeatMs;

    if (!changed && !heartbeat) {
        return; // Skip upload
    }

    // --- 2. Payload Transformation ---
    let payload = {};
    if (type === 'printer') {
        const p = data;
        let s = data.smart || {};

        // --- [NEW] Global Data Protection (Sanity Checks) ---
        // If the main printer data is suspiciously zero, do NOT upload.
        // This prevents the PWA from seeing 0 and triggering false alarms.
        const printerWallet = parseIntClean(p.walletCount);
        const printerLong = parseValue(p.longVol);

        if ((printerWallet === 0 || printerLong === 0) && currentState.lastData) {
            console.warn(`🛑 [PRINTER] Data anomaly detected (Wallet: ${p.walletCount}, Vol: ${p.longVol}). Aborting upload to protect database.`);
            return;
        }

        // [Smart Money Fallback]
        // If current smart data is missing or empty (walletCount == 0),
        // try to reuse the last known good smart data from state.
        const smartWallet = parseIntClean(s.walletCount);
        if (smartWallet === 0 && currentState.lastData && currentState.lastData.smart) {
             const lastSmart = currentState.lastData.smart;
             if (parseIntClean(lastSmart.walletCount) > 0) {
                 console.log(`[PRINTER] 🛡️ Smart Money missing/empty. Reusing last known good data.`);
                 s = lastSmart;
             }
        }

        payload = {
            // Printer
            walletCount: parseIntClean(p.walletCount),
            profitCount: parseIntClean(p.profitCount),
            lossCount: parseIntClean(p.lossCount),
            sentiment: p.sentiment || "",
            longVolNum: parseValue(p.longVol),
            shortVolNum: parseValue(p.shortVol),
            netVolNum: parseValue(p.netVol),

            // Smart Money
            smartWalletCount: parseIntClean(s.walletCount),
            smartProfitCount: parseIntClean(s.profitCount),
            smartLossCount: parseIntClean(s.lossCount),
            smartSentiment: s.sentiment || "",
            smartLongVolNum: parseValue(s.longVol),
            smartShortVolNum: parseValue(s.shortVol),
            smartNetVolNum: parseValue(s.netVol)
        };
    } else if (type === 'range') {
        payload = {
            btc: data.btc ? {
                symbol: 'BTC',
                longVol: parseValue(data.btc.long),
                shortVol: parseValue(data.btc.short),
                totalVol: parseValue(data.btc.total),
                netVol: parseValue(data.btc.long) - parseValue(data.btc.short)
            } : null,
            eth: data.eth ? {
                symbol: 'ETH',
                longVol: parseValue(data.eth.long),
                shortVol: parseValue(data.eth.short),
                totalVol: parseValue(data.eth.total),
                netVol: parseValue(data.eth.long) - parseValue(data.eth.short)
            } : null
        };
    }

    try {
        console.log(`[${type.toUpperCase()}] 📤 Uploading... (Changed: ${changed}, Target: ${url})`);

        // Use native fetch (Node 18+)
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (response.ok) {
            console.log(`[${type.toUpperCase()}] ✅ Success: ${response.status} ${response.statusText}`);
            currentState.lastData = data;
            currentState.lastUpload = now;
        } else {
            const errText = await response.text();
            console.error(`[${type.toUpperCase()}] ❌ Failed: ${response.status} ${response.statusText} - ${errText}`);
        }
    } catch (e) {
        console.error(`[${type.toUpperCase()}] 💥 Error uploading: ${e.message}`);
    }
}

// --- Main Engine ---
async function startService() {
    console.log('🚀 Starting Headless Scraper Service (FORCE RELOAD MODE)...');

    const browser = await puppeteer.launch({
        headless: "new",
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const pagePrinter = await browser.newPage();
    const pageRange = await browser.newPage();

    await pagePrinter.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await pageRange.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    async function runIteration() {
        const time = new Date().toLocaleTimeString();

        // 1. Process Printer
        try {
            await pagePrinter.goto(CONFIG.urls.printer, { waitUntil: 'networkidle2', timeout: 60000 });
            await new Promise(r => setTimeout(r, 6000)); // Still need to wait 6s for the values to pop up

            const rawPrinter = await pagePrinter.evaluate(SCRIPTS.printer);
            if (rawPrinter) {
                const data = JSON.parse(rawPrinter);
                if (data.found) await uploadData('printer', data);
            }
        } catch (e) {
            console.error(`[${time}] Printer Error:`, e.message);
        }

        // 2. Process Range
        try {
            await pageRange.goto(CONFIG.urls.range, { waitUntil: 'networkidle2', timeout: 60000 });
            await new Promise(r => setTimeout(r, 6000));

            const rawRange = await pageRange.evaluate(SCRIPTS.range);
            if (rawRange) {
                const data = JSON.parse(rawRange);
                if (data.btc || data.eth) await uploadData('range', data);
            }
        } catch (e) {
            console.error(`[${time}] Range Error:`, e.message);
        }

        setTimeout(runIteration, 100);
    }

    // Start the recursive loop
    runIteration();
}

startService();
