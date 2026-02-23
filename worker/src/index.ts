// --- L1 Cache: Global Variables (Persist across requests in warm workers) ---
let latestCache: any = null;
let lastCacheUpdate = 0;

export interface Env {
	DB: D1Database;
	API_KEY?: string;
}

// CORS headers shared across all responses
const corsHeaders = {
	'Content-Type': 'application/json',
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': '*',
};

// --- Helper: Get max timestamp efficiently using index ---
async function getMaxTimestamp(db: D1Database, table: string): Promise<string | null> {
	const row: any = await db.prepare(
		`SELECT timestamp FROM ${table} ORDER BY timestamp DESC LIMIT 1`
	).first();
	return row?.timestamp ?? null;
}

// --- Helper: Build time filter clause ---
// --- Helper: Parsing range for aggregated queries ---


export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		try {
			// --- POST: Upload endpoints ---
			if (request.method === 'POST') {
				// API Key auth
				if (env.API_KEY) {
					const authHeader = request.headers.get('X-API-Key') || '';
					if (authHeader !== env.API_KEY) {
						return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
					}
				}

				const d: any = await request.json();

				if (url.pathname === '/update-printer') {
					// 1. Deduplication with Heartbeat
					// Get the last record's data AND timestamp (Indexed for O(1) reads)
					const last: any = await env.DB.prepare(
						"SELECT timestamp, long_vol_num, short_vol_num, net_vol_num, wallet_count FROM printer_metrics ORDER BY timestamp DESC LIMIT 1"
					).first();

					let shouldWrite = true;

					if (last) {
						const lastTime = new Date(last.timestamp + (last.timestamp.endsWith('Z') ? '' : 'Z')).getTime(); // Ensure UTC parsing
						const now = Date.now();
						const diffSeconds = (now - lastTime) / 1000;

						// Condition 1: Data changed?
						const dataChanged = (
							last.long_vol_num !== d.longVolNum ||
							last.short_vol_num !== d.shortVolNum ||
							last.wallet_count !== d.walletCount
						);

						// Hard throttle: Force 10s interval to prevent conflict from multiple scrapers
						if (diffSeconds < 10) {
							shouldWrite = false;
						}
						// Condition 2: Force write every 60s (Heartbeat) to keep aggregation continuous
						// If data is same AND less than 60s since last write -> Skip
						else if (!dataChanged && diffSeconds < 60) {
							shouldWrite = false;
						}
					}

					if (shouldWrite) {
						await env.DB.prepare(
							`INSERT INTO printer_metrics (
								wallet_count, profit_count, loss_count, long_vol_num, short_vol_num, net_vol_num, sentiment, long_display, short_display, net_display,
								smart_wallet_count, smart_profit_count, smart_loss_count, smart_long_vol_num, smart_short_vol_num, smart_net_vol_num, smart_sentiment, smart_long_display, smart_short_display, smart_net_display,
								grinder_wallet_count, grinder_profit_count, grinder_loss_count, grinder_long_vol_num, grinder_short_vol_num, grinder_net_vol_num, grinder_sentiment,
								humble_wallet_count, humble_profit_count, humble_loss_count, humble_long_vol_num, humble_short_vol_num, humble_net_vol_num, humble_sentiment,
								exit_liq_wallet_count, exit_liq_profit_count, exit_liq_loss_count, exit_liq_long_vol_num, exit_liq_short_vol_num, exit_liq_net_vol_num, exit_liq_sentiment,
								semi_rekt_wallet_count, semi_rekt_profit_count, semi_rekt_loss_count, semi_rekt_long_vol_num, semi_rekt_short_vol_num, semi_rekt_net_vol_num, semi_rekt_sentiment,
								full_rekt_wallet_count, full_rekt_profit_count, full_rekt_loss_count, full_rekt_long_vol_num, full_rekt_short_vol_num, full_rekt_net_vol_num, full_rekt_sentiment,
								giga_rekt_wallet_count, giga_rekt_profit_count, giga_rekt_loss_count, giga_rekt_long_vol_num, giga_rekt_short_vol_num, giga_rekt_net_vol_num, giga_rekt_sentiment
							) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
						).bind(
							d.walletCount, d.profitCount, d.lossCount,
							d.longVolNum, d.shortVolNum, d.netVolNum,
							d.sentiment,
							d.smartWalletCount || 0, d.smartProfitCount || 0, d.smartLossCount || 0,
							d.smartLongVolNum || 0, d.smartShortVolNum || 0, d.smartNetVolNum || 0,
							d.smartSentiment || "",
							d.grinderWalletCount || 0, d.grinderProfitCount || 0, d.grinderLossCount || 0, d.grinderLongVolNum || 0, d.grinderShortVolNum || 0, d.grinderNetVolNum || 0, d.grinderSentiment || "",
							d.humbleWalletCount || 0, d.humbleProfitCount || 0, d.humbleLossCount || 0, d.humbleLongVolNum || 0, d.humbleShortVolNum || 0, d.humbleNetVolNum || 0, d.humbleSentiment || "",
							d.exitLiqWalletCount || 0, d.exitLiqProfitCount || 0, d.exitLiqLossCount || 0, d.exitLiqLongVolNum || 0, d.exitLiqShortVolNum || 0, d.exitLiqNetVolNum || 0, d.exitLiqSentiment || "",
							d.semiRektWalletCount || 0, d.semiRektProfitCount || 0, d.semiRektLossCount || 0, d.semiRektLongVolNum || 0, d.semiRektShortVolNum || 0, d.semiRektNetVolNum || 0, d.semiRektSentiment || "",
							d.fullRektWalletCount || 0, d.fullRektProfitCount || 0, d.fullRektLossCount || 0, d.fullRektLongVolNum || 0, d.fullRektShortVolNum || 0, d.fullRektNetVolNum || 0, d.fullRektSentiment || "",
							d.gigaRektWalletCount || 0, d.gigaRektProfitCount || 0, d.gigaRektLossCount || 0, d.gigaRektLongVolNum || 0, d.gigaRektShortVolNum || 0, d.gigaRektNetVolNum || 0, d.gigaRektSentiment || ""
						).run();

						// [L1 Cache Update] Update memory immediately
						if (!latestCache) latestCache = {};
						Object.assign(latestCache, {
							wallet_count: d.walletCount,
							profit_count: d.profitCount,
							loss_count: d.lossCount,
							long_vol_num: d.longVolNum,
							short_vol_num: d.shortVolNum,
							net_vol_num: d.netVolNum,
							sentiment: d.sentiment,
							// Display fields removed (frontend handles formatting)

							// Smart Money
							smart_wallet_count: d.smartWalletCount || 0,
							smart_profit_count: d.smartProfitCount || 0,
							smart_loss_count: d.smartLossCount || 0,
							smart_long_vol_num: d.smartLongVolNum || 0,
							smart_short_vol_num: d.smartShortVolNum || 0,
							smart_net_vol_num: d.smartNetVolNum || 0,
							smart_sentiment: d.smartSentiment || "",
							// Grinder
							grinder_wallet_count: d.grinderWalletCount || 0,
							grinder_profit_count: d.grinderProfitCount || 0,
							grinder_loss_count: d.grinderLossCount || 0,
							grinder_long_vol_num: d.grinderLongVolNum || 0,
							grinder_short_vol_num: d.grinderShortVolNum || 0,
							grinder_net_vol_num: d.grinderNetVolNum || 0,
							grinder_sentiment: d.grinderSentiment || "",
							// Humble
							humble_wallet_count: d.humbleWalletCount || 0,
							humble_profit_count: d.humbleProfitCount || 0,
							humble_loss_count: d.humbleLossCount || 0,
							humble_long_vol_num: d.humbleLongVolNum || 0,
							humble_short_vol_num: d.humbleShortVolNum || 0,
							humble_net_vol_num: d.humbleNetVolNum || 0,
							humble_sentiment: d.humbleSentiment || "",
							// Exit Liq
							exit_liq_wallet_count: d.exitLiqWalletCount || 0,
							exit_liq_profit_count: d.exitLiqProfitCount || 0,
							exit_liq_loss_count: d.exitLiqLossCount || 0,
							exit_liq_long_vol_num: d.exitLiqLongVolNum || 0,
							exit_liq_short_vol_num: d.exitLiqShortVolNum || 0,
							exit_liq_net_vol_num: d.exitLiqNetVolNum || 0,
							exit_liq_sentiment: d.exitLiqSentiment || "",
							// Semi Rekt
							semi_rekt_wallet_count: d.semiRektWalletCount || 0,
							semi_rekt_profit_count: d.semiRektProfitCount || 0,
							semi_rekt_loss_count: d.semiRektLossCount || 0,
							semi_rekt_long_vol_num: d.semiRektLongVolNum || 0,
							semi_rekt_short_vol_num: d.semiRektShortVolNum || 0,
							semi_rekt_net_vol_num: d.semiRektNetVolNum || 0,
							semi_rekt_sentiment: d.semiRektSentiment || "",
							// Full Rekt
							full_rekt_wallet_count: d.fullRektWalletCount || 0,
							full_rekt_profit_count: d.fullRektProfitCount || 0,
							full_rekt_loss_count: d.fullRektLossCount || 0,
							full_rekt_long_vol_num: d.fullRektLongVolNum || 0,
							full_rekt_short_vol_num: d.fullRektShortVolNum || 0,
							full_rekt_net_vol_num: d.fullRektNetVolNum || 0,
							full_rekt_sentiment: d.fullRektSentiment || "",
							// Giga Rekt
							giga_rekt_wallet_count: d.gigaRektWalletCount || 0,
							giga_rekt_profit_count: d.gigaRektProfitCount || 0,
							giga_rekt_loss_count: d.gigaRektLossCount || 0,
							giga_rekt_long_vol_num: d.gigaRektLongVolNum || 0,
							giga_rekt_short_vol_num: d.gigaRektShortVolNum || 0,
							giga_rekt_net_vol_num: d.gigaRektNetVolNum || 0,
							giga_rekt_sentiment: d.gigaRektSentiment || "",
							timestamp: new Date().toISOString()
						});
						lastCacheUpdate = Date.now();
					} else {
						return new Response(JSON.stringify({ success: true, skipped: true }), { headers: corsHeaders });
					}
				} else if (url.pathname === '/update-range') {
					const stmts: D1PreparedStatement[] = [];
					const insertSQL = `INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, price, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL)`;

					// Helper to check if we should write for a symbol (Indexed for O(1) reads)
					const checkAndPrepare = async (symbol: string, data: any) => {
						const last: any = await env.DB.prepare(`SELECT timestamp, long_vol, short_vol FROM range_metrics WHERE symbol=? ORDER BY timestamp DESC LIMIT 1`).bind(symbol).first();
						let write = true;

						if (last) {
							const lastTime = new Date(last.timestamp + (last.timestamp.endsWith('Z') ? '' : 'Z')).getTime();
							const now = Date.now();
							const diff = (now - lastTime) / 1000;

							const changed = (last.long_vol !== data.longVol || last.short_vol !== data.shortVol);

							// Hard throttle: Force 10s interval to prevent conflict from multiple scrapers
							if (diff < 10) {
								write = false;
							}
							// Skip if same data AND recent (<60s)
							else if (!changed && diff < 60) {
								write = false;
							}
						}

						if (write) {
							stmts.push(env.DB.prepare(insertSQL).bind(
								symbol, data.longVol, data.shortVol, data.totalVol, data.netVol, data.price || null
							));

							// [L1 Cache Update]
							if (!latestCache) latestCache = {};
							if (symbol === 'btc') latestCache.btc = { ...data, symbol: 'BTC' };
							if (symbol === 'eth') latestCache.eth = { ...data, symbol: 'ETH' };
						}
					};

					if (d.btc) await checkAndPrepare('btc', d.btc);
					if (d.eth) await checkAndPrepare('eth', d.eth);

					if (stmts.length > 0) {
						await env.DB.batch(stmts);
						lastCacheUpdate = Date.now();
					} else {
						return new Response(JSON.stringify({ success: true, skipped: true }), { headers: corsHeaders });
					}
				}

				return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
			}

			// --- GET: /history (Dynamic Downsampling from Raw Metrics) ---
			if (url.pathname === '/history') {
				const range = url.searchParams.get('range') || '1h'; // 1h, 4h, 24h, 7d
				let since: string;
				let bufferSeconds: number; // Group events within this buffer to avoid too many points

				// Determine time range and grouping buffer
				switch (range) {
					case '4h':
						since = '-4 hours';
						bufferSeconds = 60; // 1 min grouping
						break;
					case '24h':
						since = '-24 hours';
						bufferSeconds = 300; // 5 min grouping
						break;
					case '7d':
						since = '-7 days';
						bufferSeconds = 3600; // 1 hour grouping
						break;
					case '30d':
						since = '-30 days';
						bufferSeconds = 14400; // 4 hour grouping
						break;
					case '1h':
					default:
						since = '-1 hour';
						bufferSeconds = 10; // 10s grouping (high res)
						break;
				}

				// Query Raw Metrics with dynamic downsampling (using strftime to group)
				// Note: D1/SQLite strftime('%s') returns seconds. dividing by bufferSeconds sends to integer bucket.
				const queryP = `
					SELECT
						MAX(timestamp) as bucket,
						AVG(long_vol_num) as avg_long_vol_num,
						AVG(short_vol_num) as avg_short_vol_num,
						AVG(net_vol_num) as avg_net_vol_num,
						MAX(wallet_count) as max_wallet_count,
						MAX(sentiment) as last_sentiment,
						AVG(smart_long_vol_num) as avg_long_vol_smart,
						AVG(smart_short_vol_num) as avg_short_vol_smart,
						AVG(smart_net_vol_num) as avg_net_vol_smart,
						MAX(smart_wallet_count) as max_wallet_smart,
						MAX(smart_sentiment) as last_sentiment_smart,
						AVG(grinder_long_vol_num) as avg_long_vol_grinder,
						AVG(grinder_short_vol_num) as avg_short_vol_grinder,
						AVG(grinder_net_vol_num) as avg_net_vol_grinder,
						MAX(grinder_wallet_count) as max_wallet_grinder,
						MAX(grinder_sentiment) as last_sentiment_grinder,
						AVG(humble_long_vol_num) as avg_long_vol_humble,
						AVG(humble_short_vol_num) as avg_short_vol_humble,
						AVG(humble_net_vol_num) as avg_net_vol_humble,
						MAX(humble_wallet_count) as max_wallet_humble,
						MAX(humble_sentiment) as last_sentiment_humble,
						AVG(exit_liq_long_vol_num) as avg_long_vol_exit_liq,
						AVG(exit_liq_short_vol_num) as avg_short_vol_exit_liq,
						AVG(exit_liq_net_vol_num) as avg_net_vol_exit_liq,
						MAX(exit_liq_wallet_count) as max_wallet_exit_liq,
						MAX(exit_liq_sentiment) as last_sentiment_exit_liq,
						AVG(semi_rekt_long_vol_num) as avg_long_vol_semi_rekt,
						AVG(semi_rekt_short_vol_num) as avg_short_vol_semi_rekt,
						AVG(semi_rekt_net_vol_num) as avg_net_vol_semi_rekt,
						MAX(semi_rekt_wallet_count) as max_wallet_semi_rekt,
						MAX(semi_rekt_sentiment) as last_sentiment_semi_rekt,
						AVG(full_rekt_long_vol_num) as avg_long_vol_full_rekt,
						AVG(full_rekt_short_vol_num) as avg_short_vol_full_rekt,
						AVG(full_rekt_net_vol_num) as avg_net_vol_full_rekt,
						MAX(full_rekt_wallet_count) as max_wallet_full_rekt,
						MAX(full_rekt_sentiment) as last_sentiment_full_rekt,
						AVG(giga_rekt_long_vol_num) as avg_long_vol_giga_rekt,
						AVG(giga_rekt_short_vol_num) as avg_short_vol_giga_rekt,
						AVG(giga_rekt_net_vol_num) as avg_net_vol_giga_rekt,
						MAX(giga_rekt_wallet_count) as max_wallet_giga_rekt,
						MAX(giga_rekt_sentiment) as last_sentiment_giga_rekt
					FROM printer_metrics
					WHERE timestamp > datetime('now', ?)
					GROUP BY CAST(strftime('%s', timestamp) / ? AS INTEGER)
					ORDER BY bucket ASC
				`;

				const queryR = `
					SELECT
						MAX(timestamp) as bucket,
						symbol,
						AVG(long_vol) as avg_long_vol,
						AVG(short_vol) as avg_short_vol,
						AVG(total_vol) as avg_total_vol,
						AVG(net_vol) as avg_net_vol,
						AVG(price) as avg_price
					FROM range_metrics
					WHERE timestamp > datetime('now', ?)
					GROUP BY symbol, CAST(strftime('%s', timestamp) / ? AS INTEGER)
					ORDER BY bucket ASC
				`;

				// Parallel Query
				const [pRes, rRes] = await env.DB.batch([
					env.DB.prepare(queryP).bind(since, bufferSeconds),
					env.DB.prepare(queryR).bind(since, bufferSeconds)
				]);

				const pRows = pRes.results as any[];
				const rRows = rRes.results as any[];

				// Map database columns back to API expected fields (Backward Compatible)
				const printer = pRows.map(r => ({
					timestamp: r.bucket,
					long_vol_num: r.avg_long_vol_num,
					short_vol_num: r.avg_short_vol_num,
					net_vol_num: r.avg_net_vol_num,
					wallet_count: r.max_wallet_count,
					sentiment: r.last_sentiment,
					// Smart Money
					smart_long_vol_num: r.avg_long_vol_smart,
					smart_short_vol_num: r.avg_short_vol_smart,
					smart_net_vol_num: r.avg_net_vol_smart,
					smart_wallet_count: r.max_wallet_smart,
					smart_sentiment: r.last_sentiment_smart,
					// Grinder
					grinder_long_vol_num: r.avg_long_vol_grinder,
					grinder_short_vol_num: r.avg_short_vol_grinder,
					grinder_net_vol_num: r.avg_net_vol_grinder,
					grinder_wallet_count: r.max_wallet_grinder,
					grinder_sentiment: r.last_sentiment_grinder,
					// Humble
					humble_long_vol_num: r.avg_long_vol_humble,
					humble_short_vol_num: r.avg_short_vol_humble,
					humble_net_vol_num: r.avg_net_vol_humble,
					humble_wallet_count: r.max_wallet_humble,
					humble_sentiment: r.last_sentiment_humble,
					// Exit Liq
					exit_liq_long_vol_num: r.avg_long_vol_exit_liq,
					exit_liq_short_vol_num: r.avg_short_vol_exit_liq,
					exit_liq_net_vol_num: r.avg_net_vol_exit_liq,
					exit_liq_wallet_count: r.max_wallet_exit_liq,
					exit_liq_sentiment: r.last_sentiment_exit_liq,
					// Semi Rekt
					semi_rekt_long_vol_num: r.avg_long_vol_semi_rekt,
					semi_rekt_short_vol_num: r.avg_short_vol_semi_rekt,
					semi_rekt_net_vol_num: r.avg_net_vol_semi_rekt,
					semi_rekt_wallet_count: r.max_wallet_semi_rekt,
					semi_rekt_sentiment: r.last_sentiment_semi_rekt,
					// Full Rekt
					full_rekt_long_vol_num: r.avg_long_vol_full_rekt,
					full_rekt_short_vol_num: r.avg_short_vol_full_rekt,
					full_rekt_net_vol_num: r.avg_net_vol_full_rekt,
					full_rekt_wallet_count: r.max_wallet_full_rekt,
					full_rekt_sentiment: r.last_sentiment_full_rekt,
					// Giga Rekt
					giga_rekt_long_vol_num: r.avg_long_vol_giga_rekt,
					giga_rekt_short_vol_num: r.avg_short_vol_giga_rekt,
					giga_rekt_net_vol_num: r.avg_net_vol_giga_rekt,
					giga_rekt_wallet_count: r.max_wallet_giga_rekt,
					giga_rekt_sentiment: r.last_sentiment_giga_rekt
				}));

				const btcData = rRows.filter(r => r.symbol === 'btc').map(r => ({
					timestamp: r.bucket,
					symbol: 'BTC',
					long_vol: r.avg_long_vol,
					short_vol: r.avg_short_vol,
					total_vol: r.avg_total_vol,
					net_vol: r.avg_net_vol,
					price: r.avg_price
				}));

				const ethData = rRows.filter(r => r.symbol === 'eth').map(r => ({
					timestamp: r.bucket,
					symbol: 'ETH',
					long_vol: r.avg_long_vol,
					short_vol: r.avg_short_vol,
					total_vol: r.avg_total_vol,
					net_vol: r.avg_net_vol,
					price: r.avg_price
				}));

				// [L2 Cache] Cache history for 60s (Browser) / 120s (CDN)
				// Since historical data (aggregated/downsampled) updates slowly, we can cache it aggressively
				return new Response(JSON.stringify({
					printer, btc: btcData, eth: ethData
				}), {
					headers: {
						...corsHeaders,
						'Cache-Control': 'public, max-age=60, s-maxage=120'
					}
				});
			}

			// --- GET: /latest (Optimized with L1 Memory Cache + ETag) ---
			if (url.pathname === '/latest') {
				// 1. Check L1 Memory Cache
				const now = Date.now();
				let result = latestCache;

				// If cache is stale or missing core fields (due to partial update), fetch from DB
				if (!result || !result.long_vol_num || (now - lastCacheUpdate >= 10000)) {
					const [pResult, btcResult, ethResult] = await env.DB.batch([
						env.DB.prepare("SELECT * FROM printer_metrics ORDER BY timestamp DESC, id DESC LIMIT 1"),
						env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='btc' ORDER BY timestamp DESC, id DESC LIMIT 1"),
						env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='eth' ORDER BY timestamp DESC, id DESC LIMIT 1"),
					]);

					const p = pResult.results[0] as any;
					const btc = btcResult.results[0] as any;
					const eth = ethResult.results[0] as any;

					if (!p) return new Response(JSON.stringify({ error: "No data" }), { status: 404, headers: corsHeaders });

					result = {
						...p,
						btc: btc ? { ...btc, symbol: 'BTC' } : null,
						eth: eth ? { ...eth, symbol: 'ETH' } : null
					};

					// Update L1 Cache
					latestCache = result;
					lastCacheUpdate = now;
				}

				// 2. Generate ETag (Hash of content)
				const jsonStr = JSON.stringify(result);
				const hashBuffer = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(jsonStr));
				const hashArray = Array.from(new Uint8Array(hashBuffer));
				const etag = '"' + hashArray.map(b => b.toString(16).padStart(2, '0')).join('') + '"';

				// 3. Check If-None-Match
				const ifNoneMatch = request.headers.get('If-None-Match');
				if (ifNoneMatch === etag) {
					return new Response(null, {
						status: 304,
						headers: {
							...corsHeaders,
							'ETag': etag,
							'Cache-Control': 'no-cache' // Force revalidation
						}
					});
				}

				// 4. Return Data (200 OK)
				return new Response(jsonStr, {
					headers: {
						...corsHeaders,
						'ETag': etag,
						'Cache-Control': 'no-cache', // Force revalidation
						'X-Cache-Status': (now - lastCacheUpdate < 10000) ? 'HIT-RAM' : 'MISS-DB'
					}
				});
			}

			// --- GET: /stats — Database health check ---
			if (url.pathname === '/stats') {
				const [pCount, rCount, pOldest, rOldest] = await env.DB.batch([
					env.DB.prepare("SELECT COUNT(*) as count FROM printer_metrics"),
					env.DB.prepare("SELECT COUNT(*) as count FROM range_metrics"),
					env.DB.prepare("SELECT MIN(timestamp) as oldest FROM printer_metrics"),
					env.DB.prepare("SELECT MIN(timestamp) as oldest FROM range_metrics"),
				]);

				return new Response(JSON.stringify({
					printer_metrics: {
						count: (pCount.results[0] as any)?.count ?? 0,
						oldest: (pOldest.results[0] as any)?.oldest ?? null,
					},
					range_metrics: {
						count: (rCount.results[0] as any)?.count ?? 0,
						oldest: (rOldest.results[0] as any)?.oldest ?? null,
					},
				}), { headers: corsHeaders });
			}

			// --- GET: /cleanup — Manual trigger for data purge ---
			if (url.pathname === '/cleanup') {
				const sixMonthsAgo = new Date();
				sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
				const cutoff = sixMonthsAgo.toISOString();

				await env.DB.batch([
					env.DB.prepare(`DELETE FROM printer_metrics WHERE timestamp < ?`).bind(cutoff),
					env.DB.prepare(`DELETE FROM range_metrics WHERE timestamp < ?`).bind(cutoff)
				]);
				return new Response(JSON.stringify({ success: true, message: "Manual cleanup completed (older than 6 months)" }), { headers: corsHeaders });
			}

			return new Response("OK", { status: 200 });
		} catch (err: any) {
			return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
		}
	},

	// --- CRON: Cleanup Old Data (Retention: 6 Months) ---
	async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
		// Only run at midnight to save costs
		const date = new Date(event.scheduledTime);
		if (date.getHours() !== 0 || date.getMinutes() > 10) return;

		const sixMonthsAgo = new Date();
		sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
		const cutoff = sixMonthsAgo.toISOString();

		await env.DB.batch([
			env.DB.prepare(`DELETE FROM printer_metrics WHERE timestamp < ?`).bind(cutoff),
			env.DB.prepare(`DELETE FROM range_metrics WHERE timestamp < ?`).bind(cutoff)
		]);
	},
};

