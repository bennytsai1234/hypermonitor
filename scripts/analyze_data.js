/**
 * Data Availability Analyzer
 * Scans hyper.sqlite to discover when each data column first became available.
 */
const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const db = new Database(DB_PATH, { readonly: true });

console.log('=== Hypermonitor Data Availability Report ===\n');

// 1. Basic table stats
const printerCount = db.prepare('SELECT COUNT(*) as cnt, MIN(timestamp) as first, MAX(timestamp) as last FROM printer_metrics').get();
const rangeCount = db.prepare('SELECT COUNT(*) as cnt, MIN(timestamp) as first, MAX(timestamp) as last FROM range_metrics').get();

console.log('--- Table Overview ---');
console.log(`printer_metrics: ${printerCount.cnt} rows | ${printerCount.first} → ${printerCount.last}`);
console.log(`range_metrics:   ${rangeCount.cnt} rows | ${rangeCount.first} → ${rangeCount.last}`);

// 2. BTC / ETH price availability in range_metrics
const btcFirst = db.prepare("SELECT MIN(timestamp) as t FROM range_metrics WHERE symbol='btc' AND price IS NOT NULL AND price > 0").get();
const ethFirst = db.prepare("SELECT MIN(timestamp) as t FROM range_metrics WHERE symbol='eth' AND price IS NOT NULL AND price > 0").get();
const btcCount = db.prepare("SELECT COUNT(*) as cnt FROM range_metrics WHERE symbol='btc' AND price IS NOT NULL AND price > 0").get();
const ethCount = db.prepare("SELECT COUNT(*) as cnt FROM range_metrics WHERE symbol='eth' AND price IS NOT NULL AND price > 0").get();

console.log(`\n--- Price Data ---`);
console.log(`BTC price: first at ${btcFirst.t} (${btcCount.cnt} rows with valid price)`);
console.log(`ETH price: first at ${ethFirst.t} (${ethCount.cnt} rows with valid price)`);

// 3. Per-group data availability in printer_metrics
const GROUPS = [
    { id: 'super (printer)', long: 'long_vol_num', short: 'short_vol_num', net: 'net_vol_num' },
    { id: 'smart_money', long: 'smart_long_vol_num', short: 'smart_short_vol_num', net: 'smart_net_vol_num' },
    { id: 'grinder', long: 'grinder_long_vol_num', short: 'grinder_short_vol_num', net: 'grinder_net_vol_num' },
    { id: 'humble', long: 'humble_long_vol_num', short: 'humble_short_vol_num', net: 'humble_net_vol_num' },
    { id: 'exit_liq', long: 'exit_liq_long_vol_num', short: 'exit_liq_short_vol_num', net: 'exit_liq_net_vol_num' },
    { id: 'semi_rekt', long: 'semi_rekt_long_vol_num', short: 'semi_rekt_short_vol_num', net: 'semi_rekt_net_vol_num' },
    { id: 'full_rekt', long: 'full_rekt_long_vol_num', short: 'full_rekt_short_vol_num', net: 'full_rekt_net_vol_num' },
    { id: 'giga_rekt', long: 'giga_rekt_long_vol_num', short: 'giga_rekt_short_vol_num', net: 'giga_rekt_net_vol_num' },
];

console.log(`\n--- Per-Group First Available Data ---`);
console.log(`${'Group'.padEnd(20)} | ${'First Non-NULL'.padEnd(24)} | ${'Non-NULL Rows'.padEnd(15)} | ${'NULL/Zero Rows'.padEnd(15)}`);
console.log('-'.repeat(80));

const groupTimelines = [];

for (const g of GROUPS) {
    const firstValid = db.prepare(
        `SELECT MIN(timestamp) as t FROM printer_metrics WHERE ${g.long} IS NOT NULL AND ${g.long} != 0`
    ).get();
    const validCount = db.prepare(
        `SELECT COUNT(*) as cnt FROM printer_metrics WHERE ${g.long} IS NOT NULL AND ${g.long} != 0`
    ).get();
    const nullCount = db.prepare(
        `SELECT COUNT(*) as cnt FROM printer_metrics WHERE ${g.long} IS NULL OR ${g.long} = 0`
    ).get();

    groupTimelines.push({ id: g.id, firstValid: firstValid.t, validCount: validCount.cnt });
    console.log(`${g.id.padEnd(20)} | ${(firstValid.t || 'N/A').toString().padEnd(24)} | ${String(validCount.cnt).padEnd(15)} | ${String(nullCount.cnt).padEnd(15)}`);
}

// 4. Find the common start time (latest "first valid" across all groups + BTC price)
const allStartTimes = groupTimelines.map(g => g.firstValid).filter(Boolean);
allStartTimes.push(btcFirst.t);

const commonStart = allStartTimes.sort().pop(); // The latest start time = all data available
const commonRows = db.prepare(
    `SELECT COUNT(*) as cnt FROM printer_metrics WHERE timestamp >= ?`
).get(commonStart);

console.log(`\n--- Fair Comparison Window ---`);
console.log(`All groups + BTC price available from: ${commonStart}`);
console.log(`Usable rows for fair backtest: ${commonRows.cnt} / ${printerCount.cnt} total (${(commonRows.cnt/printerCount.cnt*100).toFixed(1)}%)`);

// 5. Data density analysis (rows per hour for different periods)
console.log(`\n--- Data Density (rows/hour) ---`);
const densityQuery = db.prepare(`
    SELECT 
        strftime('%Y-%m-%d %H:00', timestamp) as hour,
        COUNT(*) as cnt
    FROM printer_metrics
    WHERE timestamp >= ?
    GROUP BY hour
    ORDER BY hour ASC
`);

const densityRows = densityQuery.all(commonStart);
if (densityRows.length > 0) {
    const densities = densityRows.map(r => r.cnt);
    const avgDensity = densities.reduce((a, b) => a + b, 0) / densities.length;
    const minDensity = Math.min(...densities);
    const maxDensity = Math.max(...densities);
    console.log(`Average: ${avgDensity.toFixed(1)} rows/hour | Min: ${minDensity} | Max: ${maxDensity}`);
    console.log(`Total hours with data: ${densityRows.length}`);
    
    // Show first 5 and last 5 hours
    console.log(`\nFirst 5 hours:`);
    densityRows.slice(0, 5).forEach(r => console.log(`  ${r.hour}: ${r.cnt} rows`));
    console.log(`Last 5 hours:`);
    densityRows.slice(-5).forEach(r => console.log(`  ${r.hour}: ${r.cnt} rows`));
}

// 6. Check for data gaps (hours with 0 rows)
console.log(`\n--- Data Gap Detection ---`);
let gapCount = 0;
for (let i = 1; i < densityRows.length; i++) {
    const prevHour = new Date(densityRows[i-1].hour);
    const currHour = new Date(densityRows[i].hour);
    const diffHours = (currHour - prevHour) / (1000 * 60 * 60);
    if (diffHours > 1.5) { // gap of more than 1.5 hours
        if (gapCount < 10) {
            console.log(`  GAP: ${densityRows[i-1].hour} → ${densityRows[i].hour} (${diffHours.toFixed(1)} hours)`);
        }
        gapCount++;
    }
}
console.log(`Total gaps (>1.5h): ${gapCount}`);

// 7. Sample values to understand typical magnitudes
console.log(`\n--- Sample Data Magnitudes (from common start) ---`);
const sampleRow = db.prepare(`
    SELECT * FROM printer_metrics WHERE timestamp >= ? ORDER BY timestamp ASC LIMIT 1
`).get(commonStart);

if (sampleRow) {
    console.log(`Sample timestamp: ${sampleRow.timestamp}`);
    for (const g of GROUPS) {
        const lv = sampleRow[g.long];
        const sv = sampleRow[g.short];
        const nv = sampleRow[g.net] || (lv - sv);
        console.log(`  ${g.id.padEnd(20)}: long=${lv}, short=${sv}, net=${nv}`);
    }
}

db.close();
console.log('\n=== Analysis Complete ===');
