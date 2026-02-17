const puppeteer = require('puppeteer');

async function testScraper() {
    console.log('🚀 Starting Test Scraper...');
    const browser = await puppeteer.launch({ headless: "new" });
    const page = await browser.newPage();

    // Set User Agent to avoid bot detection
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    console.log('🌐 Navigating to Coinglass...');
    try {
        await page.goto('https://www.coinglass.com/zh/hl', { waitUntil: 'networkidle2', timeout: 60000 });

        // Wait for the table to be visible
        console.log('⏳ Waiting for table to render...');
        await page.waitForSelector('tr[data-row-key="Money_Printer"]', { timeout: 15000 });

        console.log('🔍 Executing Extraction Logic...');
        const result = await page.evaluate(() => {
            const extractRow = (key) => {
                let row = document.querySelector(`tr[data-row-key="${key}"]`);
                if (!row) return null;

                const cells = row.querySelectorAll('td');
                if (cells.length < 8) return null;

                const volDivs = cells[4].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
                const netVolDiv = cells[5].querySelector('div.Number') || cells[5];
                const plDivs = cells[7].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
                const sentimentBtn = row.querySelector('button.tag-but');

                return {
                    walletCount: cells[2] ? cells[2].innerText.trim() : "0",
                    longVol: volDivs[0] ? volDivs[0].innerText.trim() : "0",
                    shortVol: volDivs[1] ? volDivs[1].innerText.trim() : "0",
                    netVol: netVolDiv ? netVolDiv.innerText.trim() : "0",
                    profitCount: plDivs[0] ? plDivs[0].innerText.trim() : "0",
                    lossCount: plDivs[1] ? plDivs[1].innerText.trim() : "0",
                    sentiment: sentimentBtn ? sentimentBtn.innerText.trim() : ""
                };
            };

            const printer = extractRow('Money_Printer');
            const smart = extractRow('Smart_Money');

            return { printer, smart };
        });

        console.log('✅ Extraction Result:');
        console.log(JSON.stringify(result, null, 2));

        if (result.printer || result.smart) {
            console.log('📡 Sending to Worker...');
            // In a real test, you can uncomment this to actually update your DB
            /*
            const axios = require('axios');
            const payload = {
                ...result.printer,
                smart: result.smart
            };
            await axios.post('https://hyper-monitor-worker.bennytsai0711.workers.dev/update-printer', payload);
            console.log('✨ Data updated successfully!');
            */
        } else {
            console.log('❌ Failed to find expected rows. Check if data-row-key has changed.');
        }

    } catch (err) {
        console.error('💥 Error during scraping:', err.message);
    } finally {
        await browser.close();
        console.log('🏁 Scraper finished.');
    }
}

testScraper();
