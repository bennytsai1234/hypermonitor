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
function parseRange(range: string): { table: '1m' | '1h', limit: number, since: string } {
	switch (range) {
		case '1h':  return { table: '1m', limit: 60,   since: '-1 hour' };
		case '4h':  return { table: '1m', limit: 240,  since: '-4 hours' };
		case '12h': return { table: '1m', limit: 720,  since: '-12 hours' };
		case '1d':  return { table: '1m', limit: 1440, since: '-1 day' };
		case '3d':  return { table: '1h', limit: 72,   since: '-3 days' };
		case '1w':  return { table: '1h', limit: 168,  since: '-7 days' };
		case '1m':  return { table: '1h', limit: 744,  since: '-1 month' };
		default:    return { table: '1m', limit: 60,   since: '-1 hour' };
	}
}

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
					// Get the last record's data AND timestamp
					const last: any = await env.DB.prepare(
						"SELECT timestamp, long_vol_num, short_vol_num, net_vol_num, wallet_count FROM printer_metrics ORDER BY id DESC LIMIT 1"
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
							`INSERT INTO printer_metrics (wallet_count, profit_count, loss_count, long_vol_num, short_vol_num, net_vol_num, sentiment, long_display, short_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
						).bind(
							d.walletCount, d.profitCount, d.lossCount,
							d.longVolNum, d.shortVolNum, d.netVolNum,
							d.sentiment, d.longDisplay, d.shortDisplay, d.netDisplay
						).run();
					} else {
						return new Response(JSON.stringify({ success: true, skipped: true }), { headers: corsHeaders });
					}
				} else if (url.pathname === '/update-range') {
					const stmts: D1PreparedStatement[] = [];
					const insertSQL = `INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;

					// Helper to check if we should write for a symbol
					const checkAndPrepare = async (symbol: string, data: any) => {
						const last: any = await env.DB.prepare(`SELECT timestamp, long_vol, short_vol FROM range_metrics WHERE symbol=? ORDER BY id DESC LIMIT 1`).bind(symbol).first();
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
								symbol, data.longVol, data.shortVol, data.totalVol, data.netVol,
								data.longDisplay, data.shortDisplay, data.totalDisplay, data.netDisplay
							));
						}
					};

					if (d.btc) await checkAndPrepare('btc', d.btc);
					if (d.eth) await checkAndPrepare('eth', d.eth);

					if (stmts.length > 0) {
						await env.DB.batch(stmts);
					} else {
						return new Response(JSON.stringify({ success: true, skipped: true }), { headers: corsHeaders });
					}
				}

				return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
			}

			// --- GET: /history (Optimized) ---
			if (url.pathname === '/history') {
				const range = url.searchParams.get('range') || '1h';
				const { table, since } = parseRange(range);

				// Tables: printer_1m / printer_1h
				const pTable = `printer_${table}`;
				const rTable = `range_${table}`;

				// Parallel Query
				const [pRes, rRes] = await env.DB.batch([
					env.DB.prepare(`SELECT * FROM ${pTable} WHERE bucket > datetime('now', ?) ORDER BY bucket ASC`).bind(since),
					env.DB.prepare(`SELECT * FROM ${rTable} WHERE bucket > datetime('now', ?) ORDER BY bucket ASC`).bind(since)
				]);

				const pRows = pRes.results as any[];
				const rRows = rRes.results as any[];

				// Format for Frontend
				// Map database columns back to API expected fields
				const printer = pRows.map(r => ({
					timestamp: r.bucket,
					long_vol_num: r.avg_long_vol_num,
					short_vol_num: r.avg_short_vol_num,
					net_vol_num: r.avg_net_vol_num,
					wallet_count: r.max_wallet_count,
					sentiment: r.last_sentiment
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

				return new Response(JSON.stringify({
					printer, btc: btcData, eth: ethData
				}), { headers: corsHeaders });
			}

			// --- GET: /latest ---
			if (url.pathname === '/latest') {
				// Use batch() to parallelize all 3 queries
				const [pResult, btcResult, ethResult] = await env.DB.batch([
					env.DB.prepare("SELECT * FROM printer_metrics ORDER BY timestamp DESC LIMIT 1"),
					env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='btc' ORDER BY timestamp DESC LIMIT 1"),
					env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='eth' ORDER BY timestamp DESC LIMIT 1"),
				]);

				const p = pResult.results[0] as any;
				const btc = btcResult.results[0] as any;
				const eth = ethResult.results[0] as any;

				return new Response(JSON.stringify({
					...p,
					btc: btc ? { ...btc, symbol: 'BTC' } : null,
					eth: eth ? { ...eth, symbol: 'ETH' } : null
				}), { headers: corsHeaders });
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
				await aggregateData(env.DB);
				await cleanupOldData(env.DB);
				return new Response(JSON.stringify({ success: true, message: "Aggregation and cleanup completed" }), { headers: corsHeaders });
			}

			return new Response("OK", { status: 200 });
		} catch (err: any) {
			return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
		}
	},

	// --- Cron: Scheduled Task (Aggregation + Cleanup) ---
	async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
		// Run aggregation first, then cleanup
		// Use waitUntil to ensure it completes even if response is sent
		ctx.waitUntil((async () => {
			await aggregateData(env.DB);

			// Run cleanup only once per hour (approx)
			const date = new Date(event.scheduledTime);
			if (date.getMinutes() === 0) {
				await cleanupOldData(env.DB);
			}
		})());
	},
};

// --- Core: Aggregation Logic ---
async function aggregateData(db: D1Database): Promise<void> {
	// A. 1-Minute Aggregation (Raw -> 1m)
	// Query raw data in minute buckets.
	// To minimize complexity, we aggregate "unprocessed" minutes.
	// Reduced lookback to 5 minutes to save read ops (was 15).
	const rangeStart = `-${5} minutes`; // Look back 5 mins

	const pQuery = `
		INSERT OR REPLACE INTO printer_1m (bucket, avg_long_vol_num, avg_short_vol_num, avg_net_vol_num, max_wallet_count, last_sentiment, sample_count)
		SELECT
			strftime('%Y-%m-%d %H:%M:00', timestamp) as bucket,
			AVG(long_vol_num),
			AVG(short_vol_num),
			AVG(net_vol_num),
			MAX(wallet_count),
			MAX(sentiment), -- Simple string aggregation
			COUNT(*)
		FROM printer_metrics
		WHERE timestamp > datetime('now', ?) AND timestamp < strftime('%Y-%m-%d %H:%M:00', 'now')
		GROUP BY bucket
	`;

	const rQuery = `
		INSERT OR REPLACE INTO range_1m (bucket, symbol, avg_long_vol, avg_short_vol, avg_total_vol, avg_net_vol, sample_count)
		SELECT
			strftime('%Y-%m-%d %H:%M:00', timestamp) as bucket,
			symbol,
			AVG(long_vol),
			AVG(short_vol),
			AVG(total_vol),
			AVG(net_vol),
			COUNT(*)
		FROM range_metrics
		WHERE timestamp > datetime('now', ?) AND timestamp < strftime('%Y-%m-%d %H:%M:00', 'now')
		GROUP BY bucket, symbol
	`;

	await db.batch([
		db.prepare(pQuery).bind(rangeStart),
		db.prepare(rQuery).bind(rangeStart)
	]);

	// B. 1-Hour Aggregation (1m -> 1h)
	// Aggregate from printer_1m to printer_1h
	const p1hQuery = `
		INSERT OR REPLACE INTO printer_1h (bucket, avg_long_vol_num, avg_short_vol_num, avg_net_vol_num, max_wallet_count, last_sentiment, sample_count)
		SELECT
			strftime('%Y-%m-%d %H:00:00', bucket) as h_bucket,
			AVG(avg_long_vol_num),
			AVG(avg_short_vol_num),
			AVG(avg_net_vol_num),
			MAX(max_wallet_count),
			MAX(last_sentiment),
			SUM(sample_count)
		FROM printer_1m
		WHERE bucket > datetime('now', '-3 hours') AND bucket < strftime('%Y-%m-%d %H:00:00', 'now')
		GROUP BY h_bucket
	`;

    const r1hQuery = `
		INSERT OR REPLACE INTO range_1h (bucket, symbol, avg_long_vol, avg_short_vol, avg_total_vol, avg_net_vol, sample_count)
		SELECT
			strftime('%Y-%m-%d %H:00:00', bucket) as h_bucket,
			symbol,
			AVG(avg_long_vol),
			AVG(avg_short_vol),
			AVG(avg_total_vol),
			AVG(avg_net_vol),
			SUM(sample_count)
		FROM range_1m
		WHERE bucket > datetime('now', '-3 hours') AND bucket < strftime('%Y-%m-%d %H:00:00', 'now')
		GROUP BY h_bucket, symbol
	`;

	await db.batch([
		db.prepare(p1hQuery),
		db.prepare(r1hQuery)
	]);
}

// --- Cleanup: Retention Policy ---
async function cleanupOldData(db: D1Database): Promise<void> {
	// Raw data: Keep 24 hours (for debugging and /latest high fidelity)
	const rawCutoff = '-1 day';
	// Aggregated data: Keep 1 year
	const aggCutoff = '-1 year';

	await db.batch([
		db.prepare("DELETE FROM printer_metrics WHERE timestamp < datetime('now', ?)").bind(rawCutoff),
		db.prepare("DELETE FROM range_metrics WHERE timestamp < datetime('now', ?)").bind(rawCutoff),
		db.prepare("DELETE FROM printer_1m WHERE bucket < datetime('now', ?)").bind(aggCutoff),
		db.prepare("DELETE FROM range_1m WHERE bucket < datetime('now', ?)").bind(aggCutoff),
		db.prepare("DELETE FROM printer_1h WHERE bucket < datetime('now', ?)").bind(aggCutoff),
		db.prepare("DELETE FROM range_1h WHERE bucket < datetime('now', ?)").bind(aggCutoff)
	]);
}
