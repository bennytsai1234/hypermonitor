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
    const res = await fetch(`${API_BASE}/latest`);
    if (!res.ok) {
      setStatus('error');
      return loadCachedLatest();
    }
    const data = await res.json();
    setStatus('online');
    try { localStorage.setItem(LATEST_CACHE_KEY, JSON.stringify(data)); } catch(e) {}
    return data;
  } catch (e) {
    console.warn('Fetch latest failed:', e);
    setStatus('offline');
    return loadCachedLatest();
  }
}

function loadCachedLatest() {
  try {
    const cached = localStorage.getItem(LATEST_CACHE_KEY);
    return cached ? JSON.parse(cached) : null;
  } catch(e) { return null; }
}

export async function fetchHistory(range) {
  const cacheKey = HISTORY_CACHE_PREFIX + range;
  try {
    const res = await fetch(`${API_BASE}/history?range=${range}`);
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
        long_vol_num: (b.long_vol ?? 0) + (e.long_vol ?? 0),
        short_vol_num: (b.short_vol ?? 0) + (e.short_vol ?? 0),
      });
    }

    const result = { printer: data.printer || [], btc, eth, hedge };
    try { sessionStorage.setItem(cacheKey, JSON.stringify(result)); } catch(e) {}
    return result;
  } catch (e) {
    console.warn('Fetch history failed:', e);
    return loadCachedHistory(cacheKey);
  }
}

function loadCachedHistory(cacheKey) {
  try {
    const cached = sessionStorage.getItem(cacheKey);
    return cached ? JSON.parse(cached) : { printer: [], btc: [], eth: [], hedge: [] };
  } catch(e) { return { printer: [], btc: [], eth: [], hedge: [] }; }
}
