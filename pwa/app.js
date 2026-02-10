/**
 * Hyperliquid Monitor — PWA Application Logic
 * Consumes the existing Cloudflare Worker API.
 */

// ============================================
// Configuration
// ============================================
const API_BASE = 'https://hyper-monitor-worker.bennytsai0711.workers.dev';
const POLL_INTERVAL = 10_000;
const ALERT_DURATION = 3_000;

// ============================================
// State
// ============================================
let allData = null; // Stores the full latest payload
let currentAsset = 'all'; // 'all' | 'hedge' | 'btc' | 'eth'
let selectedRange = '1h';
let historyData = { printer: [], btc: [], eth: [], hedge: [] };
let trendChart = null;
let pollTimer = null;

// Delta cache (keyed by asset type to persist independently)
const lastDeltas = {
  all: { net: null, long: null, short: null },
  hedge: { net: null, long: null, short: null },
  btc: { net: null, long: null, short: null },
  eth: { net: null, long: null, short: null }
};

// ============================================
// DOM References
// ============================================
const $ = (id) => document.getElementById(id);
const dom = {
  loading: $('loading-screen'),
  app: $('app'),
  sentimentBadge: $('sentiment-badge'),
  netLabel: $('net-label'),
  netValue: $('net-value'),
  netDelta: $('net-delta'),
  netCard: $('net-card'),
  lastUpdate: $('last-update'),
  alertFlash: $('alert-flash'),
  chartCanvas: $('trend-chart'),
  assetBtns: document.querySelectorAll('.asset-btn'),
  rangeSelect: $('range-select'),
};

// ============================================
// API Service
// ============================================
async function fetchLatest() {
  try {
    const res = await fetch(`${API_BASE}/latest`);
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    console.warn('Fetch latest failed:', e);
    return null;
  }
}

async function fetchHistory(range) {
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

// ============================================
// Data Helpers
// ============================================
function parseTimestamp(ts) {
  if (!ts) return new Date();
  let s = ts;
  if (!s.includes('T')) s = s.replace(' ', 'T');
  if (!s.endsWith('Z') && !/[+-]\d{2}:?\d{2}$/.test(s)) s += 'Z';
  const d = new Date(s);
  return new Date(d.getTime() + 8 * 60 * 60 * 1000); // UTC+8
}

function toNum(v) { return typeof v === 'number' ? v : parseFloat(v) || 0; }

function formatVolume(v) {
  const sign = v >= 0 ? '+' : '';
  const abs = Math.abs(v);
  if (abs >= 1e8) return `${sign}$${(v / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `${sign}$${(v / 1e4).toFixed(2)}萬`;
  return `${sign}$${v.toFixed(0)}`;
}

function formatCompact(v) {
  const abs = Math.abs(v);
  if (abs >= 1e8) return `${(v / 1e8).toFixed(2)}億`;
  if (abs >= 1e4) return `${(v / 1e4).toFixed(0)}萬`;
  return v.toFixed(0);
}

function isBearish(sentiment) {
  return (sentiment || '').includes('跌');
}

function getSentimentClass(text) {
  if (!text) return 'neutral';
  if (text.includes('非常')) return text.includes('跌') ? 'extreme-bearish' : 'extreme-bullish';
  if (text.includes('略')) return text.includes('跌') ? 'mild-bearish' : 'mild-bullish';
  if (text.includes('跌')) return 'bearish';
  if (text.includes('漲') || text.includes('涨')) return 'bullish';
  return 'neutral';
}

function padTime(n) { return String(n).padStart(2, '0'); }

// ============================================
// Logic: Extract Data by Asset Type
// ============================================
function extractData(rawData, assetType) {
    if (!rawData) return null;

    // Common fields
    const sentiment = rawData.sentiment;
    const timestamp = rawData.timestamp;

    let long, short;

    if (assetType === 'all') {
        long = toNum(rawData.long_vol_num ?? rawData.longVolNum);
        short = toNum(rawData.short_vol_num ?? rawData.shortVolNum);
    } else if (assetType === 'hedge') {
        const bLong = rawData.btc ? toNum(rawData.btc.long_vol) : 0;
        const bShort = rawData.btc ? toNum(rawData.btc.short_vol) : 0;
        const eLong = rawData.eth ? toNum(rawData.eth.long_vol) : 0;
        const eShort = rawData.eth ? toNum(rawData.eth.short_vol) : 0;
        long = bLong + eLong;
        short = bShort + eShort;
    } else if (assetType === 'btc') {
        long = rawData.btc ? toNum(rawData.btc.long_vol) : 0;
        short = rawData.btc ? toNum(rawData.btc.short_vol) : 0;
    } else if (assetType === 'eth') {
        long = rawData.eth ? toNum(rawData.eth.long_vol) : 0;
        short = rawData.eth ? toNum(rawData.eth.short_vol) : 0;
    }

    return { sentiment, timestamp, long, short };
}

// ============================================
// Delta Calculation
// ============================================
function calculateAllDeltas(oldData, newData) {
  let hasSignificant = false;

  const processAsset = (type) => {
      const o = extractData(oldData, type);
      const n = extractData(newData, type);
      if (!o || !n) return;

      const bearish = isBearish(n.sentiment);
      const oldNet = bearish ? (o.short - o.long) : (o.long - o.short);
      const newNet = bearish ? (n.short - n.long) : (n.long - n.short);

      const check = (vOld, vNew) => {
          const d = vNew - vOld;
          if (d === 0) return null;
          hasSignificant = true;
          const sign = d > 0 ? '+' : '-';
          const abs = Math.abs(d);
          let fmt;
          if (abs >= 1e8) fmt = `${(abs / 1e8).toFixed(2)}億`;
          else if (abs >= 1e4) fmt = `${(abs / 1e4).toFixed(0)}萬`;
          else fmt = abs.toFixed(0);
          return `${sign}$${fmt}`;
      };

      const nD = check(oldNet, newNet);
      if (nD) lastDeltas[type].net = nD;
  };

  ['all', 'hedge', 'btc', 'eth'].forEach(processAsset);

  if (hasSignificant) {
    triggerAlert();
  }
}

function triggerAlert() {
  if (navigator.vibrate) navigator.vibrate([100, 50, 100]);

  // Flash overlay
  dom.alertFlash.classList.remove('hidden');
  setTimeout(() => dom.alertFlash.classList.add('hidden'), ALERT_DURATION);

  // Rainbow border on card
  dom.netCard.classList.add('updating');
  setTimeout(() => dom.netCard.classList.remove('updating'), ALERT_DURATION);
}

// ============================================
// Render UI
// ============================================
function renderUI() {
    if (!allData) return;

    const data = extractData(allData, currentAsset);
    if (!data) return;

    const bearish = isBearish(data.sentiment);
    const netVal = bearish ? (data.short - data.long) : (data.long - data.short);

    // 1. Sentiment Badge
    const sClass = getSentimentClass(data.sentiment);
    dom.sentimentBadge.textContent = data.sentiment || '--';
    dom.sentimentBadge.className = sClass;

    // 2. Net Card (Hero)
    const assetNames = { all: '全體', hedge: '核心', btc: 'BTC', eth: 'ETH' };
    const name = assetNames[currentAsset];
    const typeLabel = bearish ? '淨空壓' : '淨多壓';

    dom.netLabel.textContent = `${name}${typeLabel}`;
    dom.netValue.textContent = formatVolume(netVal);

    // Color logic: Red for Bearish, Green for Bullish
    const sColor = bearish ? 'red' : 'green';
    dom.netValue.className = `metric-value ${sColor}`;

    // Border logic: matching sentiment
    // Ensure we keep 'hero-card' and 'metric-card' classes
    // We only toggle the border color class
    dom.netCard.className = `metric-card hero-card ${bearish ? 'bearish-border' : 'bullish-border'}`;

    // 3. Delta (Only Net Delta shown now)
    setDelta(dom.netDelta, lastDeltas[currentAsset].net, false);

    // 4. Timestamp
    const ts = parseTimestamp(data.timestamp);
    dom.lastUpdate.textContent = `最後更新: ${padTime(ts.getUTCHours())}:${padTime(ts.getUTCMinutes())}:${padTime(ts.getUTCSeconds())}`;

    // 5. Chart
    renderChart();
}

function setDelta(el, value, inverted) {
  if (!value) {
    el.className = 'metric-delta';
    el.textContent = '';
    return;
  }
  const isPositive = value.startsWith('+');
  el.textContent = value;
  // logic: positive delta = green, negative = red. Unless inverted (like short vol).
  // For net pressure: +$ value means pressure increased. So green if bullish pressure increased?
  // Actually simplest is: + is green, - is red.
  el.className = `metric-delta visible ${isPositive ? 'positive' : 'negative'}`;
}

// ============================================
// Chart
// ============================================
function renderChart() {
  const history = historyData[currentAsset] || [];

  if (!history || history.length === 0) {
    if (trendChart) trendChart.destroy();
    trendChart = null;
    return;
  }

  // Determine sentiment from current data to color the chart
  const bearish = allData ? isBearish(allData.sentiment) : false;

  const labels = [];
  const netData = [];

  history.forEach((item) => {
    // Determine timestamp source
    const rawTs = item.timestamp || item.time_bucket;
    labels.push(parseTimestamp(rawTs));

    let l = 0, s = 0;

    // Parse based on asset type structure in history
    if (currentAsset === 'all') {
        l = toNum(item.long_vol_num ?? item.longVolNum);
        s = toNum(item.short_vol_num ?? item.shortVolNum);
    } else if (currentAsset === 'hedge') {
        l = item.long_vol_num;
        s = item.short_vol_num;
    } else if (currentAsset === 'btc' || currentAsset === 'eth') {
        l = toNum(item.long_vol);
        s = toNum(item.short_vol);
    }

    netData.push(bearish ? (s - l) : (l - s));
  });

  const ctx = dom.chartCanvas.getContext('2d');
  if (trendChart) trendChart.destroy();

  trendChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: bearish ? '淨空壓' : '淨多壓',
          data: netData,
          borderColor: bearish ? '#FF2E2E' : '#00FF9D',
          backgroundColor: bearish ? 'rgba(255,46,46,0.08)' : 'rgba(0,255,157,0.08)',
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          pointHitRadius: 10,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 600 },
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { display: false }, // Hide legend to save space
        tooltip: {
            backgroundColor: 'rgba(0,0,0,0.85)',
            titleColor: '#fff',
            callbacks: {
                title: (items) => {
                    const d = items[0].label ? new Date(items[0].label) : new Date();
                    return `${padTime(d.getUTCHours())}:${padTime(d.getUTCMinutes())}`;
                },
                label: (ctx) => `淨壓: ${formatVolume(ctx.parsed.y)}`
            }
        }
      },
      scales: {
        x: {
          type: 'time',
          time: { displayFormats: { minute: 'HH:mm', hour: 'HH:mm', day: 'MM/dd' } },
          ticks: { color: 'rgba(255,255,255,0.25)', maxTicksLimit: 6 },
          grid: { color: 'rgba(255,255,255,0.04)' },
          border: { display: false },
        },
        y: {
          ticks: { color: 'rgba(255,255,255,0.25)', callback: (v) => formatVolume(v) },
          grid: { color: 'rgba(255,255,255,0.04)' },
          border: { display: false },
        },
      },
    },
  });
}

// ============================================
// Lifecycle & Events
// ============================================
async function pollLatest() {
  const newData = await fetchLatest();
  if (!newData) return;

  if (allData) {
    calculateAllDeltas(allData, newData);
  }
  allData = newData;
  renderUI();
}

async function loadHistory() {
  historyData = await fetchHistory(selectedRange);
  renderChart();
}

async function refreshAll() {
  await pollLatest();
  await loadHistory();
}

function initListeners() {
  // Asset Switcher
  dom.assetBtns.forEach(btn => {
      btn.addEventListener('click', () => {
          document.querySelector('.asset-btn.active')?.classList.remove('active');
          btn.classList.add('active');
          currentAsset = btn.dataset.asset;
          renderUI();
      });
  });

  // Range Switcher (Dropdown)
  if (dom.rangeSelect) {
      dom.rangeSelect.addEventListener('change', (e) => {
          selectedRange = e.target.value;
          loadHistory();
      });
  }
}

// ============================================
// Boot
// ============================================
async function boot() {
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(console.warn);

  initListeners();

  // Initial load
  await refreshAll();

  dom.loading.classList.add('hidden');
  dom.app.classList.remove('hidden');

  pollTimer = setInterval(pollLatest, POLL_INTERVAL);

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) clearInterval(pollTimer);
    else {
      refreshAll();
      pollTimer = setInterval(pollLatest, POLL_INTERVAL);
    }
  });
}

boot();

