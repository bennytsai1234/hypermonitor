# Core Logic & API

## 📡 API Layer (`js/api.js`)

The `api.js` module handles all communication with the backend. It exports two main functions:

### `fetchLatest()`
- **Purpose**: Gets the current snapshot of market positions.
- **Returns**: A JSON object containing `sentiment`, `timestamp`, and volume data for various assets (`printer`, `btc`, `eth`).
- **Error Handling**: Returns `null` on failure to prevent UI crashes.

### `fetchHistory(range)`
- **Purpose**: Gets historical data for charting.
- **Arguments**: `range` (e.g., `'1h'`, `'12h'`, `'1y'`).
- **Processing**:
    - The backend returns raw arrays for BTC and ETH.
    - We calculate **Hedge** data client-side by summing BTC and ETH volumes for each timestamp.
    ```javascript
    // Client-side aggregation example
    long_vol_num: btc.long_vol + eth.long_vol
    ```

## 🧮 Data Utilities (`js/utils.js`)

This module helps parse the "messy" data from the wild.

### `extractData(rawData, assetType)`
This is the most critical function. It normalizes data from different structures into a standard format:
```javascript
{
  sentiment: "Bullish",
  timestamp: Date,
  long: 1234567,
  short: 987654
}
```
It handles:
- **CamelCase vs Snake_case**: Backend API inconsistency handling (`longVol` vs `long_vol`).
- **Asset Types**: Filters data for `all`, `hedge`, `btc`, or `eth`.

### `isBearish(sentiment)`
Simple text detection. If the sentiment string contains "跌" (Drop), it returns `true`. This drives the Red/Green logic across the entire app.

### `formatVolume(v)`
Converts raw numbers into human-readable strings like `$1.25億` or `$500萬`.
