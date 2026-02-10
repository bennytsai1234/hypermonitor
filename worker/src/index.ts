export interface Env {
	DB: D1Database;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);
		const corsHeaders = {
			'Content-Type': 'application/json',
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
			'Access-Control-Allow-Headers': '*',
		};

		if (request.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });

		// --- 上傳接口 (保持不變) ---
		if (request.method === 'POST') {
			const d: any = await request.json();
			if (url.pathname === '/update-printer') {
				await env.DB.prepare(`INSERT INTO printer_metrics (wallet_count, profit_count, loss_count, long_vol_num, short_vol_num, net_vol_num, sentiment, long_display, short_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind(d.walletCount, d.profitCount, d.lossCount, d.longVolNum, d.shortVolNum, d.netVolNum, d.sentiment, d.longDisplay, d.shortDisplay, d.netDisplay).run();
			} else if (url.pathname === '/update-range') {
				if (d.btc) await env.DB.prepare(`INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind('btc', d.btc.longVol, d.btc.shortVol, d.btc.totalVol, d.btc.netVol, d.btc.longDisplay, d.btc.shortDisplay, d.btc.totalDisplay, d.btc.netDisplay).run();
				if (d.eth) await env.DB.prepare(`INSERT INTO range_metrics (symbol, long_vol, short_vol, total_vol, net_vol, long_display, short_display, total_display, net_display) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind('eth', d.eth.longVol, d.eth.shortVol, d.eth.totalVol, d.eth.netVol, d.eth.longDisplay, d.eth.shortDisplay, d.eth.totalDisplay, d.eth.netDisplay).run();
			}
			return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
		}

		// --- [修正點]：歷史圖表接口，解決時區與數據量顯示問題 ---
		if (url.pathname === '/history') {
			const range = url.searchParams.get('range') || '1h';
			let interval = 1;
			let filter = "-1 hour";

			switch(range) {
				case '1h': filter = "-1 hour"; interval = 1; break;
				case '2h': filter = "-2 hours"; interval = 1; break;
				case '3h': filter = "-3 hours"; interval = 1; break;
				case '4h': filter = "-4 hours"; interval = 2; break;
				case '5h': filter = "-5 hours"; interval = 2; break;
				case '6h': filter = "-6 hours"; interval = 3; break;
				case '8h': filter = "-8 hours"; interval = 4; break;
				case '12h': filter = "-12 hours"; interval = 5; break;
				case '1d': filter = "-1 day"; interval = 5; break;
				case '2d': filter = "-2 days"; interval = 10; break;
				case '3d': filter = "-3 days"; interval = 15; break;
				case '4d': filter = "-4 days"; interval = 20; break;
				case '5d': filter = "-5 days"; interval = 30; break;
				case '1w': filter = "-7 days"; interval = 60; break;
				case '1m': filter = "-1 month"; interval = 240; break;
				case '3m': filter = "-3 months"; interval = 720; break;
				case '6m': filter = "-6 months"; interval = 1440; break;
				case '1y': filter = "-1 year"; interval = 1440; break;
			}

			// 關鍵修正：改用 (SELECT MAX(timestamp) FROM printer_metrics) 作為基準，避免時區誤差
			const baseQuery = (table: string, symbolCondition: string) => `
				SELECT
					datetime((strftime('%s', timestamp) / (60 * ${interval})) * (60 * ${interval}), 'unixepoch') as time_bucket,
					*
				FROM ${table}
				WHERE timestamp > datetime((SELECT MAX(timestamp) FROM ${table}), ?)
				${symbolCondition}
				GROUP BY time_bucket ORDER BY time_bucket ASC
			`;

			const p = await env.DB.prepare(baseQuery('printer_metrics', '')).bind(filter).all();
			const b = await env.DB.prepare(baseQuery('range_metrics', "AND symbol='btc'")).bind(filter).all();
			const e = await env.DB.prepare(baseQuery('range_metrics', "AND symbol='eth'")).bind(filter).all();

			return new Response(JSON.stringify({
				printer: p.results.map((i:any) => ({ ...i, timestamp: i.time_bucket })),
				btc: b.results.map((i:any) => ({ ...i, timestamp: i.time_bucket, symbol: 'BTC' })),
				eth: e.results.map((i:any) => ({ ...i, timestamp: i.time_bucket, symbol: 'ETH' }))
			}), { headers: corsHeaders });
		}

		if (url.pathname === '/latest') {
			const p = await env.DB.prepare("SELECT * FROM printer_metrics ORDER BY timestamp DESC LIMIT 1").first();
			const btc = await env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='btc' ORDER BY timestamp DESC LIMIT 1").first();
			const eth = await env.DB.prepare("SELECT * FROM range_metrics WHERE symbol='eth' ORDER BY timestamp DESC LIMIT 1").first();
			return new Response(JSON.stringify({
				...p, btc: btc ? { ...btc, symbol: 'BTC' } : null, eth: eth ? { ...eth, symbol: 'ETH' } : null
			}), { headers: corsHeaders });
		}

		return new Response("OK", { status: 200 });
	}
};
