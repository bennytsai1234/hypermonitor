const puppeteer = require('puppeteer');

// --- 1. The Function Under Test (Identical to headless_scraper.js) ---
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

// --- 2. Scraping Logic ---
const SCRIPTS = {
    printer: `
    (function() {
      const getRow = (key) => document.querySelector(\`tr[data-row-key="\${key}"]\`);
      const row = getRow('Money_Printer');
      if (!row) return null;

      const cells = row.querySelectorAll('td');
      const getLine = (idx, line) => cells[idx] ? cells[idx].innerText.trim().split('\\n')[line] : null;

      // We want to test 'Long Vol' specifically as it usually has units
      return getLine(4, 0); // Index 4, Line 0 = Long Vol
    })()
    `,
    range: `
    (function() {
      const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      for (const row of allDivs) {
        if (row.innerText.includes('BTC') && !row.innerText.includes('WBTC')) {
             const amounts = row.querySelectorAll('div[class*="cg-style-3a6fvj"]');
             if (amounts.length > 0) return amounts[0].innerText.trim(); // First amount is Long Vol
        }
      }
      return null;
    })()
    `
};

async function runRealWorldTest() {
    console.log('🚀 Starting Real-World Parsing Test...');
    const browser = await puppeteer.launch({ headless: "new" });
    const page = await browser.newPage();

    // Set User Agent
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    try {
        // --- Test 1: Printer Page ---
        console.log('\n--- 1. Testing Printer Page (https://www.coinglass.com/zh/hl) ---');
        await page.goto('https://www.coinglass.com/zh/hl', { waitUntil: 'networkidle2', timeout: 60000 });

        const rawPrinter = await page.evaluate(SCRIPTS.printer);
        console.log(`📥 Scraped Raw Value (Printer Long Vol): "${rawPrinter}"`);

        if (rawPrinter) {
            const parsed = parseValue(rawPrinter);
            console.log(`✅ Parsed Value: ${parsed.toLocaleString()} (Type: ${typeof parsed})`);

            if (parsed > 1000000) {
                console.log('🎉 Validation: Value looks realistic (> 1M)');
            } else {
                console.warn('⚠️ Validation: Value seems too small. Check units.');
            }
        } else {
            console.error('❌ Failed to scrape Printer value. Selector might be wrong.');
        }

        // --- Test 2: Range Page ---
        console.log('\n--- 2. Testing Range Page (https://www.coinglass.com/zh/hl/range/9) ---');
        await page.goto('https://www.coinglass.com/zh/hl/range/9', { waitUntil: 'networkidle2', timeout: 60000 });

        const rawRange = await page.evaluate(SCRIPTS.range);
        console.log(`📥 Scraped Raw Value (BTC Long Vol): "${rawRange}"`);

        if (rawRange) {
            const parsed = parseValue(rawRange);
            console.log(`✅ Parsed Value: ${parsed.toLocaleString()} (Type: ${typeof parsed})`);
             if (parsed > 1000000) {
                console.log('🎉 Validation: Value looks realistic (> 1M)');
            } else {
                console.warn('⚠️ Validation: Value seems too small.');
            }
        } else {
            console.error('❌ Failed to scrape Range value.');
        }

    } catch (e) {
        console.error('💥 Error:', e.message);
    } finally {
        await browser.close();
        console.log('\n🏁 Test Finished.');
    }
}

runRealWorldTest();
