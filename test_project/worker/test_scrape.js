const axios = require('axios');

async function testScrape() {
    console.log("Starting scrape test...");

    const headers = {
        "accept": "application/json, text/plain, */*",
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        "referer": "https://www.coinglass.com/zh/hl",
        "origin": "https://www.coinglass.com"
    };

    try {
        console.log("Requesting Printer Group Data...");
        const pUrl = "https://fapi.coinglass.com/api/v1/hyperliquid/wallet/groupList?groupName=MoneyPrinter";
        const pRes = await axios.get(pUrl, { headers });
        console.log("Printer Success:", pRes.data.success);
        if (pRes.data.data) console.log("Sample Data:", JSON.stringify(pRes.data.data[0]).substring(0, 200));

        console.log("\nRequesting Range Stats...");
        const rUrl = "https://fapi.coinglass.com/api/v1/hyperliquid/wallet/rangeStats?range=9";
        const rRes = await axios.get(rUrl, { headers });
        console.log("Range Success:", rRes.data.success);
        if (rRes.data.data) console.log("BTC Stats:", rRes.data.data.find(i => i.symbol === "BTC"));

    } catch (e) {
        console.log("Error occurred!");
        if (e.response) {
            console.log("Status:", e.response.status);
            console.log("Data:", e.response.data);
        } else {
            console.log("Msg:", e.message);
        }
    }
}

testScrape();