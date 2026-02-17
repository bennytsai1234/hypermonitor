// --- 1. The Function Under Test ---
// Extraction from scripts/headless_scraper.js
function parseValue(raw) {
    if (!raw) return 0.0;
    // Remove currency symbols and commas
    let clean = raw.toString().replace(/[\$¥,]/g, '').trim();
    let multiplier = 1.0;

    // Check for units
    if (clean.includes('億') || clean.includes('B') || clean.includes('亿')) {
        multiplier = 1e8;
        clean = clean.replace(/[億B亿]/g, '');
    } else if (clean.includes('萬') || clean.includes('M') || clean.includes('万')) {
        multiplier = 1e4;
        clean = clean.replace(/[萬M万]/g, '');
    }

    return (parseFloat(clean) || 0.0) * multiplier;
}

// --- 2. Test Cases ---
const cases = [
    // Traditional Chinese
    { input: "$1.5億", expected: 150000000 },
    { input: "$5,000萬", expected: 50000000 },
    { input: "¥10.5億", expected: 1050000000 },

    // Simplified Chinese
    { input: "$2.3亿", expected: 230000000 },
    { input: "¥500万", expected: 5000000 },

    // English / Number only
    { input: "$1.2B", expected: 120000000 },
    { input: "500M", expected: 5000000 },

    // Edge Cases
    { input: "$0", expected: 0 },
    { input: null, expected: 0 },
    { input: "", expected: 0 },
    { input: "   $ 5.5 億  ", expected: 550000000 }, // Spaces
    { input: "1,234.56", expected: 1234.56 } // No unit
];

// --- 3. Run Tests ---
console.log('🧪 Testing Parsing Logic...\n');
let passed = 0;
let failed = 0;

cases.forEach((c, i) => {
    const result = parseValue(c.input);
    const isPass = Math.abs(result - c.expected) < 0.001; // Float compare

    if (isPass) {
        console.log(`✅ Case ${i+1}: "${c.input}" -> ${result.toLocaleString()} (OK)`);
        passed++;
    } else {
        console.error(`❌ Case ${i+1}: "${c.input}" -> Got ${result}, Expected ${c.expected}`);
        failed++;
    }
});

console.log(`\n🏁 Result: ${passed} Passed, ${failed} Failed.`);

if (failed > 0) process.exit(1);
