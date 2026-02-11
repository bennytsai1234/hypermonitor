import { API_BASE } from './config.js';

export async function fetchLatest() {
  try {
    const res = await fetch(`${API_BASE}/latest`);
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    console.warn('Fetch latest failed:', e);
    return null;
  }
}

export async function fetchHistory(range) {
  try {
    const res = await fetch(`${API_BASE}/history?range=${range}`);
    if (!res.ok) return { printer: [], btc: [], eth: [], hedge: [] };
    const data = await res.json();

    // Calculate Hedge history (BTC + ETH) client-side
    const hedge = [];
    const btc = data.btc || [];
    const eth = data.eth || [];
    const len = Math.min(btc.length, eth.length);

    for(let i=0; i<len; i++) {
        const b = btc[i];
        const e = eth[i];
        hedge.push({
            timestamp: b.timestamp,
            long_vol_num: (b.long_vol ?? 0) + (e.long_vol ?? 0),
            short_vol_num: (b.short_vol ?? 0) + (e.short_vol ?? 0),
        });
    }

    return {
        printer: data.printer || [],
        btc: btc,
        eth: eth,
        hedge: hedge
    };
  } catch (e) {
    console.warn('Fetch history failed:', e);
    return { printer: [], btc: [], eth: [], hedge: [] };
  }
}
