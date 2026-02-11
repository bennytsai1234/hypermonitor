import {
    extractData,
    isBearish,
    getSentimentClass,
    formatVolume,
    formatAbsVolume,
    parseTimestamp,
    padTime
} from './utils.js';
import { ALERT_DURATION, ALERT_SOUND } from './config.js';

// DOM Cache
const $ = (id) => document.getElementById(id);

let dom = {};

export function initUi() {
    dom = {
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
        longVal: $('long-val'),
        shortVal: $('short-val'),
        muteBtn: $('mute-btn'),
    };

    // Set initial mute UI
    if (dom.muteBtn) {
        updateMuteIcon();
    }
}

// State for alerts
const lastDeltas = {
  all: { net: null, long: null, short: null },
  hedge: { net: null, long: null, short: null },
  btc: { net: null, long: null, short: null },
  eth: { net: null, long: null, short: null }
};

let isMuted = localStorage.getItem('hyper_muted') === 'true';
const alertAudio = new Audio(ALERT_SOUND);

// Removed top-level init call

function updateMuteIcon() {
    if (!dom.muteBtn) return;
    const icon = dom.muteBtn.querySelector('.icon');
    if (!icon) return;

    if (isMuted) {
        dom.muteBtn.classList.remove('active');
        // Simple Mute SVG
        icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5L6 9H2v6h4l5 4V5z"></path><line x1="23" y1="9" x2="17" y2="15"></line><line x1="17" y1="9" x2="23" y2="15"></line></svg>`;
    } else {
        dom.muteBtn.classList.add('active');
        // Simple Volume SVG
        icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path><path d="M19.07 4.93a10 10 0 0 1 0 14.14"></path></svg>`;
    }
}

export function toggleMute() {
    isMuted = !isMuted;
    localStorage.setItem('hyper_muted', isMuted);
    updateMuteIcon();

    if (!isMuted) {
        alertAudio.currentTime = 0; // Preload/Test
        alertAudio.play().catch(() => {});
    }
}

export function showApp() {
    dom.loading.classList.add('hidden');
    dom.app.classList.remove('hidden');
}

export function getDom() { return dom; }

export function triggerAlert() {
  if (navigator.vibrate) navigator.vibrate([100, 50, 100]);

  // Flash overlay
  dom.alertFlash.classList.remove('hidden');
  setTimeout(() => dom.alertFlash.classList.add('hidden'), ALERT_DURATION);

  // Rainbow border on card
  dom.netCard.classList.add('updating');
  setTimeout(() => dom.netCard.classList.remove('updating'), ALERT_DURATION);

  // Play Sound
  if (!isMuted) {
      alertAudio.currentTime = 0;
      alertAudio.play().catch(e => console.log('Audio play blocked:', e));
  }
}

function setDelta(el, value, isBearishMode) {
  if (!value) {
    el.className = 'metric-delta';
    el.textContent = '';
    return;
  }
  const isPositive = value.startsWith('+');

  // Logical Color Mapping:
  // Bullish Mode (Net Long): Increase (+) is Good (Green), Decrease (-) is Bad (Red)
  // Bearish Mode (Net Short): Increase (+) is Bad (Red), Decrease (-) is Good (Green)
  let isGood = isPositive;
  if (isBearishMode) {
      isGood = !isPositive;
  }

  el.textContent = value;
  // Map 'positive' class to Green, 'negative' class to Red
  el.className = `metric-delta visible ${isGood ? 'positive' : 'negative'}`;
}

export function calculateAllDeltas(oldData, newData) {
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

export function renderUI(allData, currentAsset, renderChartCallback) {
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
    dom.longVal.textContent = formatAbsVolume(data.long);
    dom.shortVal.textContent = formatAbsVolume(data.short);

    // Color logic: Red for Bearish, Green for Bullish
    const sColor = bearish ? 'red' : 'green';
    dom.netValue.className = `metric-value ${sColor}`;

    // Border logic: matching sentiment
    dom.netCard.className = `metric-card hero-card ${bearish ? 'bearish-border' : 'bullish-border'}`;

    // 3. Delta
    setDelta(dom.netDelta, lastDeltas[currentAsset].net, bearish);

    // 4. Timestamp
    const ts = parseTimestamp(data.timestamp);
    dom.lastUpdate.textContent = `最後更新: ${padTime(ts.getHours())}:${padTime(ts.getMinutes())}:${padTime(ts.getSeconds())}`;

    // 5. Chart
    if (renderChartCallback) renderChartCallback();
}
