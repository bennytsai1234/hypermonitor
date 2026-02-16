
import { fetchHistory } from './js/api.js';
import { parseTimestamp, toNum, padTime, formatVolume } from './js/utils.js';

let chartInstance = null;
let currentRange = '1h';

// Initial Boot
document.addEventListener('DOMContentLoaded', () => {
    initDropdown();
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

async function loadData() {
    const btn = document.getElementById('refresh-btn');
    if(btn) {
        btn.style.transition = 'transform 1s';
        btn.style.transform = 'rotate(360deg)';
    }

    try {
        // Fetch "All" data (printer)
        const data = await fetchHistory(currentRange);

        // The user specifically wants to "display the change in total net pressure"
        // and "change in long orders and short orders".
        // Use 'printer' array from the response which contains overall market data.
        const history = data.printer || [];

        if (history.length === 0) {
            console.warn("No data returned for range:", currentRange);
        }

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
    // Ensure we handle both snake_case (API usually) and camelCase if transformed
    const labels = history.map(d => parseTimestamp(d.timestamp || d.time_bucket));
    const longs = history.map(d => toNum(d.long_vol_num ?? d.longVolNum ?? d.long_vol));
    const shorts = history.map(d => toNum(d.short_vol_num ?? d.shortVolNum ?? d.short_vol));

    // Net Pressure = Longs - Shorts (Positive = Bullish Pressure, Negative = Bearish Pressure)
    // Or Shorts - Longs?
    // In the original PWA, Bearish = Red = (Short - Long). Bullish = Green = (Long - Short).
    // Here we want a continuous line. Let's use (Long - Short).
    // So > 0 is Bullish (Green), < 0 is Bearish (Red).
    const nets = history.map((d, i) => longs[i] - shorts[i]);

    if (chartInstance) {
        chartInstance.destroy();
    }

    chartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: '淨壓力 (Net Pressure)',
                    data: nets,
                    borderColor: '#00FF9D',
                    backgroundColor: 'rgba(0, 255, 157, 0.05)',
                    borderWidth: 2,
                    tension: 0.2,
                    fill: {
                        target: 'origin',
                        above: 'rgba(0, 255, 157, 0.05)',   // Area will be red above the origin
                        below: 'rgba(255, 46, 46, 0.05)'    // And blue below the origin
                    },
                    segment: {
                        borderColor: ctx => ctx.p0.parsed.y < 0 ? '#FF2E2E' : '#00FF9D',
                    },
                    order: 1
                },
                {
                    label: '多單 (Longs)',
                    data: longs,
                    borderColor: 'rgba(0, 255, 157, 0.4)',
                    borderWidth: 1,
                    pointRadius: 0,
                    tension: 0.2,
                    order: 2,
                    hidden: false // Show by default
                },
                {
                    label: '空單 (Shorts)',
                    data: shorts,
                    borderColor: 'rgba(255, 46, 46, 0.4)',
                    borderWidth: 1,
                    pointRadius: 0,
                    tension: 0.2,
                    order: 3,
                    hidden: false // Show by default
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    display: true,
                    labels: { color: '#999', font: { size: 10 } }
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
                            return `${ctx.dataset.label}: ${formatVolume(ctx.parsed.y)}`;
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
