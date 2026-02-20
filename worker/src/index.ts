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
								smart_wallet_count, smart_profit_count, smart_loss_count, smart_long_vol_num, smart_short_vol_num, smart_net_vol_num, smart_sentiment, smart_long_display, smart_short_display, smart_net_display
							) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)`
						).bind(
							d.walletCount, d.profitCount, d.lossCount,
							d.longVolNum, d.shortVolNum, d.netVolNum,
							d.sentiment,
							d.smartWalletCount || 0, d.smartProfitCount || 0, d.smartLossCount || 0,
							d.smartLongVolNum || 0, d.smartShortVolNum || 0, d.smartNetVolNum || 0,
							d.smartSentiment || ""
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
							timestamp: new Date().toISOString()
						});
						lastCacheUpdate = Date.now();
					} else {
						return new Response(JSON.stringify({ success: true, skipped: true }), { headers: corsHeaders });
					}
				} else if (url.pathname === '/update-range') {
					const stmts: D1PreparedStatement[] = [];
					const insertSQL = `INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL)`;

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
								symbol, data.longVol, data.shortVol, data.totalVol, data.netVol
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
						MAX(smart_sentiment) as last_sentiment_smart
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
						AVG(net_vol) as avg_net_vol
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
					smart_sentiment: r.last_sentiment_smart
				}));

				const btcData = rRows.filter(r => r.symbol === 'btc').map(r => ({
					timestamp: r.bucket,
					symbol: 'BTC',
					long_vol: r.avg_long_vol,
					short_vol: r.avg_short_vol,
					total_vol: r.avg_total_vol,
					net_vol: r.avg_net_vol
				}));

				const ethData = rRows.filter(r => r.symbol === 'eth').map(r => ({
					timestamp: r.bucket,
					symbol: 'ETH',
					long_vol: r.avg_long_vol,
					short_vol: r.avg_short_vol,
					total_vol: r.avg_total_vol,
					net_vol: r.avg_net_vol
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

