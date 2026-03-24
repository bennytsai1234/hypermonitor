/**
 * Hypermonitor Backtest v6: Train/Test Split & Risk Simulation
 * 
 * - 80% In-Sample (Train) / 20% Out-of-Sample (Test)
 * - Added Realistic Liquidation (爆倉判定) if margin drops too low.
 * - Added Max Position Limit (最大持倉卡控) to prevent infinite accumulation.
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
    INITIAL_MARGIN: 1000, 
    MARGIN_REQ: 0.1,      // 10x leverage means 10% movement = 100% margin loss
    MAX_POS_USD: 500,     // Max holding value to prevent infinite stacking
    TRAIN_RATIO: 0.8
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
        // Simple rekt check
        if (p.pnl < startPnl - CONFIG.INITIAL_MARGIN) {
            isRekt = true;
        }
    }
    
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
    console.log('║     Hypermonitor Backtest v6: Train/Test Split           ║');
    console.log('║     320 Configurations | 80% In-Sample, 20% Out-of-Sample║');
    console.log('╚══════════════════════════════════════════════════════════╝\\n');
    
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
    
    if (rows.length === 0) return;
    
    const firstTs = new Date(rows[0].timestamp).getTime();
    const lastTs = new Date(rows[rows.length-1].timestamp).getTime();
    const splitTsMs = firstTs + (lastTs - firstTs) * CONFIG.TRAIN_RATIO;
    const splitTsStr = new Date(splitTsMs).toISOString().slice(0, 19).replace('T', ' ');
    
    console.log(`Dataset Total : ${rows[0].timestamp} -> ${rows[rows.length-1].timestamp}`);
    console.log(`Train Phase   : ${rows[0].timestamp} -> ${splitTsStr} (${CONFIG.TRAIN_RATIO*100}%)`);
    console.log(`Test Phase    : ${splitTsStr} -> ${rows[rows.length-1].timestamp} (${(1-CONFIG.TRAIN_RATIO)*100}%)`);
    console.log(`Constraints   : Max Position $${CONFIG.MAX_POS_USD}\\n`);
    
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
                            pos: 0, realized_pnl: 0, trades_train: 0, trades_test: 0,
                            hist_pnl: [], is_rekt: false
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
        const isTestPhase = row.timestamp >= splitTsStr;
        
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
            if (st.is_rekt) continue; 
            
            const price = priceMap[st.instId];
            const deltaH = deltas[st.group.id];
            
            let equity = st.realized_pnl + (st.pos * price);
            
            // Liquidation
            if (equity < -CONFIG.INITIAL_MARGIN) {
                st.is_rekt = true;
                st.hist_pnl.push({ time: row.timestamp, pnl: -CONFIG.INITIAL_MARGIN, phase: isTestPhase ? 'test' : 'train' });
                continue;
            }
            
            if (deltaH !== null && deltaH !== undefined) {
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
                    
                    const projectedPos = st.pos + trade_units;
                    const projectedValueUsd = Math.abs(projectedPos * price);
                    
                    // Limit max absolute position
                    if (projectedValueUsd <= CONFIG.MAX_POS_USD || Math.abs(projectedPos) < Math.abs(st.pos)) {
                        st.realized_pnl -= feeUSD;
                        st.pos += trade_units;
                        st.realized_pnl -= (trade_units * price);
                        
                        if (isTestPhase) st.trades_test++;
                        else st.trades_train++;
                    }
                }
            }
            
            equity = st.realized_pnl + (st.pos * price);
            st.hist_pnl.push({ time: row.timestamp, pnl: equity, phase: isTestPhase ? 'test' : 'train' });
        }
    }
    
    console.log(`\\nEvaluating Train and Test Phase metrics...`);
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
            typeStr: `${st.threshold/1000000}M_${st.mode}`,
            tradesTrain: st.trades_train,
            tradesTest: st.trades_test,
            isRekt: st.is_rekt
        });
    }
    
    results.sort((a, b) => b.train.calmar - a.train.calmar);
    
    console.log(`\\n================== 🏆 TOP 15 IN-SAMPLE (TRAIN) STRATEGIES ==================`);
    console.log(`${'Strategy'.padEnd(35)} | ${'Train PNL'.padStart(10)} | ${'Train MaxDD'.padStart(11)} | ${'Trn Calmar'.padStart(10)} | ${'OOS(Test) PNL'.padStart(13)} | ${'OOS MaxDD'.padStart(10)} | ${'OOS Calmar'.padStart(11)}`);
    console.log('-'.repeat(110));
    
    for (let i = 0; i < 15; i++) {
        const r = results[i];
        if (!r) break;
        if (r.tradesTrain === 0) continue;
        
        const name = r.key.padEnd(35);
        const tPnl = (r.train.pnl >= 0 ? '+' : '') + r.train.pnl.toFixed(1);
        const tDd = r.train.maxDd.toFixed(1);
        const tCalmar = r.train.calmar.toFixed(1);
        
        const oosPnl = (r.test.pnl >= 0 ? '+' : '') + r.test.pnl.toFixed(1);
        const oosDd = r.test.maxDd.toFixed(1);
        let oosCalmar = r.test.calmar.toFixed(1);
        if (r.isRekt) oosCalmar = '💥REKT';
        
        console.log(`${name} | ${tPnl.padStart(10)} | ${tDd.padStart(11)} | ${tCalmar.padStart(10)} | ${oosPnl.padStart(13)} | ${oosDd.padStart(10)} | ${oosCalmar.padStart(11)}`);
    }
    
    const oosHeroes = [...results].filter(r => !r.isRekt && r.test.tradesTest > 0).sort((a, b) => b.test.calmar - a.test.calmar).slice(0, 5);
    console.log(`\\n================== ⭐ BEST PERFORMANCE OUT-OF-SAMPLE (TEST) ==================`);
    console.log(`Strategies that actually worked on unseen data:`);
    for (const r of oosHeroes) {
        if (r.test.calmar <= 0) continue;
        console.log(`- ${r.key.padEnd(35)}: OOS PNL +$${r.test.pnl.toFixed(1)}, OOS MaxDD $${r.test.maxDd.toFixed(1)} (Calmar: ${r.test.calmar.toFixed(1)})`);
    }
}

main();
