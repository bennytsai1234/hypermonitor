/**
 * Utility functions for parsing and formatting
 */

export function parseTimestamp(ts) {
  if (!ts) return new Date();
  let s = ts;
  if (!s.includes('T')) s = s.replace(' ', 'T');
  if (!s.endsWith('Z') && !/[+-]\d{2}:?\d{2}$/.test(s)) s += 'Z';
  return new Date(s);
}

export function toNum(v) { return typeof v === 'number' ? v : parseFloat(v) || 0; }

export function formatVolume(v) {
  const sign = v >= 0 ? '+' : '';
  const abs = Math.abs(v);
  if (abs >= 1e8) return `${sign}$${(v / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `${sign}$${(v / 1e4).toFixed(2)}萬`;
  return `${sign}$${v.toFixed(0)}`;
}

export function formatAbsVolume(v) {
  const abs = Math.abs(v);
  if (abs >= 1e8) return `$${(abs / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `$${(abs / 1e4).toFixed(2)}萬`;
  return `$${abs.toFixed(0)}`;
}

export function formatCompact(v) {
  const abs = Math.abs(v);
  if (abs >= 1e8) return `${(v / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `${(v / 1e4).toFixed(0)}萬`;
  return v.toFixed(0);
}

export function isBearish(sentiment) {
  return (sentiment || '').includes('跌');
}

export function getSentimentClass(text) {
  if (!text) return 'neutral';
  if (text.includes('非常')) return text.includes('跌') ? 'extreme-bearish' : 'extreme-bullish';
  if (text.includes('略')) return text.includes('跌') ? 'mild-bearish' : 'mild-bullish';
  if (text.includes('跌')) return 'bearish';
  if (text.includes('漲') || text.includes('涨')) return 'bullish';
  return 'neutral';
}

export function padTime(n) { return String(n).padStart(2, '0'); }

// State helper to extract data
export function extractData(rawData, assetType) {
    if (!rawData) return null;

    // Common fields
    const sentiment = rawData.sentiment;
    const timestamp = rawData.timestamp;

    let long = 0, short = 0;

    // Helper to safely get volume (handles camelCase and snake_case)
    const getVol = (obj, type) => {
        if (!obj) return 0;
        return toNum(obj[`${type}Vol`] ?? obj[`${type}_vol`] ?? 0);
    };

    if (assetType === 'all') {
        long = getVol(rawData, 'long');
        short = getVol(rawData, 'short');
        // Legacy fallback if root object uses _num suffix
        if (long === 0) long = toNum(rawData.long_vol_num ?? rawData.longVolNum);
        if (short === 0) short = toNum(rawData.short_vol_num ?? rawData.shortVolNum);
    } else if (assetType === 'hedge') {
        const bLong = getVol(rawData.btc, 'long');
        const bShort = getVol(rawData.btc, 'short');
        const eLong = getVol(rawData.eth, 'long');
        const eShort = getVol(rawData.eth, 'short');
        long = bLong + eLong;
        short = bShort + eShort;
    } else if (assetType === 'btc') {
        long = getVol(rawData.btc, 'long');
        short = getVol(rawData.btc, 'short');
    } else if (assetType === 'eth') {
        long = getVol(rawData.eth, 'long');
        short = getVol(rawData.eth, 'short');
    }

    return { sentiment, timestamp, long, short };
}
