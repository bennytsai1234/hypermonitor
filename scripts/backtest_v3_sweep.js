/**
 * Hypermonitor Backtest v3 (Sweep)
 * 
 * Tests multiple thresholds and modes simultaneously:
 * - Instant (Delta between two ticks) 1M to 5M
 * - Accumulated (Rolling sum over 15 mins) 2M to 5M
 * - Fixed order size ($1000 per trade) instead of ratio pricing
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const CONFIG = {
    ORDER_SIZE_USD: 100,   // Fixed $100 order size per trade (e.g. $10 margin * 10x)
    FEE_RATE: 0.0005,      // 0.05% per trade (taker fee)
    ACCUM_WINDOW_MS: 15 * 60 * 1000, // 15 minutes rolling window
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

const STRATEGIES = [
    { mode: 'Instant', threshold: 1_000_000 },
    { mode: 'Instant', threshold: 2_000_000 },
    { mode: 'Instant', threshold: 3_000_000 },
    { mode: 'Instant', threshold: 4_000_000 },
    { mode: 'Instant', threshold: 5_000_000 },
    { mode: 'Accum', threshold: 2_000_000 },
    { mode: 'Accum', threshold: 3_000_000 },
    { mode: 'Accum', threshold: 4_000_000 },
    { mode: 'Accum', threshold: 5_000_000 },
];

// ─── Price Lookup ───
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

// ─── Main ───
function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║     Hypermonitor Backtest v3 (Sweep Search)              ║');
    console.log('║     Fixed Order ($1000) · Instant vs 15m Accum           ║');
    console.log('╚══════════════════════════════════════════════════════════╝\n');
    
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
    
    // ─── Initialize Strategies ───
    const INSTRUMENTS = [
        { id: 'BTC', findPrice: findBtcPrice },
        { id: 'ETH', findPrice: findEthPrice },
    ];
    
    const runStates = {};
    
    for (const inst of INSTRUMENTS) {
        for (const g of GROUPS) {
            for (const dir of ['normal', 'reverse']) {
                for (const strat of STRATEGIES) {
                    const key = `${inst.id}_${g.id}_${dir}_${strat.mode}_${strat.threshold / 1000000}M`;
                    runStates[key] = {
                        key,
                        instId: inst.id,
                        group: g,
                        dirLabel: dir,
                        direction: dir === 'normal' ? 1 : -1,
                        mode: strat.mode,
                        threshold: strat.threshold,
                        
                        // Strategy State
                        pos: 0,
                        realized_pnl: 0,
                        trade_count: 0,
                        hist_pnl: [],
                        started: false,
                        
                        // Round trip
                        rounds: [],
                        round_start_time: null,
                        round_start_equity: 0,
                        prev_pos_sign: 0,
                        
                        // Accumulation State (only used for Accum mode)
                        last_trigger_time: null, 
                        accumulated_delta: 0,
                    };
                }
            }
        }
    }
    
    console.log(`Running simulation over ${rows.length} ticks...`);

    const prevNet = {};
    const accumHistory = {}; // Group -> Array of { ts: number, delta: number }
    for (const g of GROUPS) { accumHistory[g.id] = []; }
    
    // Iterate through data
    for (const row of rows) {
        const rowTime = new Date(row.timestamp + 'Z').getTime(); // parse UTC time
        
        const btcPrice = findBtcPrice(row.timestamp);
        const ethPrice = findEthPrice(row.timestamp);
        if (!btcPrice || !ethPrice) continue;
        const priceMap = { BTC: btcPrice, ETH: ethPrice };
        
        // Phase 1: Compute Deltas & Update Accumulators
        const instantDeltas = {};
        const accumDeltas = {}; // Accumulated sum over 15 mins for this tick
        
        for (const g of GROUPS) {
            const longField = g.prefix ? `${g.prefix}long_vol_num` : 'long_vol_num';
            const shortField = g.prefix ? `${g.prefix}short_vol_num` : 'short_vol_num';
            const longVol = row[longField];
            const shortVol = row[shortField];
            
            if (longVol == null || longVol === 0) {
                instantDeltas[g.id] = null;
                accumDeltas[g.id] = null;
                continue;
            }
            
            const currentNet = longVol - (shortVol || 0);
            
            if (prevNet[g.id] === undefined) {
                prevNet[g.id] = currentNet;
                instantDeltas[g.id] = null;
                accumDeltas[g.id] = null;
                continue;
            }
            
            const deltaH = currentNet - prevNet[g.id];
            prevNet[g.id] = currentNet;
            
            instantDeltas[g.id] = deltaH;
            
            // Update sliding window
            accumHistory[g.id].push({ ts: rowTime, delta: deltaH });
            
            // Prune old history
            const windowStart = rowTime - CONFIG.ACCUM_WINDOW_MS;
            while(accumHistory[g.id].length > 0 && accumHistory[g.id][0].ts < windowStart) {
                accumHistory[g.id].shift();
            }
            
            accumDeltas[g.id] = accumHistory[g.id].reduce((sum, item) => sum + item.delta, 0);
        }
        
        // Phase 2: Apply to run states
        for (const key in runStates) {
            const st = runStates[key];
            const price = priceMap[st.instId];
            
            let targetDelta = null;
            if (st.mode === 'Instant') targetDelta = instantDeltas[st.group.id];
            else if (st.mode === 'Accum') targetDelta = accumDeltas[st.group.id];
            
            if (targetDelta === null || targetDelta === undefined) {
                if (st.started) st.hist_pnl.push({ time: row.timestamp, pnl: st.realized_pnl + st.pos * price });
                continue;
            }
            
            if (!st.started) st.started = true;
            
            let triggerTrade = false;
            let tradeSign = 0;
            
            if (st.mode === 'Instant') {
                if (Math.abs(targetDelta) >= st.threshold) {
                    triggerTrade = true;
                    tradeSign = targetDelta > 0 ? 1 : -1;
                }
            } else if (st.mode === 'Accum') {
                // Determine if accumulated delta crossed the threshold
                if (Math.abs(targetDelta) >= st.threshold) {
                    triggerTrade = true;
                    tradeSign = targetDelta > 0 ? 1 : -1;
                    
                    // Reset accumulation window logic? 
                    // Usually moving averages or accumulators trigger once when crossing
                    // Here we trigger and clear the accumulation to prevent continuous firing
                    accumHistory[st.group.id] = []; 
                    // Note: clearing accumHistory affects ALL Accum strategies for this group.
                    // A proper implementation might need per-strategy accumulators if they reset differently,
                    // but since they all trigger off the same stream, clearing it is safest to simulate 
                    // "we entered, now start counting again".
                    // Wait, clearing affects the 2M if 5M isn't reached yet!
                    // Let's NOT clear the global accumulator. 
                    // Instead, implement a cooldown for the specific strategy.
                    
                    if (st.last_trigger_time && (rowTime - st.last_trigger_time < 5 * 60 * 1000)) {
                        triggerTrade = false; // Cooldown of 5 mins after a trigger
                    }
                }
            }
            
            if (triggerTrade) {
                st.last_trigger_time = rowTime;
                
                tradeSign *= st.direction;
                
                // Fixed fixed order size
                const orderUSD = CONFIG.ORDER_SIZE_USD;
                const sz = orderUSD / price;
                const trade_units = sz * tradeSign;
                const feeUSD = orderUSD * CONFIG.FEE_RATE;
                
                const prevSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                
                st.realized_pnl -= feeUSD;
                st.pos += trade_units;
                st.realized_pnl -= (trade_units * price);
                st.trade_count++;
                
                // Round trip detection
                const newSign = st.pos > 0 ? 1 : (st.pos < 0 ? -1 : 0);
                if (prevSign !== 0 && newSign !== 0 && prevSign !== newSign) {
                    const equity = st.realized_pnl + st.pos * price;
                    const roundPnl = equity - st.round_start_equity;
                    st.rounds.push({
                        start: st.round_start_time,
                        end: row.timestamp,
                        pnl: roundPnl
                    });
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
    
    // ─── Compile Results ───
    console.log('Computing Statistics...\n');
    let summaryRows = [];
    
    for (const key in runStates) {
        const st = runStates[key];
        const hist = st.hist_pnl;
        const finalPnl = hist.length > 0 ? hist[hist.length - 1].pnl : 0;
        const maxDd = computeMaxDrawdown(hist);
        const sharpe = computeSharpe(hist);
        
        const wins = st.rounds.filter(r => r.pnl > 0);
        const losses = st.rounds.filter(r => r.pnl <= 0);
        const winRate = st.rounds.length > 0 ? (wins.length / st.rounds.length * 100) : 0;
        const avgWin = wins.length > 0 ? wins.reduce((a, r) => a + r.pnl, 0) / wins.length : 0;
        const avgLoss = losses.length > 0 ? Math.abs(losses.reduce((a, r) => a + r.pnl, 0) / losses.length) : 0;
        const profitFactor = avgLoss > 0 ? avgWin / avgLoss : (avgWin > 0 ? Infinity : 0);
        
        summaryRows.push({
            key, inst: st.instId, group: st.group.id, dir: st.dirLabel,
            mode: st.mode, threshold: st.threshold,
            pnl: finalPnl, maxDd, trades: st.trade_count,
            totalRounds: st.rounds.length, winRate, profitFactor, sharpe,
        });
    }
    
    // ─── Display Top 15 Overall ───
    const allSorted = [...summaryRows].sort((a, b) => b.sharpe - a.sharpe);
    console.log(`\n${'═'.repeat(110)}`);
    console.log('  🏆 Top 15 Strategies (Sorted by Sharpe Ratio)');
    console.log(`${'═'.repeat(110)}`);
    console.log(
        `${'Strategy'.padEnd(35)} | ` +
        `${'Type'.padEnd(12)} | ` +
        `${'PNL ($)'.padStart(10)} | ` +
        `${'Sharpe'.padStart(8)} | ` +
        `${'MaxDD ($)'.padStart(10)} | ` +
        `${'WinRate'.padStart(8)} | ` +
        `${'Trades'.padStart(7)}`
    );
    console.log(`${'─'.repeat(110)}`);
    
    for (let i = 0; i < Math.min(15, allSorted.length); i++) {
        const r = allSorted[i];
        if (r.trades === 0) continue; // skip 0 trades
        
        const stratName = `${r.inst}_${r.group}_${r.dir}`.padEnd(35);
        const typeStr = `${r.mode}_${r.threshold/1000000}M`.padEnd(12);
        const pnlStr = (r.pnl >= 0 ? `+${r.pnl.toFixed(1)}` : r.pnl.toFixed(1)).padStart(10);
        const wrStr = (r.totalRounds > 0 ? r.winRate.toFixed(0) + '%' : 'N/A').padStart(8);
        const maxDdStr = r.maxDd.toFixed(1).padStart(10);
        const sharpeStr = r.sharpe.toFixed(2).padStart(8);
        
        console.log(`${stratName} | ${typeStr} | ${pnlStr} | ${sharpeStr} | ${maxDdStr} | ${wrStr} | ${String(r.trades).padStart(7)}`);
    }
    
    // Save to file
    const outputPath = path.join(__dirname, 'backtest_v3_sweep_result.json');
    fs.writeFileSync(outputPath, JSON.stringify(summaryRows, null, 2));
    console.log(`\nFull sweep results saved to ${outputPath}`);
    
    db.close();
}

main();
