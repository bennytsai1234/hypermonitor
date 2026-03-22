/**
 * Hypermonitor Backtest v2
 * 
 * Improvements over v1:
 * - Uses only clean/stable data (post 2026-03-02 15:07)
 * - Dual instrument: BTC + ETH
 * - Zero-crossing round trip detection for win rate
 * - Enhanced statistics: Win Rate, Avg Win/Loss, Sharpe, Max DD, Calmar
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const CONFIG = {
    RATIO: 1 / 100000,     // $10,000,000 delta → $100 order
    FEE_RATE: 0.0005,      // 0.05% per trade (taker fee)
    MIN_DELTA: 1_000_000,  // $1M minimum trigger
    MAX_DELTA: 40_000_000, // $40M maximum trigger
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

// ─── Price Lookup (binary search for most recent price <= timestamp) ───
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

// ─── Statistics Helpers ───
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
    // Compute hourly equity snapshots, then hourly returns
    if (hist.length < 2) return 0;
    
    // Group by hour
    const hourlyEquity = {};
    for (const p of hist) {
        const hour = p.time.slice(0, 13); // 'YYYY-MM-DD HH'
        hourlyEquity[hour] = p.pnl; // last value in each hour
    }
    
    const hours = Object.keys(hourlyEquity).sort();
    if (hours.length < 2) return 0;
    
    const returns = [];
    for (let i = 1; i < hours.length; i++) {
        // Use absolute return (not percentage, since starting equity is 0)
        returns.push(hourlyEquity[hours[i]] - hourlyEquity[hours[i - 1]]);
    }
    
    const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
    const variance = returns.reduce((a, r) => a + (r - mean) ** 2, 0) / returns.length;
    const std = Math.sqrt(variance);
    
    if (std === 0) return 0;
    
    // Annualize: sqrt(8760 hours/year)
    return (mean / std) * Math.sqrt(8760);
}

// ─── Main ───
function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('╔══════════════════════════════════════════════╗');
    console.log('║     Hypermonitor Backtest v2                 ║');
    console.log('║     BTC + ETH · 8 Groups · Normal/Reverse   ║');
    console.log('╚══════════════════════════════════════════════╝\n');
    console.log(`Clean data start: ${STABLE_START}`);
    
    // ─── Load Data ───
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
    
    const lastRow = rows[rows.length - 1];
    console.log(`Data end:         ${lastRow.timestamp}`);
    console.log(`Total rows:       ${rows.length}`);
    console.log(`BTC prices:       ${btcPriceRows.length}`);
    console.log(`ETH prices:       ${ethPriceRows.length}\n`);
    
    // ─── Initialize 32 Strategies ───
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
                    key,
                    instId: inst.id,
                    findPrice: inst.findPrice,
                    group: g,
                    direction: dir === 'normal' ? 1 : -1,
                    dirLabel: dir,
                    // Position tracking
                    pos: 0,
                    realized_pnl: 0,
                    trade_count: 0,
                    hist_pnl: [],
                    started: false,
                    // Round trip tracking
                    rounds: [],
                    round_start_time: null,
                    round_start_equity: 0,
                    prev_pos_sign: 0,
                };
            }
        }
    }
    
    // ─── Simulation Loop ───
    console.log('Running simulation...');
    
    const prevNet = {}; // Shared per-group across all strategies
    
    for (const row of rows) {
        const btcPrice = findBtcPrice(row.timestamp);
        const ethPrice = findEthPrice(row.timestamp);
        if (!btcPrice || !ethPrice) continue;
        
        const priceMap = { BTC: btcPrice, ETH: ethPrice };
        
        // Phase 1: Compute deltas per group (shared across instruments)
        const deltas = {};
        for (const g of GROUPS) {
            const longField = g.prefix ? `${g.prefix}long_vol_num` : 'long_vol_num';
            const shortField = g.prefix ? `${g.prefix}short_vol_num` : 'short_vol_num';
            const longVol = row[longField];
            const shortVol = row[shortField];
            
            if (longVol == null || longVol === 0) {
                deltas[g.id] = null;
                continue;
            }
            
            const currentNet = longVol - (shortVol || 0);
            
            if (prevNet[g.id] === undefined) {
                prevNet[g.id] = currentNet;
                deltas[g.id] = null; // First row, no delta yet
                continue;
            }
            
            deltas[g.id] = currentNet - prevNet[g.id];
            prevNet[g.id] = currentNet;
        }
        
        // Phase 2: Apply deltas to all 32 strategies
        for (const key in strategies) {
            const st = strategies[key];
            const price = priceMap[st.instId];
            const deltaH = deltas[st.group.id];
            
            // No valid delta for this group → record equity if already started
            if (deltaH === null || deltaH === undefined) {
                if (st.started) {
                    st.hist_pnl.push({ time: row.timestamp, pnl: st.realized_pnl + st.pos * price });
                }
                continue;
            }
            
            if (!st.started) st.started = true;
            
            // Execute trade if delta is within thresholds
            if (Math.abs(deltaH) >= CONFIG.MIN_DELTA && Math.abs(deltaH) <= CONFIG.MAX_DELTA) {
                const orderUSD = Math.abs(deltaH) * CONFIG.RATIO;
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
                
                // ─── Zero-Crossing Round Trip Detection ───
                const newSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                
                if (prevSign !== 0 && newSign !== 0 && prevSign !== newSign) {
                    // Position flipped! Close the round.
                    const equity = st.realized_pnl + st.pos * price;
                    const roundPnl = equity - st.round_start_equity;
                    st.rounds.push({
                        start: st.round_start_time,
                        end: row.timestamp,
                        pnl: roundPnl,
                        direction: prevSign > 0 ? 'LONG' : 'SHORT',
                    });
                    st.round_start_equity = equity;
                    st.round_start_time = row.timestamp;
                }
                
                // Initialize round tracking on first position
                if (newSign !== 0 && st.round_start_time === null) {
                    st.round_start_time = row.timestamp;
                    st.round_start_equity = st.realized_pnl + st.pos * price;
                }
                
                if (newSign !== 0) st.prev_pos_sign = newSign;
            }
            
            const equity = st.realized_pnl + st.pos * price;
            st.hist_pnl.push({ time: row.timestamp, pnl: equity });
        }
    }
    
    // ─── Compute Statistics & Output ───
    console.log('\nSimulation complete. Computing statistics...\n');
    
    const results = {};
    const summaryRows = [];
    
    for (const key in strategies) {
        const st = strategies[key];
        const hist = st.hist_pnl;
        const finalPnl = hist.length > 0 ? hist[hist.length - 1].pnl : 0;
        const maxDd = computeMaxDrawdown(hist);
        const sharpe = computeSharpe(hist);
        
        // Round trip stats
        const wins = st.rounds.filter(r => r.pnl > 0);
        const losses = st.rounds.filter(r => r.pnl <= 0);
        const winRate = st.rounds.length > 0 ? (wins.length / st.rounds.length * 100) : 0;
        const avgWin = wins.length > 0 ? wins.reduce((a, r) => a + r.pnl, 0) / wins.length : 0;
        const avgLoss = losses.length > 0 ? Math.abs(losses.reduce((a, r) => a + r.pnl, 0) / losses.length) : 0;
        const profitFactor = avgLoss > 0 ? avgWin / avgLoss : (avgWin > 0 ? Infinity : 0);
        
        // Calmar ratio (annualized return / max drawdown)
        // We have ~20 days of data
        const totalHours = hist.length > 0
            ? (new Date(hist[hist.length - 1].time) - new Date(hist[0].time)) / 3600000
            : 1;
        const annualizedReturn = (finalPnl / Math.max(totalHours, 1)) * 8760;
        const calmar = maxDd > 0 ? annualizedReturn / maxDd : 0;
        
        results[key] = {
            name: key,
            instrument: st.instId,
            group: st.group.id,
            direction: st.dirLabel,
            final_pnl: finalPnl,
            max_drawdown: maxDd,
            trade_count: st.trade_count,
            rounds_total: st.rounds.length,
            rounds_wins: wins.length,
            rounds_losses: losses.length,
            win_rate: winRate,
            avg_win: avgWin,
            avg_loss: avgLoss,
            profit_factor: profitFactor,
            sharpe,
            calmar,
            hist: hist,
            rounds: st.rounds,
        };
        
        summaryRows.push({
            key, inst: st.instId, group: st.group.id, dir: st.dirLabel,
            pnl: finalPnl, maxDd, trades: st.trade_count,
            totalRounds: st.rounds.length, winRate, profitFactor, sharpe, calmar,
        });
    }
    
    // ─── Sort & Print Summary Table ───
    // Sort by instrument, then by final PNL descending
    summaryRows.sort((a, b) => {
        if (a.inst !== b.inst) return a.inst < b.inst ? -1 : 1;
        return b.pnl - a.pnl;
    });
    
    for (const inst of ['BTC', 'ETH']) {
        console.log(`\n${'═'.repeat(130)}`);
        console.log(`  ${inst} Contract Simulation Results`);
        console.log(`${'═'.repeat(130)}`);
        console.log(
            `${'Strategy'.padEnd(26)} | ` +
            `${'PNL ($)'.padStart(12)} | ` +
            `${'MaxDD ($)'.padStart(12)} | ` +
            `${'Trades'.padStart(7)} | ` +
            `${'Rounds'.padStart(7)} | ` +
            `${'WinRate'.padStart(8)} | ` +
            `${'PF'.padStart(7)} | ` +
            `${'Sharpe'.padStart(8)} | ` +
            `${'Calmar'.padStart(8)}`
        );
        console.log(`${'─'.repeat(130)}`);
        
        for (const row of summaryRows.filter(r => r.inst === inst)) {
            const pnlStr = row.pnl >= 0 ? `+${row.pnl.toFixed(2)}` : row.pnl.toFixed(2);
            const wrStr = row.totalRounds > 0 ? `${row.winRate.toFixed(0)}%` : 'N/A';
            const pfStr = row.profitFactor === Infinity ? '∞' : row.profitFactor.toFixed(2);
            
            console.log(
                `${(row.group + '_' + row.dir).padEnd(26)} | ` +
                `${pnlStr.padStart(12)} | ` +
                `${row.maxDd.toFixed(2).padStart(12)} | ` +
                `${String(row.trades).padStart(7)} | ` +
                `${String(row.totalRounds).padStart(7)} | ` +
                `${wrStr.padStart(8)} | ` +
                `${pfStr.padStart(7)} | ` +
                `${row.sharpe.toFixed(2).padStart(8)} | ` +
                `${row.calmar.toFixed(2).padStart(8)}`
            );
        }
    }
    
    // ─── Top 5 Overall ───
    const allSorted = [...summaryRows].sort((a, b) => b.pnl - a.pnl);
    console.log(`\n${'═'.repeat(80)}`);
    console.log('  🏆 Top 5 Strategies (by PNL)');
    console.log(`${'═'.repeat(80)}`);
    for (let i = 0; i < Math.min(5, allSorted.length); i++) {
        const r = allSorted[i];
        console.log(
            `  ${i + 1}. ${r.key.padEnd(30)} PNL: $${r.pnl >= 0 ? '+' : ''}${r.pnl.toFixed(2)}  ` +
            `WR: ${r.totalRounds > 0 ? r.winRate.toFixed(0) + '%' : 'N/A'}  ` +
            `Sharpe: ${r.sharpe.toFixed(2)}  MaxDD: $${r.maxDd.toFixed(2)}`
        );
    }
    
    console.log(`\n${'═'.repeat(80)}`);
    console.log('  💀 Bottom 5 Strategies (by PNL)');
    console.log(`${'═'.repeat(80)}`);
    for (let i = allSorted.length - 1; i >= Math.max(0, allSorted.length - 5); i--) {
        const r = allSorted[i];
        console.log(
            `  ${allSorted.length - i}. ${r.key.padEnd(30)} PNL: $${r.pnl >= 0 ? '+' : ''}${r.pnl.toFixed(2)}  ` +
            `WR: ${r.totalRounds > 0 ? r.winRate.toFixed(0) + '%' : 'N/A'}  ` +
            `Sharpe: ${r.sharpe.toFixed(2)}  MaxDD: $${r.maxDd.toFixed(2)}`
        );
    }
    
    // ─── Save Results ───
    const outputPath = path.join(__dirname, 'backtest_v2_result.json');
    fs.writeFileSync(outputPath, JSON.stringify(results));
    console.log(`\nResults saved to ${outputPath}`);
    
    db.close();
}

main();
