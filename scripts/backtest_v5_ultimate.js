/**
 * Hypermonitor Backtest v5: Ultimate Parameter Sweep
 * 
 * Tests 320 combinations:
 * - 2 Sizing Modes (Ratio 1/100,000 vs Fixed $100)
 * - 5 Thresholds (1M, 2M, 3M, 4M, 5M)
 * - 8 Groups
 * - 2 Directions (Normal, Reverse)
 * - 2 Coins (BTC, ETH)
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const CONFIG = {
    FEE_RATE: 0.0005,
    RATIO_MULT: 0.00001,
    FIXED_USD: 100,
};

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

const THRESHOLDS = [1_000_000, 2_000_000, 3_000_000, 4_000_000, 5_000_000];
const MODES = ['Ratio', 'Fixed100'];

function buildPriceLookup(priceRows) {
    const timestamps = priceRows.map(r => r.timestamp);
    const prices = priceRows.map(r => r.price);
    return function findPrice(ts) {
        let lo = 0, hi = timestamps.length - 1, result = null;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (timestamps[mid] <= ts) { result = prices[mid]; lo = mid + 1; }
            else { hi = mid - 1; }
        }
        return result;
    };
}

function computeMaxDrawdown(hist) {
    let peak = -Infinity, maxDd = 0;
    for (const p of hist) {
        if (p.pnl > peak) peak = p.pnl;
        const dd = peak - p.pnl;
        if (dd > maxDd) maxDd = dd;
    }
    return maxDd;
}

function computeSharpe(hist) {
    if (hist.length < 2) return 0;
    const hourlyEquity = {};
    for (const p of hist) {
        const hour = p.time.slice(0, 13);
        hourlyEquity[hour] = p.pnl;
    }
    const hours = Object.keys(hourlyEquity).sort();
    if (hours.length < 2) return 0;
    const returns = [];
    for (let i = 1; i < hours.length; i++) {
        returns.push(hourlyEquity[hours[i]] - hourlyEquity[hours[i - 1]]);
    }
    const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
    const variance = returns.reduce((a, r) => a + (r - mean) ** 2, 0) / returns.length;
    const std = Math.sqrt(variance);
    if (std === 0) return 0;
    return (mean / std) * Math.sqrt(8760);
}

function computeCalmar(finalPnl, maxDd, histLength, startTime, endTime) {
    if (histLength < 2 || maxDd === 0) return 0;
    const totalHours = Math.max(1, (new Date(endTime) - new Date(startTime)) / 3600000);
    const annualizedReturn = (finalPnl / totalHours) * 8760;
    return annualizedReturn / maxDd;
}


function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║     Hypermonitor Backtest v5: Ultimate Sweep             ║');
    console.log('║     320 Configurations | Ratio vs Fixed $100             ║');
    console.log('╚══════════════════════════════════════════════════════════╝\n');
    
    const rows = db.prepare(
        `SELECT * FROM printer_metrics WHERE timestamp >= ? ORDER BY timestamp ASC`
    ).all(STABLE_START);
    
    const btcPriceRows = db.prepare(
        `SELECT timestamp, price FROM range_metrics WHERE symbol='btc' AND price > 0 AND timestamp >= ? ORDER BY timestamp ASC`
    ).all(STABLE_START);
    
    const ethPriceRows = db.prepare(
        `SELECT timestamp, price FROM range_metrics WHERE symbol='eth' AND price > 0 AND timestamp >= ? ORDER BY timestamp ASC`
    ).all(STABLE_START);
    
    const findBtcPrice = buildPriceLookup(btcPriceRows);
    const findEthPrice = buildPriceLookup(ethPriceRows);
    
    const INSTRUMENTS = [
        { id: 'BTC', findPrice: findBtcPrice },
        { id: 'ETH', findPrice: findEthPrice },
    ];
    
    const strategies = {};
    for (const inst of INSTRUMENTS) {
        for (const g of GROUPS) {
            for (const dir of ['normal', 'reverse']) {
                for (const thresh of THRESHOLDS) {
                    for (const mode of MODES) {
                        const key = `${inst.id}_${g.id}_${dir}_${thresh/1000000}M_${mode}`;
                        strategies[key] = {
                            key, instId: inst.id, group: g, dirLabel: dir,
                            direction: dir === 'normal' ? 1 : -1,
                            threshold: thresh, mode,
                            pos: 0, realized_pnl: 0, trade_count: 0, hist_pnl: [], started: false,
                            rounds: [], round_start_time: null, round_start_equity: 0, prev_pos_sign: 0
                        };
                    }
                }
            }
        }
    }
    
    console.log(`Analyzing ${rows.length} rows...`);
    
    const prevNet = {};
    for (const row of rows) {
        const btcPrice = findBtcPrice(row.timestamp);
        const ethPrice = findEthPrice(row.timestamp);
        if (!btcPrice || !ethPrice) continue;
        const priceMap = { BTC: btcPrice, ETH: ethPrice };
        
        const deltas = {};
        for (const g of GROUPS) {
            const longField = g.prefix ? `${g.prefix}long_vol_num` : 'long_vol_num';
            const shortField = g.prefix ? `${g.prefix}short_vol_num` : 'short_vol_num';
            const longVol = parseFloat(row[longField]);
            const shortVol = parseFloat(row[shortField]);
            
            if (isNaN(longVol) || longVol === 0) { deltas[g.id] = null; continue; }
            const currentNet = longVol - (isNaN(shortVol) ? 0 : shortVol);
            
            if (prevNet[g.id] === undefined) {
                prevNet[g.id] = currentNet;
                deltas[g.id] = null;
                continue;
            }
            deltas[g.id] = currentNet - prevNet[g.id];
            prevNet[g.id] = currentNet;
        }
        
        for (const key in strategies) {
            const st = strategies[key];
            const price = priceMap[st.instId];
            const deltaH = deltas[st.group.id];
            
            if (deltaH === null || deltaH === undefined) {
                if (st.started) st.hist_pnl.push({ time: row.timestamp, pnl: st.realized_pnl + st.pos * price });
                continue;
            }
            
            if (!st.started) st.started = true;
            
            // Only trade if delta exceeds threshold
            if (Math.abs(deltaH) >= st.threshold) {
                let orderUSD = 0;
                if (st.mode === 'Ratio') {
                    orderUSD = Math.abs(deltaH) * CONFIG.RATIO_MULT;
                } else {
                    orderUSD = CONFIG.FIXED_USD;
                }
                
                const sz = orderUSD / price;
                let trade_sign = (deltaH > 0) ? 1 : -1;
                trade_sign *= st.direction;
                
                const trade_units = sz * trade_sign;
                const feeUSD = orderUSD * CONFIG.FEE_RATE;
                const prevSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                
                st.realized_pnl -= feeUSD;
                st.pos += trade_units;
                st.realized_pnl -= (trade_units * price);
                st.trade_count++;
                
                const newSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                if (prevSign !== 0 && newSign !== 0 && prevSign !== newSign) {
                    const equity = st.realized_pnl + st.pos * price;
                    const roundPnl = equity - st.round_start_equity;
                    st.rounds.push({ start: st.round_start_time, end: row.timestamp, pnl: roundPnl });
                    st.round_start_equity = equity;
                    st.round_start_time = row.timestamp;
                }
                if (newSign !== 0 && st.round_start_time === null) {
                    st.round_start_time = row.timestamp;
                    st.round_start_equity = st.realized_pnl + st.pos * price;
                }
            }
            const equity = st.realized_pnl + st.pos * price;
            st.hist_pnl.push({ time: row.timestamp, pnl: equity });
        }
    }
    
    const summaryRows = [];
    const firstTime = rows[0].timestamp + 'Z';
    const lastTime = rows[rows.length-1].timestamp + 'Z';

    for (const key in strategies) {
        const st = strategies[key];
        const hist = st.hist_pnl;
        const finalPnl = hist.length > 0 ? hist[hist.length - 1].pnl : 0;
        const maxDd = computeMaxDrawdown(hist);
        const sharpe = computeSharpe(hist);
        const calmar = computeCalmar(finalPnl, maxDd, hist.length, firstTime, lastTime);
        const winRate = st.rounds.length > 0 ? (st.rounds.filter(r => r.pnl > 0).length / st.rounds.length * 100) : 0;
        
        summaryRows.push({
            key, inst: st.instId, group: st.group.id, dir: st.dirLabel,
            mode: st.mode, threshold: st.threshold,
            pnl: finalPnl, maxDd, trades: st.trade_count,
            totalRounds: st.rounds.length, winRate, sharpe, calmar
        });
    }
    
    // Output Top 15 by Calmar Ratio (most robust metric for small accounts considering MaxDD)
    summaryRows.sort((a, b) => b.calmar - a.calmar);
    
    console.log(`\n${'═'.repeat(125)}`);
    console.log(
        `${'Strategy Name'.padEnd(35)} | ` +
        `${'Type'.padEnd(12)} | ` +
        `${'PNL ($)'.padStart(12)} | ` +
        `${'MaxDD ($)'.padStart(12)} | ` +
        `${'Sharpe'.padStart(8)} | ` +
        `${'Calmar'.padStart(8)} | ` +
        `${'Win Rate'.padStart(8)}`
    );
    console.log(`${'─'.repeat(125)}`);
    
    for (const r of summaryRows.slice(0, 15)) {
        if (r.trades === 0) continue;
        const stratName = `${r.inst}_${r.group}_${r.dir}`.padEnd(35);
        const typeStr = `${r.threshold/1000000}M_${r.mode}`.padEnd(12);
        const pnlStr = (r.pnl >= 0 ? `+${r.pnl.toFixed(1)}` : r.pnl.toFixed(1)).padStart(12);
        const maxDdStr = r.maxDd.toFixed(1).padStart(12);
        const sharpeStr = r.sharpe.toFixed(2).padStart(8);
        const calmarStr = isNaN(r.calmar) || !isFinite(r.calmar) ? '∞'.padStart(8) : r.calmar.toFixed(2).padStart(8);
        const wrStr = (r.totalRounds > 0 ? r.winRate.toFixed(0) + '%' : 'N/A').padStart(8);
        
        console.log(`${stratName} | ${typeStr} | ${pnlStr} | ${maxDdStr} | ${sharpeStr} | ${calmarStr} | ${wrStr}`);
    }

    const outputPath = path.join(__dirname, 'backtest_v5_ultimate_result.json');
    fs.writeFileSync(outputPath, JSON.stringify(summaryRows, null, 2));
    console.log(`\nResults saved to ${outputPath}`);
}

main();
