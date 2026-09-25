// Headless self-test for the web build (run: node web/selftest.js).
// Mirrors arcade.ps1 -SelfTest: drives every game with synthetic keys,
// verifies challenge-code interop with the PS implementation.
var fs = require('fs');
var path = require('path');
var vm = require('vm');

var code = fs.readFileSync(path.join(__dirname, 'app.js'), 'utf8');
vm.runInThisContext(code, { filename: 'app.js' });

var failed = 0;
var only = process.env.ARCADE_TEST_GAME || '';
A.headless = true;
A.soundOn = false;
A.playerName = 'tester';

// ---- interop vectors (must match the PowerShell implementation) ----
// letter1 = alphabet[gameIdx], letter2 = alphabet[(gameIdx*7+5)%24]
var vectors = [
    ['snake', 0, 'AF-000000-0'],
    ['snake', 999999, 'AF-999999-9'],
    ['tetris', 1234, 'BN-001234-3'],
    ['2048', 2048, 'CV-002048-6'],
    ['ttt', 500, 'JP-000500-2'],
    ['pong', 4321, 'LD-004321-1']
];
var gameIdx = function (id) {
    for (var i = 0; i < A.games.length; i++) { if (A.games[i].id === id) { return i; } }
    return -1;
};
for (var v = 0; v < vectors.length; v++) {
    var vec = vectors[v];
    var enc = A.challengeCode(vec[0], vec[1]);
    if (enc !== vec[2]) {
        console.log('FAIL encode ' + vec[0] + ' ' + vec[1] + ': got ' + enc + ' want ' + vec[2]);
        failed++;
    }
    var dec = A.challengeTarget(vec[2]);
    if (!dec || dec.gameIdx !== gameIdx(vec[0]) || dec.score !== vec[1]) {
        console.log('FAIL decode ' + vec[2]);
        failed++;
    }
}
// tamper checks
if (A.challengeTarget('AZ-000000-0') !== null) { console.log('FAIL letter tamper accepted'); failed++; }
if (A.challengeTarget('AA-000001-0') !== null) { console.log('FAIL checksum tamper accepted'); failed++; }
if (A.challengeTarget('garbage') !== null) { console.log('FAIL junk accepted'); failed++; }

// registry
if (A.games.length !== 11) { console.log('FAIL registry size ' + A.games.length); failed++; }
var ids = A.games.map(function (g) { return g.id; });
if (new Set(ids).size !== 11) { console.log('FAIL duplicate ids'); failed++; }
for (var r = 0; r < A.games.length; r++) {
    if (typeof A.games[r].fn !== 'function') { console.log('FAIL fn missing ' + A.games[r].id); failed++; }
}

// ---- headless game runs, sequentially ----
var runGames = async function () {
    for (var gi = 0; gi < A.games.length; gi++) {
        var g = A.games[gi];
        if (only && g.id !== only) { continue; }
        console.log('  run  ' + g.name);
        A.testFrames = 0;
        A.testKeys.length = 0;
        try {
            await g.fn();
            console.log('  ok   ' + g.name);
        } catch (e) {
            if (e instanceof A.SelfTestDone) {
                console.log('  ok   ' + g.name + '  (ran ' + A.testFrames + ' frames)');
            } else {
                console.log('  FAIL ' + g.name + ' -> ' + e.message);
                console.log(e.stack);
                failed++;
            }
        }
    }
    // menu test
    try {
        A.testFrames = 0;
        A.startScreen(30);
        await A.showMenu();
        console.log('  ok   menu');
    } catch (e) {
        if (e instanceof A.SelfTestDone) { console.log('  ok   menu'); }
        else { console.log('  FAIL menu -> ' + e.message); failed++; }
    }
    console.log('');
    if (failed === 0) { console.log('all games passed the smoke test'); process.exit(0); }
    else { console.log('failed: ' + failed + ' check(s)'); process.exit(1); }
};

runGames();
