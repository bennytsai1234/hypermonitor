# Project Overview

## 🎯 Vision
Hyperliquid Monitor is a specialized Progressive Web App (PWA) designed for crypto traders who need real-time visibility into "Super Money Printer" (large whale) positions on Hyperliquid. Unlike generic dashboards, this tool focuses on **actionable intelligence**—specifically tracking the net flow of capital (Long vs. Short) with millisecond precision and instant auditory feedback.

## ✨ Key Features

### 1. Real-Time Monitoring
- **Live Data Polling**: Fetches data every 10 seconds (configurable) from a distributed Cloudflare Worker network.
- **Sentiment Analysis**: Automatically classifies market sentiment (Bullish/Bearish) based on net position deltas.
- **Visual Feedback**: The entire UI theme adapts dynamically—Green for Bullish, Red for Bearish.

### 2. Cross-Platform Experience (PWA)
- **Installable**: Works as a native app on iOS, Android, and Desktop.
- **Offline Capable**: Critical UI assets are cached for instant loading.
- **Background Sync**: Uses a dedicated Web Worker (`timer.worker.js`) to ensure data polling continues even when the mobile screen is locked.

### 3. Audiovisual Alerts
- **Sound System**: Plays a distinct alert sound (`alert.mp3`) when significant position changes occurred.
- **Visual Flash**: The screen flashes and the card border glows when new data arrives.

### 4. Advanced Charting
- **Net Pressure Graph**: A custom area chart visualizing the `Long - Short` delta over time.
- **Multi-Asset Support**: Tracks `All`, `Hedge` (BTC+ETH), `BTC` specific, and `ETH` specific flows.
- **Time Travel**: Selectable time ranges from 1 Hour to 1 Year.

## 📱 User Interface Design
We utilize a **Glassmorphism** design language:
- Translucent, frosted-glass cards.
- Vibrant, neon-like text colors for critical metrics.
- Minimalist iconography using SVG.
- "Mobile-First" responsive layout ensuring usability on 5.5" screens and 30" monitors alike.
