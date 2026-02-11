import { parseTimestamp, toNum, isBearish, extractData, padTime, formatVolume } from './utils.js';

let chartInstance = null;
let lastSignature = null;

export function renderChart(canvas, historyData, currentAsset, allData, selectedRange) {
  if (!canvas) return;

  // Map currentAsset ('all') to historyData key ('printer')
  const key = currentAsset === 'all' ? 'printer' : currentAsset;
  const history = historyData[key] || [];

  if (!history || history.length === 0) {
    if (chartInstance) {
        chartInstance.destroy();
        chartInstance = null;
    }
    return;
  }

  // Optimization: Skip re-render if data hasn't changed
  const latestTs = history[history.length - 1]?.timestamp || history[history.length - 1]?.time_bucket;
  const signature = `${key}-${selectedRange}-${latestTs}`;

  if (lastSignature === signature && chartInstance) {
      return;
  }
  lastSignature = signature;

  // Determine sentiment from current data to color the chart
  const bearish = allData ? isBearish(allData.sentiment) : false;
  const chartPoints = [];
  const color = bearish ? '#FF2E2E' : '#00FF9D';
  const bg = bearish ? 'rgba(255,46,46,0.08)' : 'rgba(0,255,157,0.08)';

  history.forEach((item) => {
    // Determine timestamp source
    const rawTs = item.timestamp || item.time_bucket;
    const ts = parseTimestamp(rawTs);

    let l = 0, s = 0;

    // Parse based on asset type structure in history
    if (currentAsset === 'all') {
        l = toNum(item.long_vol_num ?? item.longVolNum);
        s = toNum(item.short_vol_num ?? item.shortVolNum);
    } else if (currentAsset === 'hedge') {
        l = toNum(item.long_vol_num);
        s = toNum(item.short_vol_num);
    } else if (currentAsset === 'btc' || currentAsset === 'eth') {
        l = toNum(item.long_vol);
        s = toNum(item.short_vol);
    }

    const val = bearish ? (s - l) : (l - s);
    chartPoints.push({ x: ts, y: val });
  });

  const ctx = canvas.getContext('2d');
  if (chartInstance) chartInstance.destroy();

  chartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      datasets: [
        {
          label: bearish ? '淨空壓' : '淨多壓',
          data: chartPoints, // {x: Date, y: Number}
          borderColor: color,
          backgroundColor: bg,
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
        legend: { display: false },
        tooltip: {
            backgroundColor: 'rgba(0,0,0,0.85)',
            titleColor: '#fff',
            callbacks: {
                title: (items) => {
                    const idx = items[0].dataIndex;
                    // Safely retrieve the Date object from raw data
                    const d = chartPoints[idx].x;
                    if (!d || isNaN(d.getTime())) return '時間未知';
                    return `${padTime(d.getMonth()+1)}/${padTime(d.getDate())} ${padTime(d.getHours())}:${padTime(d.getMinutes())}`;
                },
                label: (ctx) => {
                    const v = ctx.parsed.y;
                    return isNaN(v) ? '無數據' : `淨壓: ${formatVolume(v)}`;
                }
            }
        }
      },
      scales: {
        x: {
          type: 'time',
          time: {
              displayFormats: { minute: 'HH:mm', hour: 'HH:mm', day: 'MM/dd' }
          },
          ticks: {
              color: 'rgba(255,255,255,0.25)',
              maxTicksLimit: 5, // Reduce density
              autoSkip: true,
              maxRotation: 0,
              includeBounds: true
          },
          grid: { color: 'rgba(255,255,255,0.04)' },
          border: { display: false },
        },
        y: {
          position: 'right', // Move Y-axis to right for better mobile view
          ticks: { color: 'rgba(255,255,255,0.25)', callback: (v) => formatVolume(v) },
          grid: { color: 'rgba(255,255,255,0.04)' },
          border: { display: false },
        },
      },
    },
  });
}
