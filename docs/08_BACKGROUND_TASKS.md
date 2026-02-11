# Background Tasks (Web Worker)

## ปัญหา The Problem: Mobile Throttling
Mobile browsers (Safari, Chrome Android) are aggressive about saving battery. If a tab is not visible (user switched apps or locked screen), the browser drastically reduces the frequency of `setTimeout` and `setInterval` on the main thread.
- **Result**: Our 10s polling becomes 1 minute or stops entirely. No alerts are triggered.

## ✅ The Solution: Dedicated Web Worker

We rely on `pwa/timer.worker.js`.

### How it Works
1.  **Main Thread**: Spawns the worker.
    ```javascript
    const pollWorker = new Worker('timer.worker.js');
    pollWorker.postMessage({ action: 'start', interval: 10000 });
    ```
2.  **Worker Thread**: Runs inside a separate context that is less restricted by the main UI thread's visibility state.
    ```javascript
    setInterval(() => self.postMessage('tick'), interval);
    ```
3.  **Communication**: The Worker simply says "tick". The Main Thread receives it and executes the actual heavy logic (`pollLatest()` -> `fetch` -> `render`).

### Why not fetch inside the Worker?
We could, but keeping the Worker "dumb" (just a timer) allows the Main Thread to handle all the complex data state and DOM updates. The Worker acts purely as a "Heartbeat" (Pacemaker) to wake up the Main Thread.

### Reliability
This method significantly improves background reliability, though OS-level "doze modes" (Android) or iOS background freezing can still eventually kill the process. This is the maximum capability possible within standard Web Standards without native code.
