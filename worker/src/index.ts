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
function parseRange(range: string): { filter: string; interval: number } {
	const map: Record<string, { filter: string; interval: number }> = {
		'1h':  { filter: '-1 hour',    interval: 1 },
		'2h':  { filter: '-2 hours',   interval: 1 },
		'3h':  { filter: '-3 hours',   interval: 1 },
		'4h':  { filter: '-4 hours',   interval: 2 },
		'5h':  { filter: '-5 hours',   interval: 2 },
		'6h':  { filter: '-6 hours',   interval: 3 },
		'8h':  { filter: '-8 hours',   interval: 4 },
		'12h': { filter: '-12 hours',  interval: 5 },
		'1d':  { filter: '-1 day',     interval: 5 },
		'2d':  { filter: '-2 days',    interval: 10 },
		'3d':  { filter: '-3 days',    interval: 15 },
		'4d':  { filter: '-4 days',    interval: 20 },
		'5d':  { filter: '-5 days',    interval: 30 },
		'1w':  { filter: '-7 days',    interval: 60 },
		'1m':  { filter: '-1 month',   interval: 240 },
		'3m':  { filter: '-3 months',  interval: 720 },
		'6m':  { filter: '-6 months',  interval: 1440 },
		'1y':  { filter: '-1 year',    interval: 1440 },
	};
	return map[range] || map['1h'];
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
					await env.DB.prepare(
						`INSERT INTO printer_metrics (wallet_count, profit_count, loss_count, long_vol_num, short_vol_num, net_vol_num, sentiment, long_display, short_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
					).bind(
						d.walletCount, d.profitCount, d.lossCount,
						d.longVolNum, d.shortVolNum, d.netVolNum,
						d.sentiment, d.longDisplay, d.shortDisplay, d.netDisplay
					).run();
				} else if (url.pathname === '/update-range') {
					// Use batch() for atomic multi-insert
					const stmts: D1PreparedStatement[] = [];
					const insertSQL = `INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;

					if (d.btc) {
						stmts.push(env.DB.prepare(insertSQL).bind(
							'btc', d.btc.longVol, d.btc.shortVol, d.btc.totalVol, d.btc.netVol,
							d.btc.longDisplay, d.btc.shortDisplay, d.btc.totalDisplay, d.btc.netDisplay
						));
					}
					if (d.eth) {
						stmts.push(env.DB.prepare(insertSQL).bind(
							'eth', d.eth.longVol, d.eth.shortVol, d.eth.totalVol, d.eth.netVol,
							d.eth.longDisplay, d.eth.shortDisplay, d.eth.totalDisplay, d.eth.netDisplay
						));
					}
					if (stmts.length > 0) {
						await env.DB.batch(stmts);
					}
				}

				return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
			}

			// --- GET: /history ---
			if (url.pathname === '/history') {
				const range = url.searchParams.get('range') || '1h';
				const { filter, interval } = parseRange(range);

				// Step 1: Get max timestamps from both tables in parallel using batch()
				const [pMax, rMax] = await env.DB.batch([
					env.DB.prepare(`SELECT timestamp FROM printer_metrics ORDER BY timestamp DESC LIMIT 1`),
					env.DB.prepare(`SELECT timestamp FROM range_metrics ORDER BY timestamp DESC LIMIT 1`),
				]);

				const pMaxTs = (pMax.results[0] as any)?.timestamp;
				const rMaxTs = (rMax.results[0] as any)?.timestamp;

				if (!pMaxTs && !rMaxTs) {
					return new Response(JSON.stringify({ printer: [], btc: [], eth: [] }), { headers: corsHeaders });
				}

				// Step 2: Build aggregation queries with the resolved max timestamps
				const timeBucket = `datetime((strftime('%s', timestamp) / (60 * ${interval})) * (60 * ${interval}), 'unixepoch')`;

				const batchStmts: D1PreparedStatement[] = [];

				// Printer query
				if (pMaxTs) {
					batchStmts.push(env.DB.prepare(`
						SELECT
							${timeBucket} as time_bucket,
							AVG(long_vol_num) as long_vol_num,
							AVG(short_vol_num) as short_vol_num,
							AVG(net_vol_num) as net_vol_num,
							MAX(wallet_count) as wallet_count,
							MAX(sentiment) as sentiment
						FROM printer_metrics
						WHERE timestamp > datetime(?, ?)
						GROUP BY time_bucket ORDER BY time_bucket ASC
					`).bind(pMaxTs, filter));
				}

				// BTC query — symbol is now parameterized (fixes SQL injection)
				if (rMaxTs) {
					batchStmts.push(env.DB.prepare(`
						SELECT
							${timeBucket} as time_bucket,
							? as symbol,
							AVG(long_vol) as long_vol,
							AVG(short_vol) as short_vol,
							AVG(total_vol) as total_vol,
							AVG(net_vol) as net_vol
						FROM range_metrics
						WHERE timestamp > datetime(?, ?)
						AND symbol = ?
						GROUP BY time_bucket ORDER BY time_bucket ASC
					`).bind('btc', rMaxTs, filter, 'btc'));

					// ETH query
					batchStmts.push(env.DB.prepare(`
						SELECT
							${timeBucket} as time_bucket,
							? as symbol,
							AVG(long_vol) as long_vol,
							AVG(short_vol) as short_vol,
							AVG(total_vol) as total_vol,
							AVG(net_vol) as net_vol
						FROM range_metrics
						WHERE timestamp > datetime(?, ?)
						AND symbol = ?
						GROUP BY time_bucket ORDER BY time_bucket ASC
					`).bind('eth', rMaxTs, filter, 'eth'));
				}

				const results = await env.DB.batch(batchStmts);

				let pIdx = 0;
				const printer = pMaxTs ? results[pIdx++].results.map((i: any) => ({ ...i, timestamp: i.time_bucket })) : [];
				const btcData = rMaxTs ? results[pIdx++].results.map((i: any) => ({ ...i, timestamp: i.time_bucket, symbol: 'BTC' })) : [];
				const ethData = rMaxTs ? results[pIdx++].results.map((i: any) => ({ ...i, timestamp: i.time_bucket, symbol: 'ETH' })) : [];

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
				const days = parseInt(url.searchParams.get('days') || '365');
				const result = await cleanupOldData(env.DB, days);
				return new Response(JSON.stringify(result), { headers: corsHeaders });
			}

			return new Response("OK", { status: 200 });
		} catch (err: any) {
			return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
		}
	},

	// --- Cron: Scheduled cleanup ---
	async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
		ctx.waitUntil(cleanupOldData(env.DB, 365));
	},
};

// --- Cleanup: Delete rows older than N days ---
async function cleanupOldData(db: D1Database, days: number): Promise<{ deleted_printer: number; deleted_range: number }> {
	const cutoff = `-${days} days`;

	const [pResult, rResult] = await db.batch([
		db.prepare("DELETE FROM printer_metrics WHERE timestamp < datetime('now', ?)").bind(cutoff),
		db.prepare("DELETE FROM range_metrics WHERE timestamp < datetime('now', ?)").bind(cutoff),
	]);

	return {
		deleted_printer: pResult.meta.changes ?? 0,
		deleted_range: rResult.meta.changes ?? 0,
	};
}
