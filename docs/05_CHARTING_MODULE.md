# Charting Module

## 📊 Overview
We use **Chart.js** (v4.4.7) with the **date-fns** adapter for time-scale rendering. The entire logic is encapsulated in `pwa/js/chart.js`.

## 📉 Logic Flow

### 1. Data Processing
The `renderChart` function accepts `historyData` and `currentAsset`.
- It iterates through the history array.
- For each point, it calculates the **Net Pressure**:
  ```javascript
  // Bearish Mode: Short - Long (Positive value means strong selling pressure)
  // Bullish Mode: Long - Short (Positive value means strong buying pressure)
  const val = bearish ? (s - l) : (l - s);
  ```
- This ensures the chart always goes "Up" when the trend confirms the sentiment, making it intuitive to read.

### 2. Optimization
To prevent canvas flickering and high CPU usage:
```javascript
// Signature check prevents re-rendering identical data
const signature = `${key}-${selectedRange}-${latestTs}`;
if (lastSignature === signature) return;
```

### 3. Visuals
- **Dynamic Coloring**:
  - Green (`#00FF9D`) for Bullish contexts.
  - Red (`#FF2E2E`) for Bearish contexts.
- **Gradients**: Use `fill: true` with a transparent background color (`rgba(..., 0.08)`) to create a modern area chart look.
- **Responsive Scales**:
  - Time Axis (X) automatically formats ticks (`HH:mm` or `MM/dd`) based on the zoom level.
  - Volume Axis (Y) is moved to the **right side** to prevent blocking the most recent data points on mobile screens.

## 🛠Dependencies
- `chart.umd.min.js`: The core library.
- `chartjs-adapter-date-fns.bundle.min.js`: Allows passing JS `Date` objects directly to `x` axis.
