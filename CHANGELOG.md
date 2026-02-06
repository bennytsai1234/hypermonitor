# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-06

### Added
- **OLED 純黑模式**：全系統背景與趨勢圖深度黑化優化。
- **對沖監控系統**：新增 BTC+ETH 合併部位顯示與對沖趨勢圖。
- **彩虹變動提醒**：數據實際跳動時觸發四周彩虹光效 5 秒。
- **變動時間追蹤**：右上角顯示最後一次數據更新的精確時間。

### Changed
- **穩定爬蟲**：回退至最穩定的單路徑 10 秒刷新邏輯，並修正 BTC 抓取偏誤。
- **智能 Delta**：變動值現在會在無數據變化時自動保留，在刷新為 0 時隱藏。
- **UI 優化**：大幅提升字體大小與對比度，適配大螢幕監控。
