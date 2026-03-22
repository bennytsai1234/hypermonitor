const fs = require('fs');
const txt = fs.readFileSync('backtest_v4_results.txt', 'utf8');
console.log(txt);
