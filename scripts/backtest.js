const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const DUMP_PATH = path.join(__dirname, '../worker/hyper_db_dump.sql');

async function importDatabase(db) {
    if (!fs.existsSync(DB_PATH) || fs.statSync(DB_PATH).size < 1000) {
        console.log('Creating local SQLite database from 100MB D1 dump...');
        const sqlDump = fs.readFileSync(DUMP_PATH, 'utf8');
        
        console.log('Splitting SQL statements for faster ingestion...');
        const statements = sqlDump.split(';\n');
        
        db.pragma('journal_mode = OFF');
        db.pragma('synchronous = 0');
        
        db.exec('BEGIN TRANSACTION');
        let count = 0;
        for (const stmt of statements) {
            const cleanStmt = stmt.trim();
            if (cleanStmt) {
                db.exec(cleanStmt + ';');
                count++;
                if (count % 50 === 0) console.log(`Executed ${count} large statement blocks...`);
            }
        }
        db.exec('COMMIT');
        
        console.log('Database initialized successfully.');
    }
}

async function main() {
    const db = new Database(DB_PATH);
    await importDatabase(db);

// Group definitions
const GROUPS = [
    { id: 'super', field_prefix: '' },
    { id: 'smart', field_prefix: 'smart_' },
    { id: 'grinder', field_prefix: 'grinder_' },
    { id: 'humble', field_prefix: 'humble_' },
    { id: 'exit_liq', field_prefix: 'exit_liq_' },
    { id: 'semi_rekt', field_prefix: 'semi_rekt_' },
    { id: 'full_rekt', field_prefix: 'full_rekt_' },
    { id: 'giga_rekt', field_prefix: 'giga_rekt_' },
];

const CONFIG = {
    RATIO: 1 / 100000, // $10,000,000 delta = $100 order
    FEE_RATE: 0.0005, // 0.05% per trade
    MIN_DELTA: 5000000, // 5M minimum trigger
    MAX_DELTA: 40000000 // 40M max trigger
};

const strategies = {};

GROUPS.forEach(g => {
    strategies[`${g.id}_normal`] = { group: g, direction: 1, pos_btc: 0, realized_pnl: 0, trade_count: 0, hist_pnl: [] };
    strategies[`${g.id}_reverse`] = { group: g, direction: -1, pos_btc: 0, realized_pnl: 0, trade_count: 0, hist_pnl: [] };
});

const prevNet = {};

console.log('Querying joined data (might take a few seconds)...');

// Fetch all rows joined with the most recent BTC price known at that timestamp
const rows = db.prepare(`
    SELECT
      p.timestamp,
      p.long_vol_num, p.short_vol_num, p.net_vol_num,
      p.smart_long_vol_num, p.smart_short_vol_num, p.smart_net_vol_num,
      p.grinder_long_vol_num, p.grinder_short_vol_num, p.grinder_net_vol_num,
      p.humble_long_vol_num, p.humble_short_vol_num, p.humble_net_vol_num,
      p.exit_liq_long_vol_num, p.exit_liq_short_vol_num, p.exit_liq_net_vol_num,
      p.semi_rekt_long_vol_num, p.semi_rekt_short_vol_num, p.semi_rekt_net_vol_num,
      p.full_rekt_long_vol_num, p.full_rekt_short_vol_num, p.full_rekt_net_vol_num,
      p.giga_rekt_long_vol_num, p.giga_rekt_short_vol_num, p.giga_rekt_net_vol_num,
      (SELECT price FROM range_metrics r WHERE r.symbol = 'btc' AND r.timestamp <= p.timestamp ORDER BY timestamp DESC LIMIT 1) as btc_price
    FROM printer_metrics p
    ORDER BY p.timestamp ASC
`).all();

console.log(`Processing ${rows.length} rows...`);

rows.forEach((row, idx) => {
    const price = row.btc_price;
    if (!price) return; // Wait until price data is available

    // FAIRNESS CHECK: 
    // Wait until ALL 8 groups have non-zero data to start the simulation.
    // This ensures we are comparing performance over the EXACT SAME time period.
    let allGroupsValid = true;
    for (const g of GROUPS) {
        const longField = g.field_prefix === '' ? 'long_vol_num' : `${g.field_prefix}long_vol_num`;
        if (!row[longField] || row[longField] === 0) {
            allGroupsValid = false;
            break;
        }
    }
    
    if (!allGroupsValid) {
        return; // Skip this row, waiting for all data columns to exist
    }

    // Now process normally since all data is active
    for (const st_key in strategies) {
        const st = strategies[st_key];
        const g = st.group;

        const longField = g.field_prefix === '' ? 'long_vol_num' : `${g.field_prefix}long_vol_num`;
        const shortField = g.field_prefix === '' ? 'short_vol_num' : `${g.field_prefix}short_vol_num`;

        const longVol = row[longField] || 0;
        const shortVol = row[shortField] || 0;
        const currentNet = longVol - shortVol;

        // Init
        if (prevNet[g.id] === undefined) {
           if (st_key.endsWith('_normal')) { // Set it only once per group
               prevNet[g.id] = currentNet;
           }
           st.hist_pnl.push({ time: row.timestamp, pnl: 0 });
           continue;
        }

        const deltaH = currentNet - prevNet[g.id];

        if (Math.abs(deltaH) >= CONFIG.MIN_DELTA && Math.abs(deltaH) <= CONFIG.MAX_DELTA) {
            const orderUSD = Math.abs(deltaH) * CONFIG.RATIO;
            const sz_btc = orderUSD / price;

            // Normal: longs increase (deltaH > 0) = Buy
            let trade_sign = (deltaH > 0) ? 1 : -1;
            trade_sign *= st.direction;

            const trade_btc = sz_btc * trade_sign;

            // Log fee
            const feeUSD = orderUSD * CONFIG.FEE_RATE;
            st.realized_pnl -= feeUSD;

            // Execute Trade (Decrease realized_cash if buy, increase if sell)
            st.pos_btc += trade_btc;
            st.realized_pnl -= (trade_btc * price);

            st.trade_count++;
        }

        const equity = st.realized_pnl + (st.pos_btc * price);
        st.hist_pnl.push({ time: row.timestamp, pnl: equity });
    }

    // Update prevNet after calculating for both strategies in the group
    GROUPS.forEach(g => {
        const longField = g.field_prefix === '' ? 'long_vol_num' : `${g.field_prefix}long_vol_num`;
        const shortField = g.field_prefix === '' ? 'short_vol_num' : `${g.field_prefix}short_vol_num`;
        prevNet[g.id] = (row[longField] || 0) - (row[shortField] || 0);
    });
});

console.log('Simulation complete. Formatting results...');

const finalResults = {};
for (const k in strategies) {
    const st = strategies[k];
    const final_pnl = st.hist_pnl.length > 0 ? st.hist_pnl[st.hist_pnl.length - 1].pnl : 0;
    
    let maxEq = -Infinity;
    let maxDd = 0;
    for (let p of st.hist_pnl) {
        if (p.pnl > maxEq) maxEq = p.pnl;
        const dd = maxEq - p.pnl;
        if (dd > maxDd) maxDd = dd;
    }

    finalResults[k] = {
        name: k,
        final_pnl,
        max_drawdown: maxDd,
        trade_count: st.trade_count,
        hist: st.hist_pnl // keep full res, downsample in frontend if needed
    };
    console.log(`[${k}] PNL: $${final_pnl.toFixed(2)}, MaxDD: $${maxDd.toFixed(2)}, Trades: ${st.trade_count}`);
}

fs.writeFileSync(path.join(__dirname, 'backtest_result.json'), JSON.stringify(finalResults));
console.log('Results saved to backtest_result.json!');
}

main().catch(console.error);
