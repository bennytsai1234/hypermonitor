const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const GROUPS = [
    { id: 'super',     prefix: '' },
    { id: 'smart',     prefix: 'smart_' },
    { id: 'grinder',   prefix: 'grinder_' },
    { id: 'humble',    prefix: 'humble_' },
    { id: 'exit_liq',  prefix: 'exit_liq_' },
    { id: 'semi_rekt', prefix: 'semi_rekt_' },
    { id: 'full_rekt', prefix: 'full_rekt_' },
    { id: 'giga_rekt', prefix: 'giga_rekt_' },
];

function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('Analyzing minimum absolute DELTA for each group...\n');
    
    // Load rows
    const rows = db.prepare(
        `SELECT * FROM printer_metrics WHERE timestamp >= ? ORDER BY timestamp ASC`
    ).all(STABLE_START);

    const prevNet = {};
    const minDeltas = {};
    
    // Initialize minDeltas with Infinity
    for (const g of GROUPS) {
        minDeltas[g.id] = Infinity;
    }

    for (const row of rows) {
        for (const g of GROUPS) {
            const longField = g.prefix ? `${g.prefix}long_vol_num` : 'long_vol_num';
            const shortField = g.prefix ? `${g.prefix}short_vol_num` : 'short_vol_num';
            const longVol = row[longField];
            const shortVol = row[shortField];
            
            if (longVol == null || longVol === 0) continue;
            
            const currentNet = longVol - (shortVol || 0);
            
            if (prevNet[g.id] === undefined) {
                prevNet[g.id] = currentNet;
                continue;
            }
            
            const deltaH = Math.abs(currentNet - prevNet[g.id]);
            prevNet[g.id] = currentNet;
            
            // We only care about non-zero deltas >= 200 (filter out floating point noise & micro changes)
            if (deltaH >= 200 && deltaH < minDeltas[g.id]) {
                minDeltas[g.id] = deltaH;
            }
        }
    }

    // Print results
    console.log("Minimum Non-Zero Delta values:");
    console.log("------------------------------");
    for (const g of GROUPS) {
        const minVal = minDeltas[g.id] === Infinity ? "N/A" : minDeltas[g.id].toString();
        // Format to show full number without scientific notation if possible
        console.log(`${g.id.padEnd(12)} : ${minVal}`);
    }

    db.close();
}

main();
