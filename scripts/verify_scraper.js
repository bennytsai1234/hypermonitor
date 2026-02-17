const puppeteer = require('puppeteer');

// 1. Logic extracted from lib/core/data_scraper.dart (_printerJs)
const printerJs = `
    (function() {
      const getRow = (texts) => {
        const rows = document.querySelectorAll('tr');
        for (const r of rows) {
          // Check innerText for keywords
          if (texts.some(txt => r.innerText.includes(txt))) return r;
        }
        return null;
      };

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

      // Force scroll to ensure lazy rows are rendered
      window.scrollTo(0, 500);

      const printerRow = getRow(['超级印钞', '超級印鈔']);
      const smartRow = getRow(['聪明钱', '聰明錢']);

      const printerData = parseRow(printerRow);
      const smartData = parseRow(smartRow);

      if (!printerData && !smartData) return null;

      return JSON.stringify({
        found: true,
        ...(printerData || {}),
        smart: smartData
      });
    })();
`;

// 2. Logic extracted from lib/core/data_scraper.dart (_rangeJs)
const rangeJs = `
    (function() {
      // Range logic remains same, searching for BTC/ETH rows
      const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      let data = { btc: null, eth: null };
      for (const row of allDivs) {
        const text = row.innerText;
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "btc";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "eth";

        if (symbol) {
          // Attempt to find numerical columns
          const amounts = row.querySelectorAll('div[class*="cg-style-3a6fvj"], div[class*="cg-style-zuy5by"], div.Number');
          if (amounts.length >= 2) {
             // Usually: Long, Short, ..., Total
             // Or sometimes: Long, Short, Net
             // We take first two as L/S, last as Total/Net
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

async function runTest() {
    console.log('🚀 Starting Verification Scraper...');
    const browser = await puppeteer.launch({
        headless: "new",
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();

    // Set User Agent to resemble a real browser
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    try {
        // --- Test 1: Printer & Smart Money Logic ---
        console.log('\n--- 1. Testing Printer & Smart Money Logic ---');
        console.log('🌐 Navigating to https://www.coinglass.com/zh/hl ...');
        await page.goto('https://www.coinglass.com/zh/hl', { waitUntil: 'networkidle2', timeout: 60000 });

        // Wait a bit for dynamic content
        await new Promise(r => setTimeout(r, 5000));

        console.log('🔍 Executing injected JS...');
        const printerResult = await page.evaluate(printerJs);

        if (printerResult && printerResult !== "null") {
            const data = JSON.parse(printerResult);
            console.log('✅ Printer/Smart Data Found:');
            console.log(JSON.stringify(data, null, 2));

            if (!data.smart) {
                console.warn('⚠️  "Smart Money" (聪明钱) section is MISSING in the result.');
                console.log('   Possible cause: The row text changed or the row is not rendering.');
            }
        } else {
            console.error('❌ Printer/Smart Data returned NULL.');
            console.log('   Possible cause: Page layout changed completely, or loading timed out.');

            // Debug: Print page content if failed
            // const content = await page.content();
            // console.log('DEBUG: Page content length:', content.length);
        }

        // --- Test 2: Range Logic ---
        console.log('\n--- 2. Testing Range Logic ---');
        console.log('🌐 Navigating to https://www.coinglass.com/zh/hl/range/9 ...');
        await page.goto('https://www.coinglass.com/zh/hl/range/9', { waitUntil: 'networkidle2', timeout: 60000 });

        await new Promise(r => setTimeout(r, 5000));

        console.log('🔍 Executing injected JS...');
        const rangeResult = await page.evaluate(rangeJs);

        if (rangeResult && rangeResult !== "null") {
             const data = JSON.parse(rangeResult);
             console.log('✅ Range Data Found:');
             console.log(JSON.stringify(data, null, 2));

             if (!data.btc || !data.eth) {
                 console.warn('⚠️  BTC or ETH data is missing in the range result.');
             }
        } else {
            console.error('❌ Range Data returned NULL.');
        }

    } catch (err) {
        console.error('💥 Error:', err.message);
    } finally {
        await browser.close();
        console.log('\n🏁 Verification finished.');
    }
}

runTest();
