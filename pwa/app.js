/**
 * Hyperliquid Monitor — PWA Application Logic
 * Modularized Structure
 */

import { POLL_INTERVAL } from './js/config.js';
import { fetchLatest, fetchHistory } from './js/api.js';
import { renderChart } from './js/chart.js';
import { renderUI, calculateAllDeltas, triggerAlert, toggleMute, showApp, getDom, initUi } from './js/ui.js';

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
// Boot
// ============================================
async function boot() {
  if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').then(reg => {
          reg.update(); // Force update check
      }).catch(console.warn);
  }

  initUi(); // Initialize DOM references
  initListeners();

  // Initial load
  await refreshAll();
  showApp();

  pollTimer = setInterval(pollLatest, POLL_INTERVAL);

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      clearInterval(pollTimer);
    } else {
      clearInterval(pollTimer);
      refreshAll();
      pollTimer = setInterval(pollLatest, POLL_INTERVAL);
    }
  });
}

boot();
