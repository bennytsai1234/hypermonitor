
import { fetchHistory } from './js/api.js';
import { parseTimestamp, toNum, padTime, formatVolume } from './js/utils.js';

let chartInstance = null;
let currentRange = '1h';
let currentChart = 'net'; // 'net', 'long', 'short'
let globalHistory = []; // Cache loaded data

// Initial Boot
document.addEventListener('DOMContentLoaded', () => {
    initDropdown();
    initChartSwitcher();
    const btn = document.getElementById('refresh-btn');
    if(btn) btn.addEventListener('click', loadData);

    loadData();
});

// Dropdown Logic
function initDropdown() {
    const dd = document.querySelector('.custom-dropdown');
    if (!dd) return;

    const trigger = dd.querySelector('.dropdown-trigger');
    const items = dd.querySelectorAll('.dropdown-item');
    const selectedText = dd.querySelector('.selected-text');

    trigger.addEventListener('click', (e) => {
        e.stopPropagation();
        dd.classList.toggle('open');
    });

    items.forEach(item => {
        item.addEventListener('click', (e) => {
            e.stopPropagation();
            const val = item.dataset.value;
            if (val === currentRange) {
                dd.classList.remove('open');
                return;
            }
            currentRange = val;
            selectedText.textContent = item.textContent;
            items.forEach(i => i.classList.remove('active'));
            item.classList.add('active');
            dd.classList.remove('open');
            loadData();
        });
    });

    document.addEventListener('click', () => {
        dd.classList.remove('open');
    });
}

// Chart Switcher Logic
function initChartSwitcher() {
    const btns = document.querySelectorAll('.switch-btn');
    btns.forEach(btn => {
        btn.addEventListener('click', () => {
             const type = btn.dataset.chart;
             if (type === currentChart) return;

             currentChart = type;

             // Update UI
             btns.forEach(b => b.classList.remove('active'));
             btn.classList.add('active');

             // Re-render chart using cached data
             if (globalHistory.length > 0) {
                 renderChart(globalHistory);
             }
        });
    });
}

async function loadData() {
    const btn = document.getElementById('refresh-btn');
    if(btn) {
        btn.style.transition = 'transform 1s';
        btn.style.transform = 'rotate(360deg)';
    }

    try {
        const data = await fetchHistory(currentRange);
        const history = data.printer || [];

        if (history.length === 0) {
            console.warn("No data returned for range:", currentRange);
        }

        globalHistory = history; // Cache
        renderChart(history);
    } catch (e) {
        console.error("Failed to load data", e);
        alert("無法讀取數據，請稍後重試。");
    } finally {
        if(btn) {
            setTimeout(() => {
                btn.style.transform = 'none';
            }, 1000);
        }
    }
}

function renderChart(history) {
    const canvas = document.getElementById('analysis-chart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    // Parse Data
    const labels = history.map(d => parseTimestamp(d.timestamp || d.time_bucket));
    const longs = history.map(d => toNum(d.long_vol_num ?? d.longVolNum ?? d.long_vol));
    const shorts = history.map(d => toNum(d.short_vol_num ?? d.shortVolNum ?? d.short_vol));

    // Prepare Dataset based on currentChart type
    let datasets = [];

    // Dynamic Button Highlight (Optional polish: remove 'active' from net_long if net_short implies dominance?)
    // Actually, keep it simple. User chooses what to view.

    if (currentChart === 'net_long') {
        const nets = history.map((d, i) => longs[i] - shorts[i]);
        datasets.push({
            label: '淨多壓 (Net Long Pressure)',
            data: nets,
            borderColor: '#00FF9D',
            backgroundColor: 'rgba(0, 255, 157, 0.05)',
            borderWidth: 2,
            tension: 0,
            pointRadius: 0,
            fill: {
                target: 'origin',
                above: 'rgba(0, 255, 157, 0.1)',   // Positive (Long is stronger) = Green
                below: 'rgba(255, 46, 46, 0.1)'    // Negative (Short is stronger) = Red
            },
            segment: {
                 // If value < 0 (Red dominant), line is Red. Else Green.
                borderColor: ctx => ctx.p0.parsed.y < 0 ? '#FF2E2E' : '#00FF9D',
            }
        });
    } else if (currentChart === 'net_short') {
        // Net Short = Shorts - Longs
        const nets = history.map((d, i) => shorts[i] - longs[i]);
        datasets.push({
            label: '淨空壓 (Net Short Pressure)',
            data: nets,
            borderColor: '#FF2E2E',
            backgroundColor: 'rgba(255, 46, 46, 0.05)',
            borderWidth: 2,
            tension: 0,
            pointRadius: 0,
            fill: {
                target: 'origin',
                above: 'rgba(255, 46, 46, 0.1)',    // Positive (Short is stronger) = Red
                below: 'rgba(0, 255, 157, 0.1)'    // Negative (Long is stronger) = Green
            },
            segment: {
                // If value < 0 (Long dominant), line is Green. Else Red.
                borderColor: ctx => ctx.p0.parsed.y < 0 ? '#00FF9D' : '#FF2E2E',
            }
        });
    } else if (currentChart === 'long') {
        datasets.push({
            label: '多單 (Longs)',
            data: longs,
            borderColor: '#00FF9D',
            backgroundColor: 'rgba(0, 255, 157, 0.05)',
            borderWidth: 2,
            pointRadius: 0,
            tension: 0,
            fill: true
        });
    } else if (currentChart === 'short') {
        datasets.push({
            label: '空單 (Shorts)',
            data: shorts,
            borderColor: '#FF2E2E',
            backgroundColor: 'rgba(255, 46, 46, 0.05)',
            borderWidth: 2,
            pointRadius: 0,
            tension: 0,
            fill: true
        });
    }

    if (chartInstance) {
        chartInstance.destroy();
    }

    chartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            // Disable animations for snappier switching
            animation: {
                duration: 300
            },
            plugins: {
                legend: {
                    display: false // Hide legend to save space, tile is clear
                },
                tooltip: {
                    backgroundColor: 'rgba(10, 10, 10, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#ccc',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    callbacks: {
                        title: (ctx) => {
                           if(!ctx || !ctx[0]) return '';
                           const d = new Date(ctx[0].parsed.x);
                           return `${padTime(d.getMonth()+1)}/${padTime(d.getDate())} ${padTime(d.getHours())}:${padTime(d.getMinutes())}`;
                       },
                        label: (ctx) => {
                             let label = ctx.dataset.label;
                             // Dynamic tooltip label for Net Pressure
                             if (currentChart === 'net_long') {
                                 const val = ctx.parsed.y;
                                 label = val >= 0 ? '淨多壓' : '淨空壓';
                             } else if (currentChart === 'net_short') {
                                 const val = ctx.parsed.y;
                                 // For Net Short chart: Positive = Net Short, Negative = Net Long
                                 label = val >= 0 ? '淨空壓' : '淨多壓';
                             }
                             return `${label}: ${formatVolume(ctx.parsed.y)}`; // Always show magnitude? Or signed? Let's use signed but context aware. Actually formatted signed is fine. Original code uses formatVolume directly. Let's stick to signed formatVolume for consistency.
                        }
                    }
                }
            },
            scales: {
                x: {
                    type: 'time',
                    time: {
                         displayFormats: {
                             minute: 'HH:mm',
                             hour: 'MM/dd HH:mm',
                             day: 'MM/dd'
                         },
                         tooltipFormat: 'PPpp'
                    },
                    ticks: {
                        color: 'rgba(255,255,255,0.3)',
                        maxRotation: 0,
                        autoSkip: true,
                        maxTicksLimit: 6
                    },
                    grid: { color: 'rgba(255,255,255,0.03)' },
                    border: { display: false }
                },
                y: {
                    display: true,
                    position: 'right',
                    ticks: {
                        color: 'rgba(255,255,255,0.3)',
                        callback: v => formatVolume(v),
                        font: { size: 10 }
                    },
                    grid: { color: 'rgba(255,255,255,0.03)' },
                    border: { display: false }
                }
            }
        }
    });
}
