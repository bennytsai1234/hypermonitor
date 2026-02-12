/**
 * Hyperliquid Monitor — PWA Application Logic
 * Modularized Structure
 */

import { POLL_INTERVAL } from './js/config.js';
import { fetchLatest, fetchHistory, onConnectionStatusChange } from './js/api.js';
import { renderChart } from './js/chart.js';
import { renderUI, calculateAllDeltas, toggleMute, showApp, getDom, initUi, updateConnectionStatus, requestNotificationPermission } from './js/ui.js';

// Global State
let allData = null;
let currentAsset = 'all';
let selectedRange = '1h';
let historyData = { printer: [], btc: [], eth: [], hedge: [] };
let pollTimer = null;

// ============================================
// Logic
// ============================================
async function pollLatest() {
  const newData = await fetchLatest();
  if (!newData) return;

  if (allData) {
    calculateAllDeltas(allData, newData);
  }
  allData = newData;
  render();
}

async function loadHistory() {
  historyData = await fetchHistory(selectedRange);
  render();
}

async function refreshAll() {
  await pollLatest();
  await loadHistory();
}

function render() {
    renderUI(allData, currentAsset, () => {
        const dom = getDom();
        renderChart(dom.chartCanvas, historyData, currentAsset, allData, selectedRange);
    });
}

// ============================================
// Event Listeners
// ============================================
function initListeners() {
  const dom = getDom();

  // Asset Switcher
  dom.assetBtns.forEach(btn => {
      btn.addEventListener('click', () => {
          document.querySelector('.asset-btn.active')?.classList.remove('active');
          btn.classList.add('active');
          currentAsset = btn.dataset.asset;
          render();
      });
  });

  // Mute Toggle
  if (dom.muteBtn) {
      dom.muteBtn.addEventListener('click', toggleMute);
  }

  // Range Switcher (Custom Dropdown)
  const dd = document.getElementById('range-dropdown');
  if (dd) {
      const trigger = dd.querySelector('.dropdown-trigger');
      const selectedText = dd.querySelector('.selected-text');
      const items = dd.querySelectorAll('.dropdown-item');

      // Restore from storage
      const saved = localStorage.getItem('hyper_range') || '1h';
      selectedRange = saved;

      // Update UI to match saved state
      const savedItem = Array.from(items).find(i => i.dataset.value === saved);
      if (savedItem) {
          selectedText.textContent = savedItem.textContent;
          items.forEach(i => i.classList.remove('active'));
          savedItem.classList.add('active');
      }

      // Toggle Menu
      trigger.addEventListener('click', (e) => {
          e.stopPropagation();
          dd.classList.toggle('open');
      });

      // Handle Selection
      items.forEach(item => {
          item.addEventListener('click', (e) => {
              e.stopPropagation();
              const val = item.dataset.value;

              if (val === selectedRange) {
                  dd.classList.remove('open');
                  return;
              }

              selectedRange = val;
              localStorage.setItem('hyper_range', val);

              // UI Update
              selectedText.textContent = item.textContent;
              items.forEach(i => i.classList.remove('active'));
              item.classList.add('active');

              dd.classList.remove('open');
              loadHistory();
          });
      });

      // Close when clicking outside
      document.addEventListener('click', () => {
          dd.classList.remove('open');
      });
  }
}

// ============================================
// Pull to Refresh
// ============================================
function initPullToRefresh() {
    const content = document.getElementById('content');
    const ptr = document.getElementById('ptr-indicator');
    if (!content || !ptr) return;

    let startY = 0;
    let pulling = false;
    const THRESHOLD = 60;

    content.addEventListener('touchstart', (e) => {
        if (content.scrollTop <= 0) {
            startY = e.touches[0].clientY;
            pulling = true;
        }
    }, { passive: true });

    content.addEventListener('touchmove', (e) => {
        if (!pulling) return;
        const dy = e.touches[0].clientY - startY;
        if (dy > 0 && dy < 120) {
            ptr.style.height = `${Math.min(dy * 0.6, THRESHOLD)}px`;
            ptr.style.opacity = String(Math.min(dy / THRESHOLD, 1));
            ptr.classList.remove('ptr-hidden');
            const ptrText = ptr.querySelector('.ptr-text');
            if (dy > THRESHOLD) {
                if (ptrText) ptrText.textContent = '釋放刷新';
                ptr.classList.add('ptr-ready');
            } else {
                if (ptrText) ptrText.textContent = '下拉刷新';
                ptr.classList.remove('ptr-ready');
            }
        }
    }, { passive: true });

    content.addEventListener('touchend', async () => {
        if (!pulling) return;
        pulling = false;
        if (ptr.classList.contains('ptr-ready')) {
            const ptrText = ptr.querySelector('.ptr-text');
            if (ptrText) ptrText.textContent = '刷新中...';
            ptr.classList.add('ptr-loading');
            await refreshAll();
            ptr.classList.remove('ptr-loading');
        }
        setTimeout(() => {
            ptr.style.height = '0';
            ptr.style.opacity = '0';
            ptr.classList.add('ptr-hidden');
            ptr.classList.remove('ptr-ready');
        }, 200);
    });
}

// ============================================
// Boot
// ============================================
async function boot() {
  if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').then(reg => {
          reg.update(); // Force update check
      }).catch(console.warn);
  }

  initUi();
  initListeners();
  initPullToRefresh();

  // Connection status listener
  onConnectionStatusChange(updateConnectionStatus);

  // Request notification permission
  requestNotificationPermission();

  // Initial load
  await refreshAll();
  showApp();

  // Use Web Worker for background timing
  if (window.Worker) {
      const pollWorker = new Worker('timer.worker.js');
      pollWorker.onmessage = (e) => {
          if (e.data === 'tick') pollLatest();
      };
      pollWorker.postMessage({ action: 'start', interval: POLL_INTERVAL });
  } else {
      // Fallback for older browsers
      pollTimer = setInterval(pollLatest, POLL_INTERVAL);
  }

  // Optional: You can still use visibilitychange to limit frequency if needed,
  // but for "background play", we keep it running.
  document.addEventListener('visibilitychange', () => {
      // Logic for reconnecting if needed, but worker keeps ticking
      if (!document.hidden) {
          refreshAll();
      }
  });
}

boot();
