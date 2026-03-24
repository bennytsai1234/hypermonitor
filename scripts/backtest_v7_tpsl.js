/**
 * Hypermonitor Backtest v7: Take Profit & Stop Loss
 * 
 * Includes TP/SL grid search combined with v6 Train/Test splits.
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'hyper.sqlite');
const STABLE_START = '2026-03-02 15:07:06';

const CONFIG = {
    FEE_RATE: 0.0005,
    FIXED_USD: 100,
    INITIAL_MARGIN: 1000, 
    MAX_POS_USD: 500,     
    TRAIN_RATIO: 0.8
};

const GROUPS = [
    { id: 'smart',     prefix: 'smart_' },
    { id: 'humble',    prefix: 'humble_' },
    { id: 'exit_liq',  prefix: 'exit_liq_' },
    { id: 'full_rekt', prefix: 'full_rekt_' },
];

const THRESHOLDS = [2_000_000, 3_000_000, 4_000_000, 5_000_000];
const SL_PCTS = [0.01, 0.02, 0.03, 0.05, 1.0]; 
const TP_PCTS = [0.01, 0.02, 0.03, 0.05, 1.0];

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

function computeMetrics(hist, startTime, endTime) {
    if (hist.length < 2) return { pnl: 0, maxDd: 0, sharpe: 0, calmar: 0, rekt: false };
    const startPnl = hist[0].pnl;
    const finalPnl = hist[hist.length - 1].pnl;
    const netPnl = finalPnl - startPnl;
    let peak = startPnl, maxDd = 0;
    let isRekt = false;
    for (const p of hist) {
        if (p.pnl > peak) peak = p.pnl;
        const dd = peak - p.pnl;
        if (dd > maxDd) maxDd = dd;
        if (p.pnl < startPnl - CONFIG.INITIAL_MARGIN) {
            isRekt = true;
        }
    }
    
    // Quick Sharpe
    const hourlyEquity = {};
    for (const p of hist) {
        const hour = p.time.slice(0, 13);
        hourlyEquity[hour] = p.pnl;
    }
    const hours = Object.keys(hourlyEquity).sort();
    let sharpe = 0;
    if (hours.length >= 2) {
        const returns = [];
        for (let i = 1; i < hours.length; i++) {
            returns.push(hourlyEquity[hours[i]] - hourlyEquity[hours[i - 1]]);
        }
        const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
        const variance = returns.reduce((a, r) => a + (r - mean) ** 2, 0) / returns.length;
        const std = Math.sqrt(variance);
        if (std > 0) sharpe = (mean / std) * Math.sqrt(8760);
    }
    
    const tStart = new Date(startTime).getTime();
    const tEnd = new Date(endTime).getTime();
    const totalHours = Math.max(1, (tEnd - tStart) / 3600000);
    const annualizedReturn = (netPnl / totalHours) * 8760;
    const calmar = maxDd > 0 ? (annualizedReturn / maxDd) : 0;
    
    return { pnl: netPnl, maxDd, sharpe, calmar: isNaN(calmar) ? 0 : calmar, rekt: isRekt };
}


function main() {
    const db = new Database(DB_PATH, { readonly: true });
    
    console.log('╔══════════════════════════════════════════════════════════╗');
    console.log('║     Hypermonitor Backtest v7: TP/SL Optimizer            ║');
    console.log('║     1600 Combinations | Trailing Average Entry logic     ║');
    console.log('╚══════════════════════════════════════════════════════════╝\\n');
    
    const rows = db.prepare(`SELECT * FROM printer_metrics WHERE timestamp >= ? ORDER BY timestamp ASC`).all(STABLE_START);
    const btcPriceRows = db.prepare(`SELECT timestamp, price FROM range_metrics WHERE symbol='btc' AND price > 0 AND timestamp >= ? ORDER BY timestamp ASC`).all(STABLE_START);
    const ethPriceRows = db.prepare(`SELECT timestamp, price FROM range_metrics WHERE symbol='eth' AND price > 0 AND timestamp >= ? ORDER BY timestamp ASC`).all(STABLE_START);
    
    const findBtcPrice = buildPriceLookup(btcPriceRows);
    const findEthPrice = buildPriceLookup(ethPriceRows);
    
    const INSTRUMENTS = [{ id: 'BTC', findPrice: findBtcPrice }, { id: 'ETH', findPrice: findEthPrice }];
    if (rows.length === 0) return;
    
    const firstTs = new Date(rows[0].timestamp).getTime();
    const lastTs = new Date(rows[rows.length-1].timestamp).getTime();
    const splitTsMs = firstTs + (lastTs - firstTs) * CONFIG.TRAIN_RATIO;
    const splitTsStr = new Date(splitTsMs).toISOString().slice(0, 19).replace('T', ' ');
    
    const strategies = {};
    let strategyCount = 0;
    for (const inst of INSTRUMENTS) {
        for (const g of GROUPS) {
            for (const dir of ['normal', 'reverse']) {
                for (const thresh of THRESHOLDS) {
                    for (const sl of SL_PCTS) {
                        for (const tp of TP_PCTS) {
                            const key = `${inst.id}_${g.id}_${dir}_${thresh/1000000}M_SL${sl*100}_TP${tp*100}`;
                            strategies[key] = {
                                key, instId: inst.id, group: g, dirLabel: dir,
                                direction: dir === 'normal' ? 1 : -1,
                                threshold: thresh,
                                sl_pct: sl, tp_pct: tp,
                                
                                // Live tracking
                                pos: 0, avg_entry: 0, realized_pnl: 0,
                                trades_train: 0, trades_test: 0,
                                hist_pnl: [], is_rekt: false,
                                last_action_ts: 0
                            };
                            strategyCount++;
                        }
                    }
                }
            }
        }
    }
    
    console.log(`Analyzing ${rows.length} rows for ${strategyCount} strategies...`);
    const prevNet = {};

    for (const row of rows) {
        const btcPrice = findBtcPrice(row.timestamp);
        const ethPrice = findEthPrice(row.timestamp);
        if (!btcPrice || !ethPrice) continue;
        const priceMap = { BTC: btcPrice, ETH: ethPrice };
        const isTestPhase = row.timestamp >= splitTsStr;
        const currentTs = new Date(row.timestamp).getTime();
        
        const deltas = {};
        for (const g of GROUPS) {
            const longField = g.prefix ? `${g.prefix}long_vol_num` : 'long_vol_num';
            const shortField = g.prefix ? `${g.prefix}short_vol_num` : 'short_vol_num';
            const longVol = parseFloat(row[longField]);
            const shortVol = parseFloat(row[shortField]);
            if (isNaN(longVol) || longVol === 0) { deltas[g.id] = null; continue; }
            const currentNet = longVol - (isNaN(shortVol) ? 0 : shortVol);
            if (prevNet[g.id] === undefined) { prevNet[g.id] = currentNet; deltas[g.id] = null; continue; }
            deltas[g.id] = currentNet - prevNet[g.id];
            prevNet[g.id] = currentNet;
        }
        
        for (const key in strategies) {
            const st = strategies[key];
            if (st.is_rekt) continue; 
            
            const price = priceMap[st.instId];
            let equity = st.realized_pnl + st.pos * (price - st.avg_entry);
            
            if (equity < -CONFIG.INITIAL_MARGIN) {
                st.is_rekt = true;
                st.hist_pnl.push({ time: row.timestamp, pnl: -CONFIG.INITIAL_MARGIN, phase: isTestPhase ? 'test' : 'train' });
                continue;
            }
            
            // Check TP/SL first
            let closed = false;
            if (st.pos !== 0) {
                let closePrice = null;
                if (st.pos > 0) {
                    if (price <= st.avg_entry * (1 - st.sl_pct)) closePrice = st.avg_entry * (1 - st.sl_pct);
                    else if (price >= st.avg_entry * (1 + st.tp_pct)) closePrice = st.avg_entry * (1 + st.tp_pct);
                } else if (st.pos < 0) {
                    if (price >= st.avg_entry * (1 + st.sl_pct)) closePrice = st.avg_entry * (1 + st.sl_pct);
                    else if (price <= st.avg_entry * (1 - st.tp_pct)) closePrice = st.avg_entry * (1 - st.tp_pct);
                }
                
                if (closePrice !== null) {
                    const trade_units = -st.pos;
                    const feeUSD = Math.abs(trade_units * closePrice) * CONFIG.FEE_RATE;
                    st.realized_pnl -= feeUSD;
                    st.realized_pnl += st.pos * (closePrice - st.avg_entry);
                    st.pos = 0;
                    st.avg_entry = 0;
                    if (isTestPhase) st.trades_test++; else st.trades_train++;
                    closed = true;
                }
            }
            
            const deltaH = deltas[st.group.id];
            if (!closed && deltaH !== null && deltaH !== undefined) {
                if (Math.abs(deltaH) >= st.threshold) {
                    const orderUSD = CONFIG.FIXED_USD;
                    const sz = orderUSD / price;
                    
                    let ts_sign = (deltaH > 0) ? 1 : -1;
                    ts_sign *= st.direction;
                    const trade_units = sz * ts_sign;
                    
                    const new_total_pos = st.pos + trade_units;
                    const projectedValueUsd = Math.abs(new_total_pos * price);
                    
                    if (projectedValueUsd <= CONFIG.MAX_POS_USD || Math.abs(new_total_pos) < Math.abs(st.pos)) {
                        const feeUSD = orderUSD * CONFIG.FEE_RATE;
                        st.realized_pnl -= feeUSD;
                        
                        if (st.pos !== 0 && Math.sign(st.pos) !== Math.sign(trade_units)) {
                            if (Math.abs(trade_units) <= Math.abs(st.pos)) {
                                const close_val = -trade_units * (price - st.avg_entry);
                                st.realized_pnl += close_val;
                                st.pos += trade_units;
                            } else {
                                const closed_amt = Math.abs(st.pos);
                                const close_val = st.pos * (price - st.avg_entry);
                                st.realized_pnl += close_val;
                                
                                st.pos = new_total_pos;
                                st.avg_entry = price; 
                            }
                        } else {
                            const new_val = Math.abs(st.pos * st.avg_entry) + Math.abs(trade_units * price);
                            st.avg_entry = new_val / Math.abs(new_total_pos);
                            st.pos = new_total_pos;
                        }
                        
                        if (isTestPhase) st.trades_test++; else st.trades_train++;
                    }
                }
            }
            
            equity = st.realized_pnl + st.pos * (price - st.avg_entry);
            st.hist_pnl.push({ time: row.timestamp, pnl: equity, phase: isTestPhase ? 'test' : 'train' });
        }
    }
    
    console.log(`\\nEvaluating metrics...`);
    const results = [];
    for (const key in strategies) {
        const st = strategies[key];
        const trainHist = st.hist_pnl.filter(h => h.phase === 'train');
        const testHist = st.hist_pnl.filter(h => h.phase === 'test');
        
        const trainStart = rows[0].timestamp;
        const testStart = testHist.length > 0 ? testHist[0].time : splitTsStr;
        const testEnd = rows[rows.length-1].timestamp;
        
        const trainMetrics = computeMetrics(trainHist, trainStart, testStart);
        const testMetrics = computeMetrics(testHist, testStart, testEnd);
        
        results.push({
            key, 
            train: trainMetrics,
            test: testMetrics,
            tradesTrain: st.trades_train,
            tradesTest: st.trades_test,
            isRekt: st.is_rekt
        });
    }
    
    results.sort((a, b) => b.train.calmar - a.train.calmar);
    
    console.log(`\\n================== 🏆 TOP 15 IN-SAMPLE (TRAIN) STRATEGIES ==================`);
    console.log(`${'Strategy'.padEnd(46)} | ${'Trn PNL'.padStart(8)} | ${'Trn MaxDD'.padStart(9)} | ${'Trn Calmar'.padStart(10)} | ${'OOS PNL'.padStart(8)} | ${'OOS MaxDD'.padStart(9)} | ${'OOS Calmar'.padStart(10)}`);
    console.log('-'.repeat(120));
    for (let i = 0; i < 15; i++) {
        const r = results[i];
        if (!r) break;
        if (r.tradesTrain === 0) continue;
        const name = r.key.padEnd(46);
        console.log(`${name} | ` +
            `${(r.train.pnl >= 0 ? '+' : '') + r.train.pnl.toFixed(1)}`.padStart(8) + ` | ` +
            `${r.train.maxDd.toFixed(1)}`.padStart(9) + ` | ` +
            `${r.train.calmar.toFixed(1)}`.padStart(10) + ` | ` +
            `${(r.test.pnl >= 0 ? '+' : '') + r.test.pnl.toFixed(1)}`.padStart(8) + ` | ` +
            `${r.test.maxDd.toFixed(1)}`.padStart(9) + ` | ` +
            `${(r.isRekt ? '💥REKT' : r.test.calmar.toFixed(1))}`.padStart(10));
    }
    
    const oosHeroes = [...results].filter(r => !r.isRekt && r.test.tradesTest > 0).sort((a, b) => b.test.calmar - a.test.calmar).slice(0, 10);
    console.log(`\\n================== ⭐ BEST PERFORMANCE OUT-OF-SAMPLE (TEST) ==================`);
    for (const r of oosHeroes) {
        if (r.test.calmar <= 0) continue;
        console.log(`- ${r.key.padEnd(46)}: OOS PNL +$${r.test.pnl.toFixed(1)}, OOS MaxDD $${r.test.maxDd.toFixed(1)} (Calmar: ${r.test.calmar.toFixed(1)})`);
    }
}
main();
