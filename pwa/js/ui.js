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
        connStatus: $('conn-status'),
    };

    if (dom.muteBtn) {
        updateMuteIcon();
    }
}

// State for alerts
const lastDeltas = {
  all: { net: null }, hedge: { net: null },
  btc: { net: null }, eth: { net: null }
};

let isMuted = localStorage.getItem('hyper_muted') === 'true';
const alertAudio = new Audio(ALERT_SOUND);

// ============================================
// Connection Status
// ============================================
export function updateConnectionStatus(status) {
    if (!dom.connStatus) return;
    dom.connStatus.className = `conn-dot ${status}`;
    dom.connStatus.title = status === 'online' ? '已連線' : status === 'offline' ? '離線中' : '連線異常';

    if (status !== 'online' && dom.lastUpdate) {
        const currentText = dom.lastUpdate.textContent;
        if (!currentText.includes('離線')) {
            dom.lastUpdate.textContent = `⚠ 離線模式 · ${currentText}`;
        }
    }
}

// ============================================
// Web Notifications
// ============================================
let notifPermission = (typeof Notification !== 'undefined') ? Notification.permission : 'denied';

export async function requestNotificationPermission() {
    if (!('Notification' in window)) return 'denied';
    if (Notification.permission === 'granted') {
        notifPermission = 'granted';
        return 'granted';
    }
    if (Notification.permission !== 'denied') {
        const result = await Notification.requestPermission();
        notifPermission = result;
        return result;
    }
    return 'denied';
}

function sendNotification(title, body) {
    if (notifPermission !== 'granted') return;
    if (!document.hidden) return; // Only when in background
    try {
        const n = new Notification(title, {
            body, icon: 'icons/icon.svg', badge: 'icons/icon.svg',
            tag: 'hyper-alert', renotify: true, silent: isMuted,
        });
        n.onclick = () => { window.focus(); n.close(); };
        setTimeout(() => n.close(), 10000);
    } catch(e) { console.warn('Notification failed:', e); }
}

// ============================================
// Mute Toggle
// ============================================
function updateMuteIcon() {
    if (!dom.muteBtn) return;
    const icon = dom.muteBtn.querySelector('.icon');
    if (!icon) return;
    if (isMuted) {
        dom.muteBtn.classList.remove('active');
        icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5L6 9H2v6h4l5 4V5z"></path><line x1="23" y1="9" x2="17" y2="15"></line><line x1="17" y1="9" x2="23" y2="15"></line></svg>`;
    } else {
        dom.muteBtn.classList.add('active');
        icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path><path d="M19.07 4.93a10 10 0 0 1 0 14.14"></path></svg>`;
    }
}

export function toggleMute() {
    isMuted = !isMuted;
    localStorage.setItem('hyper_muted', isMuted);
    updateMuteIcon();
    if (!isMuted) {
        alertAudio.currentTime = 0;
        alertAudio.play().catch(() => {});
    }
    // Request notification permission on first unmute (requires user gesture)
    if (!isMuted && notifPermission === 'default') {
        requestNotificationPermission();
    }
}

// ============================================
// Show App (with fade-in)
// ============================================
export function showApp() {
    dom.loading.classList.add('hidden');
    dom.app.classList.remove('hidden');
    requestAnimationFrame(() => {
        dom.app.classList.add('visible');
    });
}

export function getDom() { return dom; }

// ============================================
// Alert System
// ============================================
export function triggerAlert(playAudio = true) {
  if (navigator.vibrate) navigator.vibrate([100, 50, 100]);
  dom.alertFlash.classList.remove('hidden');
  setTimeout(() => dom.alertFlash.classList.add('hidden'), ALERT_DURATION);
  dom.netCard.classList.add('updating');
  setTimeout(() => dom.netCard.classList.remove('updating'), ALERT_DURATION);
  if (playAudio && !isMuted) {
      alertAudio.currentTime = 0;
      alertAudio.play().catch(e => console.log('Audio play blocked:', e));
  }
}

function setDelta(el, value, isBearishMode) {
  if (!value) { el.className = 'metric-delta'; el.textContent = ''; return; }
  const isPositive = value.startsWith('+');
  let isGood = isPositive;
  if (isBearishMode) isGood = !isPositive;
  el.textContent = value;
  el.className = `metric-delta visible ${isGood ? 'positive' : 'negative'}`;
}

// ============================================
// Value Animation
// ============================================
function animateValue(el, newText) {
    if (el.textContent === newText || el.textContent === '--') {
        el.textContent = newText;
        return;
    }
    el.classList.add('value-updating');
    el.textContent = newText;
    setTimeout(() => el.classList.remove('value-updating'), 400);
}

// ============================================
// Delta Calculation + Notification
// ============================================
export function calculateAllDeltas(oldData, newData) {
    let hasSignificant = false;
    let shouldPlayAudio = false;
    let notifBody = '';

    const processAsset = (type) => {
        const o = extractData(oldData, type);
        const n = extractData(newData, type);
        if (!o || !n) return;
        const bearish = isBearish(n.sentiment);
        const oldNet = bearish ? (o.short - o.long) : (o.long - o.short);
        const newNet = bearish ? (n.short - n.long) : (n.long - n.short);

        const d = newNet - oldNet;
        if (d === 0) return;
        hasSignificant = true;

        if (type === 'all') {
            shouldPlayAudio = true;
            const sign = d > 0 ? '📈 +' : '📉 ';
            const abs = Math.abs(d);
            let fmt;
            if (abs >= 1e8) fmt = `${(abs / 1e8).toFixed(2)}億`;
            else if (abs >= 1e4) fmt = `${(abs / 1e4).toFixed(0)}萬`;
            else fmt = abs.toFixed(0);
            const label = bearish ? '淨空壓' : '淨多壓';
            notifBody = `${label}: ${sign}$${fmt}`;
        }

        const sign = d > 0 ? '+' : '-';
        const abs = Math.abs(d);
        let fmt;
        if (abs >= 1e8) fmt = `${(abs / 1e8).toFixed(2)}億`;
        else if (abs >= 1e4) fmt = `${(abs / 1e4).toFixed(0)}萬`;
        else fmt = abs.toFixed(0);
        lastDeltas[type].net = `${sign}$${fmt}`;
    };

    ['all', 'hedge', 'btc', 'eth'].forEach(processAsset);

    if (hasSignificant) {
      triggerAlert(shouldPlayAudio);
      // Web Notification for 'all' changes when app is in background
      if (shouldPlayAudio && notifBody) {
        sendNotification('⚡ HyperMonitor 資金變動', notifBody);
      }
    }
}

// ============================================
// Render UI
// ============================================
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

    // 2. Net Card
    const assetNames = { all: '全體', hedge: '核心', btc: 'BTC', eth: 'ETH' };
    const name = assetNames[currentAsset];
    const typeLabel = bearish ? '淨空壓' : '淨多壓';
    dom.netLabel.textContent = `${name}${typeLabel}`;
    animateValue(dom.netValue, formatVolume(netVal));
    animateValue(dom.longVal, formatAbsVolume(data.long));
    animateValue(dom.shortVal, formatAbsVolume(data.short));

    const sColor = bearish ? 'red' : 'green';
    dom.netValue.className = `metric-value ${sColor}`;
    dom.netCard.className = `metric-card hero-card ${bearish ? 'bearish-border' : 'bullish-border'}`;

    // 3. Delta
    setDelta(dom.netDelta, lastDeltas[currentAsset].net, bearish);

    // 4. Timestamp
    const ts = parseTimestamp(data.timestamp);
    dom.lastUpdate.textContent = `最後更新: ${padTime(ts.getHours())}:${padTime(ts.getMinutes())}:${padTime(ts.getSeconds())}`;

    // 5. Chart
    if (renderChartCallback) renderChartCallback();
}
