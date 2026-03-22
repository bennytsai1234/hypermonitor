/**
 * Hypermonitor Backtest v4 (1:1 Ratio)
 * 
 * orderUSD = Math.abs(delta)
 * MIN_DELTA = 200 (to filter floating point noise)
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const CONFIG = {
    RATIO: 1,              // $1 delta = $1 order (1:1)
    FEE_RATE: 0.0005,      // 0.05% per trade (taker fee)
    MIN_DELTA: 200,        // Filter out floating point noise
    MAX_DELTA: Infinity,   // No upper limit
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

function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║     Hypermonitor Backtest v4 (1:1 Ratio)                 ║');
    console.log('║     orderUSD = Delta (No limits, $200 min noise filter)  ║');
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
                const key = `${inst.id}_${g.id}_${dir}`;
                strategies[key] = {
                    key, instId: inst.id, group: g, dirLabel: dir,
                    direction: dir === 'normal' ? 1 : -1,
                    pos: 0, realized_pnl: 0, trade_count: 0, hist_pnl: [], started: false,
                    rounds: [], round_start_time: null, round_start_equity: 0, prev_pos_sign: 0,
                    gross_volume: 0
                };
            }
        }
    }
    
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
            
            if (Math.abs(deltaH) >= CONFIG.MIN_DELTA) {
                const orderUSD = Math.abs(deltaH) * CONFIG.RATIO;
                const sz = orderUSD / price;
                let trade_sign = (deltaH > 0) ? 1 : -1;
                trade_sign *= st.direction;
                
                const trade_units = sz * trade_sign;
                const feeUSD = orderUSD * CONFIG.FEE_RATE;
                const prevSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                
                st.gross_volume += orderUSD;
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
    for (const key in strategies) {
        const st = strategies[key];
        const hist = st.hist_pnl;
        const finalPnl = hist.length > 0 ? hist[hist.length - 1].pnl : 0;
        const maxDd = computeMaxDrawdown(hist);
        const sharpe = computeSharpe(hist);
        const winRate = st.rounds.length > 0 ? (st.rounds.filter(r => r.pnl > 0).length / st.rounds.length * 100) : 0;
        
        summaryRows.push({
            key, inst: st.instId, group: st.group.id, dir: st.dirLabel,
            pnl: finalPnl, maxDd, trades: st.trade_count, volume: st.gross_volume,
            totalRounds: st.rounds.length, winRate, sharpe,
        });
    }
    
    // Sort by PNL
    summaryRows.sort((a, b) => b.pnl - a.pnl);
    
    console.log(`\n${'═'.repeat(120)}`);
    console.log(
        `${'Strategy'.padEnd(30)} | ` +
        `${'PNL ($)'.padStart(16)} | ` +
        `${'MaxDD ($)'.padStart(16)} | ` +
        `${'Trades'.padStart(7)} | ` +
        `${'Vol($) M'.padStart(10)} | ` +
        `${'Sharpe'.padStart(8)}`
    );
    console.log(`${'─'.repeat(120)}`);
    
    for (const r of summaryRows) {
        console.log(
            `${r.key.padEnd(30)} | ` +
            `${r.pnl.toFixed(0).padStart(16)} | ` +
            `${r.maxDd.toFixed(0).padStart(16)} | ` +
            `${String(r.trades).padStart(7)} | ` +
            `${(r.volume/1000000).toFixed(1).padStart(10)} | ` +
            `${r.sharpe.toFixed(2).padStart(8)}`
        );
    }
}

main();
