/**
 * Interleave Analysis
 * Detects rows where new scraper data and old scraper data were mixed,
 * causing some rows to have valid data and adjacent rows to have NULL/0.
 */
const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const db = new Database(DB_PATH, { readonly: true });

const GROUPS = [
    { id: 'super', long: 'long_vol_num' },
    { id: 'smart', long: 'smart_long_vol_num' },
    { id: 'grinder', long: 'grinder_long_vol_num' },
    { id: 'humble', long: 'humble_long_vol_num' },
    { id: 'exit_liq', long: 'exit_liq_long_vol_num' },
    { id: 'semi_rekt', long: 'semi_rekt_long_vol_num' },
    { id: 'full_rekt', long: 'full_rekt_long_vol_num' },
    { id: 'giga_rekt', long: 'giga_rekt_long_vol_num' },
];

console.log('=== Interleave / Data Flickering Analysis ===\n');

// 1. For each group, find rows AFTER first valid data that still have NULL/0
// This detects the "flickering" pattern caused by old+new scraper overlap
console.log('--- Flickering Detection (NULL/0 rows AFTER first valid data) ---');
console.log(`${'Group'.padEnd(15)} | ${'First Valid'.padEnd(22)} | ${'Flicker Rows'.padEnd(14)} | ${'Last Flicker At'.padEnd(22)} | ${'Stable From'.padEnd(22)}`);
console.log('-'.repeat(100));

const groupInfo = {};

for (const g of GROUPS) {
    const firstValid = db.prepare(
        `SELECT MIN(timestamp) as t FROM printer_metrics WHERE ${g.long} IS NOT NULL AND ${g.long} != 0`
    ).get().t;

    // Rows after firstValid that are NULL/0 = flickering
    const flickerRows = db.prepare(
        `SELECT COUNT(*) as cnt FROM printer_metrics 
         WHERE timestamp > ? AND (${g.long} IS NULL OR ${g.long} = 0)`
    ).get(firstValid);

    // Last flickering row timestamp
    const lastFlicker = db.prepare(
        `SELECT MAX(timestamp) as t FROM printer_metrics 
         WHERE timestamp > ? AND (${g.long} IS NULL OR ${g.long} = 0)`
    ).get(firstValid);

    // First timestamp after which NO more flickering occurs (stable start)
    // = first row after lastFlicker that has valid data
    let stableFrom = firstValid;
    if (lastFlicker.t) {
        const stableRow = db.prepare(
            `SELECT MIN(timestamp) as t FROM printer_metrics 
             WHERE timestamp > ? AND ${g.long} IS NOT NULL AND ${g.long} != 0`
        ).get(lastFlicker.t);
        stableFrom = stableRow.t || lastFlicker.t;
    }

    groupInfo[g.id] = { firstValid, flickerCount: flickerRows.cnt, lastFlicker: lastFlicker.t, stableFrom };

    console.log(
        `${g.id.padEnd(15)} | ${(firstValid || 'N/A').padEnd(22)} | ${String(flickerRows.cnt).padEnd(14)} | ${(lastFlicker.t || 'none').toString().padEnd(22)} | ${stableFrom.padEnd(22)}`
    );
}

// 2. Global stable start: when ALL groups are stable
const allStableFroms = Object.values(groupInfo).map(g => g.stableFrom).sort();
const globalStableStart = allStableFroms[allStableFroms.length - 1]; // latest

// Also need BTC price to be stable
const btcLastNull = db.prepare(
    `SELECT MAX(p.timestamp) as t FROM printer_metrics p
     WHERE NOT EXISTS (
         SELECT 1 FROM range_metrics r 
         WHERE r.symbol='btc' AND r.price > 0 AND r.timestamp <= p.timestamp
     )`
).get();

let btcStableFrom = '2026-02-23 13:35:13'; // fallback
if (btcLastNull.t) {
    const afterBtc = db.prepare(
        `SELECT MIN(timestamp) as t FROM printer_metrics WHERE timestamp > ?`
    ).get(btcLastNull.t);
    if (afterBtc.t && afterBtc.t > btcStableFrom) btcStableFrom = afterBtc.t;
}

const trueStableStart = globalStableStart > btcStableFrom ? globalStableStart : btcStableFrom;

const stableRows = db.prepare('SELECT COUNT(*) as cnt FROM printer_metrics WHERE timestamp >= ?').get(trueStableStart);
const totalRows = db.prepare('SELECT COUNT(*) as cnt FROM printer_metrics').get();

console.log(`\n--- Global Stable Start ---`);
console.log(`All groups stable from:  ${globalStableStart}`);
console.log(`BTC price stable from:   ${btcStableFrom}`);
console.log(`TRUE stable start:       ${trueStableStart}`);
console.log(`Stable rows: ${stableRows.cnt} / ${totalRows.cnt} (${(stableRows.cnt / totalRows.cnt * 100).toFixed(1)}%)`);

// 3. Zoom into the transition period: hourly breakdown showing flicker rate
console.log(`\n--- Hourly Flicker Rate During Transition Period ---`);

// Get the transition window: earliest firstValid to true stable start
const transitionStart = Object.values(groupInfo).map(g => g.firstValid).sort()[0];

const hourlyFlicker = db.prepare(`
    SELECT 
        strftime('%Y-%m-%d %H:00', timestamp) as hour,
        COUNT(*) as total,
        SUM(CASE WHEN (grinder_long_vol_num IS NULL OR grinder_long_vol_num = 0) THEN 1 ELSE 0 END) as null_grinder,
        SUM(CASE WHEN (smart_long_vol_num IS NULL OR smart_long_vol_num = 0) THEN 1 ELSE 0 END) as null_smart,
        SUM(CASE WHEN (grinder_long_vol_num IS NOT NULL AND grinder_long_vol_num != 0) THEN 1 ELSE 0 END) as valid_grinder
    FROM printer_metrics
    WHERE timestamp >= ? AND timestamp <= ?
    GROUP BY hour
    ORDER BY hour ASC
`).all(transitionStart, trueStableStart);

if (hourlyFlicker.length > 0) {
    console.log(`${'Hour'.padEnd(18)} | ${'Total'.padEnd(6)} | ${'Grinder OK'.padEnd(12)} | ${'Grinder NULL'.padEnd(13)} | ${'Smart NULL'.padEnd(12)} | Flicker %`);
    console.log('-'.repeat(85));
    for (const h of hourlyFlicker) {
        const flickerPct = ((h.null_grinder / h.total) * 100).toFixed(0);
        const bar = flickerPct > 0 ? '█'.repeat(Math.min(Math.round(flickerPct / 5), 20)) : '';
        console.log(
            `${h.hour.padEnd(18)} | ${String(h.total).padEnd(6)} | ${String(h.valid_grinder).padEnd(12)} | ${String(h.null_grinder).padEnd(13)} | ${String(h.null_smart).padEnd(12)} | ${flickerPct}% ${bar}`
        );
    }
}

// 4. Quick pattern check: are null rows consecutive or randomly interspersed?
console.log(`\n--- Flicker Pattern (grinder group, post-02/23) ---`);
const flickerSample = db.prepare(`
    SELECT 
        timestamp,
        CASE WHEN (grinder_long_vol_num IS NOT NULL AND grinder_long_vol_num != 0) THEN 'OK' ELSE 'NULL' END as status
    FROM printer_metrics
    WHERE timestamp >= '2026-02-23 13:00:00' AND timestamp <= '2026-02-24 13:00:00'
    ORDER BY timestamp ASC
`).all();

let transitions = 0;
let lastStatus = '';
for (const row of flickerSample) {
    if (lastStatus && row.status !== lastStatus) transitions++;
    lastStatus = row.status;
}
const nullInSample = flickerSample.filter(r => r.status === 'NULL').length;
console.log(`Period: 02/23 13:00 ~ 02/24 13:00 (first 24h after grinder appears)`);
console.log(`Total rows: ${flickerSample.length} | NULL rows: ${nullInSample} | OK→NULL transitions: ${transitions}`);
if (transitions > 10) {
    console.log(`⚠️ HIGH FLICKER: ${transitions} status transitions detected — old & new scraper were interleaving!`);
} else if (transitions > 0) {
    console.log(`⚡ LOW FLICKER: ${transitions} transitions, mostly sequential.`);
} else {
    console.log(`✅ NO FLICKER in this window.`);
}

// 5. Show a few consecutive rows at a transition point to visualize the interleave
console.log(`\n--- Sample Interleaved Rows (around first grinder flicker) ---`);
const firstFlickerTime = db.prepare(`
    SELECT MIN(timestamp) as t FROM printer_metrics 
    WHERE timestamp > '2026-02-23 13:35:00' AND (grinder_long_vol_num IS NULL OR grinder_long_vol_num = 0)
`).get();

if (firstFlickerTime.t) {
    const around = db.prepare(`
        SELECT timestamp, 
               CASE WHEN long_vol_num IS NOT NULL AND long_vol_num != 0 THEN 'OK' ELSE '--' END as super,
               CASE WHEN smart_long_vol_num IS NOT NULL AND smart_long_vol_num != 0 THEN 'OK' ELSE '--' END as smart,
               CASE WHEN grinder_long_vol_num IS NOT NULL AND grinder_long_vol_num != 0 THEN 'OK' ELSE '--' END as grinder,
               CASE WHEN humble_long_vol_num IS NOT NULL AND humble_long_vol_num != 0 THEN 'OK' ELSE '--' END as humble
        FROM printer_metrics
        WHERE timestamp >= datetime(?, '-2 minutes') AND timestamp <= datetime(?, '+2 minutes')
        ORDER BY timestamp ASC
    `).all(firstFlickerTime.t, firstFlickerTime.t);

    console.log(`${'Timestamp'.padEnd(22)} | Super | Smart | Grinder | Humble`);
    console.log('-'.repeat(65));
    for (const r of around) {
        console.log(`${r.timestamp.padEnd(22)} | ${r.super.padEnd(5)} | ${r.smart.padEnd(5)} | ${r.grinder.padEnd(7)} | ${r.humble}`);
    }
}

db.close();
console.log('\n=== Analysis Complete ===');
