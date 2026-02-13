const puppeteer = require('puppeteer');

(async () => {
  try {
    console.log('Launching browser...');
    const browser = await puppeteer.launch();
    console.log('Browser launched!');

    // Check version
    const version = await browser.version();
    console.log(`Browser version: ${version}`);

    await browser.close();
    console.log('Browser closed.');
  } catch (error) {
    console.error('Error:', error);
  }
})();
