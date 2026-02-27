import { API_BASE } from './config.js';

const LATEST_CACHE_KEY = 'hyper_latest_cache';
const HISTORY_CACHE_PREFIX = 'hyper_history_';

let _connectionStatus = 'online';
let _statusListeners = [];

export function getConnectionStatus() { return _connectionStatus; }
export function onConnectionStatusChange(cb) { _statusListeners.push(cb); }

function setStatus(status) {
  if (_connectionStatus !== status) {
    _connectionStatus = status;
    _statusListeners.forEach(cb => cb(status));
  }
}

export async function fetchLatest() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout
    const res = await fetch(`${API_BASE}/latest`, { signal: controller.signal });
    clearTimeout(timeoutId);
    if (!res.ok) {
      setStatus('error');
      return loadCachedLatest();
    }
    const data = await res.json();
    setStatus('online');
    try { localStorage.setItem(LATEST_CACHE_KEY, JSON.stringify(data)); } catch (e) { }
    return data;
  } catch (e) {
    console.warn('Fetch latest failed:', e);
    setStatus(e.name === 'AbortError' ? 'error' : 'offline');
    return loadCachedLatest();
  }
}

function loadCachedLatest() {
  try {
    const cached = localStorage.getItem(LATEST_CACHE_KEY);
    return cached ? JSON.parse(cached) : null;
  } catch (e) { return null; }
}

export async function fetchHistory(range) {
  const cacheKey = HISTORY_CACHE_PREFIX + range;

  // Map frontend ranges to backend expectations
  let apiRange = range;
  if (range === '1d') apiRange = '24h';
  if (range === '1w') apiRange = '7d';

  try {
    const res = await fetch(`${API_BASE}/history?range=${apiRange}`);
    if (!res.ok) return loadCachedHistory(cacheKey);
    const data = await res.json();

    const hedge = [];
    const btc = data.btc || [];
    const eth = data.eth || [];
    const len = Math.min(btc.length, eth.length);
    for (let i = 0; i < len; i++) {
      const b = btc[i];
      const e = eth[i];
      hedge.push({
        timestamp: b.timestamp,
        long_vol_num: (b.long_vol !== undefined && b.long_vol !== null ? b.long_vol : 0) + (e.long_vol !== undefined && e.long_vol !== null ? e.long_vol : 0),
        short_vol_num: (b.short_vol !== undefined && b.short_vol !== null ? b.short_vol : 0) + (e.short_vol !== undefined && e.short_vol !== null ? e.short_vol : 0),
      });

    }

    const result = {
      printer: data.printer || [],
      smart: data.printer || [],
      grinder: data.printer || [],
      humble: data.printer || [],
      exitLiq: data.printer || [],
      semiRekt: data.printer || [],
      fullRekt: data.printer || [],
      gigaRekt: data.printer || [],
      btc, eth, hedge
    };
    try { sessionStorage.setItem(cacheKey, JSON.stringify(result)); } catch (e) { }
    return result;
  } catch (e) {
    console.warn('Fetch history failed:', e);
    return loadCachedHistory(cacheKey);
  }
}

function loadCachedHistory(cacheKey) {
  try {
    const cached = sessionStorage.getItem(cacheKey);
    return cached ? JSON.parse(cached) : {
      printer: [], smart: [], grinder: [], humble: [],
      exitLiq: [], semiRekt: [], fullRekt: [], gigaRekt: [],
      btc: [], eth: [], hedge: []
    };
  } catch (e) {
    return {
      printer: [], smart: [], grinder: [], humble: [],
      exitLiq: [], semiRekt: [], fullRekt: [], gigaRekt: [],
      btc: [], eth: [], hedge: []
    };
  }
}
