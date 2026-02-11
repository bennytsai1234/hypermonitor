# UI System & Design

## 🎨 Design Philosophy: Glassmorphism
The UI is built using strict CSS variables defined in directory `root` of `style.css`.
- **Background**: Deep black/grey (`#000`, `#111`).
- **Cards**: `backdrop-filter: blur(12px)` with semi-transparent borders.
- **Typography**: `Inter` for UI text, `JetBrains Mono` for numbers to ensure tabular alignment.

## 🖥️ Layout Structure (`index.html`)

1.  **Header**: App title, Mute toggle, Sentiment Badge.
2.  **Hero Card**: The significantly largest card showing the **Net Pressure**.
3.  **Stats Grid**: Two smaller cards for Long and Short absolute volumes.
4.  **Chart Section**: Interactive canvas with a custom Dropdown for time range.
5.  **Footer**: Status and timestamp.

## 🔧 DOM Manipulation (`js/ui.js`)

We do not use React or Vue. We utilize a **Cached DOM Pattern**.

### Initialization
`initUi()` is called once at boot. It queries all necessary IDs and stores them in the `dom` object. This avoids expensive `document.getElementById` calls inside the render loop.

```javascript
let dom = {
    netValue: $('net-value'),
    // ...
};
```

### Rendering (`renderUI`)
This function is "stateless" regarding the DOM. It takes the data and updates the `textContent` and `className` of the cached elements.

### Delta Logic
We calculate the difference between the previous fetch and the current fetch (`calculateAllDeltas`).
- If the change is significant, we update the delta indicator (e.g., `+$500萬`).
- **Color Logic**:
    - In a **Bearish** market, an *increase* in Sell Volume is "Good" for the prediction (Green), but technically it's selling. We handled this logic carefully:
    - `"Positive" class` -> Green Color.
    - `"Negative" class` -> Red Color.

## 🚨 Alert System
When `triggerAlert()` is called:
1.  **Vibration**: Uses `navigator.vibrate` (Mobile only).
2.  **Visual**: Adds `.updating` class to the main card, triggering a CSS animation (rainbow border flash).
3.  **Audio**: Plays `alert.mp3`. **Note**: User must interact with the page (click Mute button) at least once to unlock browser Audio Context.
