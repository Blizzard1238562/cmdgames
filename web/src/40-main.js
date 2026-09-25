// ============================================================
//  MAIN - boot, update check, input wiring, headless runner
// ============================================================

A.checkForUpdate = async function () {
    if (A.isNode) { return; }
    try {
        var r = await A.fetchJson('https://raw.githubusercontent.com/Blizzard1238562/cmdgames/refs/heads/main/VERSION.txt', {}, 4000);
        if (!r.ok) { return; }
        var txt = await r.text();
        var m = txt.match(/(\d+\.\d+\.\d+)/);
        if (!m) { return; }
        A.updateRemoteVersion = m[1];
        A.updateKnown = true;
        var a = A.version.split('.'), b = m[1].split('.');
        for (var i = 0; i < 3; i++) {
            var ai = parseInt(a[i] || '0', 10), bi = parseInt(b[i] || '0', 10);
            if (bi > ai) { A.updateAvailable = true; break; }
            if (ai > bi) { break; }
        }
    } catch (e) { }
};

A.splash = async function () {
    A.startScreen(30);
    A.showMenuLogo(8);
    A.setTextCentered(15, 'insert coin...', 'dim');
    A.showFrame();
    await A.sleep(600);
    if (!A.playerName) {
        if (A.isTouch()) {
            // no hardware keyboard on phones/tablets: use a native prompt
            var v = window.prompt('pick a name for the leaderboards', '');
            v = (v === null ? '' : String(v)).replace(/[^A-Za-z0-9 _\-]/g, '').trim().substring(0, 16);
            A.playerName = v || 'guest';
            A.saveConfig();
        } else {
            A.clearFrame();
            A.showMenuLogo(6);
            A.setTextCentered(13, 'first time here - pick a name for the leaderboards', 'dim');
            A.showFrame();
            A.playerName = await A.readPlayerName('');
            A.saveConfig();
        }
    }
};

A.wireKeyboard = function () {
    window.addEventListener('keydown', function (e) {
        if (e.metaKey || e.ctrlKey || e.altKey) { return; }
        var name = A.keyName(e);
        if (name === 'F5' || name === 'F12' || name.indexOf('F') === 0) { return; }
        e.preventDefault();
        A.ensureAudio();
        A.pushKey({ key: name, char: (e.key && e.key.length === 1) ? e.key : '' });
    });
};

A.wireTouch = function () {
    var send = function (name, char) {
        return function (ev) {
            ev.preventDefault();
            A.ensureAudio();
            A.pushKey({ key: name, char: char || '' });
        };
    };
    var bind = function (id, name, ch) {
        var el = document.getElementById(id);
        if (!el) { return; }
        el.addEventListener('touchstart', send(name, ch), { passive: false });
        el.addEventListener('mousedown', send(name, ch));
    };
    bind('t-up', 'UpArrow'); bind('t-down', 'DownArrow');
    bind('t-left', 'LeftArrow'); bind('t-right', 'RightArrow');
    bind('t-a', 'Space', ' ');
    bind('t-q', 'Q', 'q');
    bind('t-m', 'M', 'm');
    bind('t-h', 'H', 'h');
};

A.runHeadless = async function () {
    A.headless = true;
    A.soundOn = false;
    A.playerName = 'tester';
    var failed = [];
    var only = process.env.ARCADE_TEST_GAME || '';
    for (var i = 0; i < A.games.length; i++) {
        var g = A.games[i];
        if (only && g.id !== only) { continue; }
        process.stdout.write('  run  ' + g.name + '\n');
        A.testFrames = 0;
        A.testKeys.length = 0;
        try {
            await g.fn();
            process.stdout.write('  ok   ' + g.name + '\n');
        } catch (e) {
            if (e instanceof A.SelfTestDone) {
                process.stdout.write('  ok   ' + g.name + '  (ran ' + A.testFrames + ' frames)\n');
            } else {
                process.stdout.write('  FAIL ' + g.name + ' -> ' + e.message + '\n');
                failed.push(g.name);
            }
        }
    }
    // menu draw test
    try {
        A.testFrames = 0;
        A.startScreen(30);
        A.showMenu();
        process.stdout.write('  ok   menu\n');
    } catch (e) {
        if (e instanceof A.SelfTestDone) { process.stdout.write('  ok   menu\n'); }
        else { process.stdout.write('  FAIL menu -> ' + e.message + '\n'); failed.push('menu'); }
    }
    process.stdout.write('\n');
    if (failed.length === 0) { process.stdout.write('all games passed the smoke test\n'); }
    else { process.stdout.write('failed: ' + failed.join(', ') + '\n'); process.exit(1); }
};

A.isTouch = function () {
    if (A.isNode) { return false; }
    try { return window.matchMedia('(pointer: coarse)').matches; } catch (e) { return false; }
};

A.boot = async function () {
    A.loadConfig();
    A.loadScoresFile();
    if (A.isNode) { await A.runHeadless(); return; }
    A.initCanvas();
    A.wireKeyboard();
    A.wireTouch();
    A.checkForUpdate();
    try {
        await A.splash();
        await A.showMenu();
    } finally {
        // returning to the page: show a friendly sign-off
        A.startScreen(30);
        A.showMenuLogo(8);
        A.setTextCentered(15, 'thanks for playing - reload to start again', 'dim');
        A.showFrame();
    }
};

// browser entry point (the node selftest drives the games itself)
if (!A.isNode) {
    A.boot().catch(function (e) {
        console.error('PS-ARCADE failed to start:', e);
    });
}
