// ============================================================
//  PS-ARCADE WEB - generated file, do not edit by hand.
//  Edit files in web/src/ and run web/build.ps1 instead.
// ============================================================

// ---- 00-core.js ----
// ============================================================
//  CORE - namespace, palette, shared constants
// ============================================================

var A = globalThis.A = globalThis.A || {};

A.version = '1.2.0';
A.appName = 'PS-ARCADE';
A.headless = false;          // true = no rendering, frames counted (selftest)
A.testFrames = 0;
A.testKeys = [];             // queued key names for the headless driver
A.isNode = (typeof document === 'undefined');
A.supabaseUrl = 'https://daoothvdwxbfyocyapkl.supabase.co';
A.supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhb290aHZkd3hiZnlvY3lhcGtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAyNDA5NjcsImV4cCI6MjEwNTgxNjk2N30.vKGTNe3zGyAoA6-9BObEjmIVa5r3Z1dHyMm7223Xh-E';
A.updateAvailable = false;
A.updateKnown = false;
A.updateRemoteVersion = '';

// same 256-color palette as src/00-header.ps1
A.palette = {
    bg: 235, bg2: 237, fg: 250, dim: 245, accent: 108,
    green: 107, red: 174, orange: 179, yellow: 180, blue: 109,
    purple: 139, cyan: 116, white: 254, wall: 240, ink: 234
};

A.colorCode = function (name) {
    var c = A.palette[name];
    return (c === undefined) ? 250 : c;
};

// xterm 256-color -> css rgb
A.codeToRgb = function (n) {
    n = n | 0;
    if (n < 16) {
        var base = [
            [0, 0, 0], [205, 0, 0], [0, 205, 0], [205, 205, 0],
            [0, 0, 238], [205, 0, 205], [0, 205, 205], [229, 229, 229],
            [127, 127, 127], [255, 0, 0], [0, 255, 0], [255, 255, 0],
            [92, 92, 255], [255, 0, 255], [0, 255, 255], [255, 255, 255]
        ];
        return base[n];
    }
    if (n >= 232) {
        var g = 8 + (n - 232) * 10;
        return [g, g, g];
    }
    var i = n - 16;
    var ch = [0, 95, 135, 175, 215, 255];
    var r = ch[Math.floor(i / 36)];
    var gg = ch[Math.floor((i % 36) / 6)];
    var b = ch[i % 6];
    return [r, gg, b];
};

A.cssColor = function (n) {
    var c = A.codeToRgb(n);
    return 'rgb(' + c[0] + ',' + c[1] + ',' + c[2] + ')';
};

// console key names, PS style ('Space' not 'Spacebar', 'UpArrow', ...)
A.keyName = function (e) {
    var k = e.key;
    if (k === ' ') { return 'Space'; }
    if (k === 'ArrowUp') { return 'UpArrow'; }
    if (k === 'ArrowDown') { return 'DownArrow'; }
    if (k === 'ArrowLeft') { return 'LeftArrow'; }
    if (k === 'ArrowRight') { return 'RightArrow'; }
    if (k === 'Escape') { return 'Escape'; }
    if (k === 'Enter') { return 'Enter'; }
    if (k === 'Backspace') { return 'Backspace'; }
    if (k === '?') { return 'OemQuestion'; }
    if (k.length === 1) { return k.toUpperCase(); }
    return k;
};

// unicode glyphs (same codepoints as the PS engine)
A.ch = {
    BL: '\u250C', BH: '\u2500', BR: '\u2510', BV: '\u2502',
    FL: '\u2514', FR: '\u2518', Full: '\u2588', Med: '\u2592',
    Light: '\u2591', Dot: '\u00B7', Diam: '\u25C6', Heart: '\u2665',
    Star: '\u263C', Arrow: '>'
};


// ---- 01-engine.js ----
// ============================================================
//  ENGINE - frame buffer, drawing, rendering, input, sound
// ============================================================

A.FbW = 80;
A.FbH = 30;
A.FbCh = null; A.FbFg = null; A.FbBg = null;

A.SelfTestDone = function () { this.name = 'SelfTestDone'; };
A.SelfTestDone.prototype = Object.create(Error.prototype);

// ---- frame buffer ----

A.startScreen = function (h) {
    A.newFrame(80, h || 30, 'bg');
};

A.newFrame = function (w, h, bg) {
    A.FbW = w; A.FbH = h;
    var n = w * h;
    A.FbCh = new Array(n);
    A.FbFg = new Array(n);
    A.FbBg = new Array(n);
    A.clearFrame(bg || 'bg');
};

A.clearFrame = function (bg) {
    var fc = A.colorCode('fg');
    var bc = A.colorCode(bg || 'bg');
    for (var i = 0; i < A.FbCh.length; i++) {
        A.FbCh[i] = ' '; A.FbFg[i] = fc; A.FbBg[i] = bc;
    }
};

A.setCell = function (x, y, chr, fg, bg) {
    if (x < 0 || x >= A.FbW || y < 0 || y >= A.FbH) { return; }
    var i = y * A.FbW + x;
    if (chr && chr.length > 0) { A.FbCh[i] = chr.charAt(0); }
    if (fg) { A.FbFg[i] = A.colorCode(fg); }
    if (bg) { A.FbBg[i] = A.colorCode(bg); }
};

A.setText = function (x, y, text, fg, bg) {
    if (y < 0 || y >= A.FbH) { return; }
    var fc = A.colorCode(fg || 'fg');
    var bc = (bg === undefined || bg === null) ? -1 : A.colorCode(bg);
    var row = y * A.FbW;
    var len = text.length;
    for (var i = 0; i < len; i++) {
        var cx = x + i;
        if (cx < 0 || cx >= A.FbW) { continue; }
        var idx = row + cx;
        A.FbCh[idx] = text.charAt(i);
        A.FbFg[idx] = fc;
        if (bc >= 0) { A.FbBg[idx] = bc; }
    }
};

A.setTextCentered = function (y, text, fg, bg) {
    var x = Math.floor((A.FbW - text.length) / 2);
    A.setText(x, y, text, fg, bg);
};

A.setTextRight = function (y, text, fg, bg) {
    A.setText(A.FbW - text.length - 2, y, text, fg, bg);
};

A.drawBox = function (x, y, w, h, title, fg, bg, fillBg) {
    var useBg = A.colorCode(fillBg || bg || 'bg');
    var fgc = A.colorCode(fg || 'wall');
    var x1 = x + w - 1, y1 = y + h - 1;
    for (var yy = y; yy <= y1; yy++) {
        if (yy < 0 || yy >= A.FbH) { continue; }
        var row = yy * A.FbW;
        var top = (yy === y), bot = (yy === y1);
        for (var xx = x; xx <= x1; xx++) {
            if (xx < 0 || xx >= A.FbW) { continue; }
            var i = row + xx, ch = ' ';
            if (xx === x) {
                if (top) { ch = A.ch.BL; } else if (bot) { ch = A.ch.FL; } else { ch = A.ch.BV; }
            } else if (xx === x1) {
                if (top) { ch = A.ch.BR; } else if (bot) { ch = A.ch.FR; } else { ch = A.ch.BV; }
            } else if (top || bot) {
                ch = A.ch.BH;
            }
            A.FbCh[i] = ch; A.FbFg[i] = fgc; A.FbBg[i] = useBg;
        }
    }
    if (title && title.length > 0) {
        var tx = x + Math.floor((w - title.length) / 2);
        A.setText(tx, y, title, 'fg', fillBg || bg || 'bg');
    }
};

A.gameHeader = function (title, score, right) {
    A.setText(2, 1, title.toUpperCase(), 'accent');
    A.setText(2, 2, 'score ' + score, 'dim');
    if (right && right.length > 0) { A.setTextRight(1, right, 'dim'); }
    A.setTextRight(2, 'm mute - q menu', 'dim');
};

// ---- rendering (canvas) ----

A.canvas = null; A.ctx = null;
A.cellW = 9; A.cellH = 16;

A.initCanvas = function () {
    if (A.isNode) { return; }
    A.canvas = document.getElementById('screen');
    A.ctx = A.canvas.getContext('2d');
    var dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    A.canvas.width = A.FbW * A.cellW * dpr;
    A.canvas.height = A.FbH * A.cellH * dpr;
    A.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    A.fitCanvas();
    window.addEventListener('resize', A.fitCanvas);
};

A.fitCanvas = function () {
    if (!A.canvas) { return; }
    var availW = window.innerWidth - 8;
    var availH = window.innerHeight - 8;
    var scale = Math.min(availW / (A.FbW * A.cellW), availH / (A.FbH * A.cellH));
    scale = Math.max(0.4, Math.min(2.2, scale));
    A.canvas.style.width = Math.floor(A.FbW * A.cellW * scale) + 'px';
    A.canvas.style.height = Math.floor(A.FbH * A.cellH * scale) + 'px';
};

A.showFrame = function () {
    if (A.headless) { return; }
    var ctx = A.ctx, cw = A.cellW, chh = A.cellH;
    ctx.textBaseline = 'middle';
    ctx.font = 'bold 14px Menlo, Consolas, "Courier New", monospace';
    for (var y = 0; y < A.FbH; y++) {
        var row = y * A.FbW;
        var last = A.FbW - 1;
        while (last >= 0 && A.FbCh[row + last] === ' ') { last--; }
        // paint the row background in runs (full width, then glyphs)
        var x = 0;
        while (x < A.FbW) {
            var b = A.FbBg[row + x];
            var x2 = x;
            while (x2 + 1 < A.FbW && A.FbBg[row + x2 + 1] === b) { x2++; }
            ctx.fillStyle = A.cssColor(b);
            ctx.fillRect(x * cw, y * chh, (x2 - x + 1) * cw, chh);
            x = x2 + 1;
        }
        // glyphs
        for (var gx = 0; gx <= last; gx++) {
            var c = A.FbCh[row + gx];
            if (c === ' ') { continue; }
            ctx.fillStyle = A.cssColor(A.FbFg[row + gx]);
            ctx.fillText(c, gx * cw + cw / 2, y * chh + chh / 2 + 1);
        }
    }
};

// ---- input ----

A.keyQueue = [];
A.keyWaiters = [];

A.pushKey = function (entry) {
    // entry: { key: 'Space', char: ' ' } (key name in PS convention)
    A.keyQueue.push(entry);
    var waiters = A.keyWaiters.splice(0);
    for (var i = 0; i < waiters.length; i++) { waiters[i](); }
};

A.keysPressed = function () {
    var out = [];
    if (A.headless) {
        while (A.testKeys.length > 0) { out.push(A.testKeys.shift()); }
        return out;
    }
    while (A.keyQueue.length > 0) { out.push(A.keyQueue.shift().key); }
    return out;
};

A.clearKeyBuffer = function () {
    if (A.headless) { A.testKeys.length = 0; return; }
    A.keyQueue.length = 0;
};

A.sleep = function (ms) {
    return new Promise(function (res) { setTimeout(res, ms); });
};

A.waitRealKey = async function () {
    if (A.headless) { return 'Escape'; }
    if (A.keyQueue.length > 0) { return A.keyQueue.shift().key; }
    await new Promise(function (res) { A.keyWaiters.push(res); });
    if (A.keyQueue.length > 0) { return A.keyQueue.shift().key; }
    return 'Escape';
};

A.waitRealKeyChar = async function () {
    if (A.headless) { return { key: 'Escape', char: '' }; }
    var e = null;
    if (A.keyQueue.length > 0) { e = A.keyQueue.shift(); }
    else {
        await new Promise(function (res) { A.keyWaiters.push(res); });
        if (A.keyQueue.length > 0) { e = A.keyQueue.shift(); }
    }
    if (!e) { return { key: 'Escape', char: '' }; }
    return { key: e.key, char: (e.char === undefined) ? '' : e.char };
};

A.waitKeyOrIdle = async function (seconds) {
    if (A.headless) { return 'Escape'; }
    var deadline = Date.now() + seconds * 1000;
    while (Date.now() < deadline) {
        if (A.keyQueue.length > 0) { return A.keyQueue.shift().key; }
        await A.sleep(30);
    }
    return null;
};

// ---- timing / frames ----

A.frameStart = Date.now();

A.startFrames = function () { A.frameStart = Date.now(); };

A.waitFrame = async function (ms) {
    if (A.headless) {
        A.testFrames++;
        if (A.testFrames > 120) { throw new A.SelfTestDone(); }
        return;
    }
    var target = A.frameStart + ms;
    var now = Date.now();
    if (target > now) { await A.sleep(target - now); }
    A.frameStart = Date.now();
};

A.arcadeSleep = async function (ms) {
    if (A.headless) { return; }
    await A.sleep(ms);
};

// ---- sound ----

A.soundOn = true;
A.audioCtx = null;

A.ensureAudio = function () {
    if (A.isNode || A.audioCtx) { return; }
    try {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (AC) { A.audioCtx = new AC(); }
    } catch (e) { A.audioCtx = null; }
};

A.beep = function (freq, ms) {
    if (!A.soundOn || A.headless) { return; }
    A.ensureAudio();
    if (!A.audioCtx) { return; }
    try {
        if (A.audioCtx.state === 'suspended') { A.audioCtx.resume(); }
        var o = A.audioCtx.createOscillator();
        var g = A.audioCtx.createGain();
        o.type = 'square';
        o.frequency.value = freq;
        g.gain.value = 0.035;
        o.connect(g); g.connect(A.audioCtx.destination);
        var t = A.audioCtx.currentTime;
        o.start(t);
        g.gain.setValueAtTime(0.035, t + Math.max(0, (ms - 20) / 1000));
        g.gain.exponentialRampToValueAtTime(0.0001, t + ms / 1000);
        o.stop(t + ms / 1000 + 0.02);
    } catch (e) { }
};

// ---- mute toggle ----

A.muteToggleRequested = function (keys) {
    if (keys.indexOf('M') >= 0) {
        A.soundOn = !A.soundOn;
        A.saveConfig();
        return true;
    }
    return false;
};


// ---- 02-scores.js ----
// ============================================================
//  SCORES - config, local highscores, global Supabase board
// ============================================================

A.config = { name: '', sound: true };
A.scoresData = {};
A.playerName = '';
A.pendingOnline = {};
A.pendingLastTry = 0;
A.sessionRuns = 0;
A.sessionBestRank = 0;

A.storageGet = function (key) {
    if (A.isNode) { return null; }
    try { return localStorage.getItem(key); } catch (e) { return null; }
};
A.storageSet = function (key, val) {
    if (A.isNode) { return; }
    try { localStorage.setItem(key, val); } catch (e) { }
};

A.loadConfig = function () {
    var raw = A.storageGet('psarcade.config');
    if (raw) {
        try {
            var c = JSON.parse(raw);
            if (c && typeof c.name === 'string') { A.playerName = c.name; }
            if (c && typeof c.sound === 'boolean') { A.soundOn = c.sound; }
        } catch (e) { }
    }
};
A.saveConfig = function () {
    A.config.name = A.playerName;
    A.config.sound = A.soundOn;
    A.storageSet('psarcade.config', JSON.stringify(A.config));
};
A.loadScoresFile = function () {
    var raw = A.storageGet('psarcade.scores');
    if (raw) {
        try { A.scoresData = JSON.parse(raw) || {}; } catch (e) { A.scoresData = {}; }
    }
};
A.saveScoresFile = function () {
    A.storageSet('psarcade.scores', JSON.stringify(A.scoresData));
};

A.getLocalScores = function (gameId) {
    var l = A.scoresData[gameId];
    if (!l) { return []; }
    return l;
};

A.addLocalScore = function (gameId, name, score) {
    var list = (A.scoresData[gameId] || []).slice();
    list.push({ name: name, score: score, when: new Date().toISOString().slice(0, 10) });
    list.sort(function (a, b) { return b.score - a.score; });
    if (list.length > 10) { list = list.slice(0, 10); }
    var rank = -1;
    for (var i = 0; i < list.length; i++) {
        if (rank < 0 && list[i].score === score && list[i].name === name) { rank = i + 1; }
    }
    A.scoresData[gameId] = list;
    A.saveScoresFile();
    return rank;
};

A.testOnlineScores = function () { return true; };

A.fetchJson = async function (url, opts, timeoutMs) {
    var ctrl = (typeof AbortController !== 'undefined') ? new AbortController() : null;
    var timer = null;
    if (ctrl) {
        timer = setTimeout(function () { ctrl.abort(); }, timeoutMs || 5000);
        opts = opts || {};
        opts.signal = ctrl.signal;
    }
    try {
        var r = await fetch(url, opts);
        if (ctrl) { clearTimeout(timer); }
        return r;
    } catch (e) {
        if (ctrl) { clearTimeout(timer); }
        throw e;
    }
};

A.sendOnlineScore = async function (gameId, name, score) {
    try {
        var r = await A.fetchJson(A.supabaseUrl + '/rest/v1/rpc/submit_score', {
            method: 'POST',
            headers: {
                'apikey': A.supabaseKey,
                'Authorization': 'Bearer ' + A.supabaseKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ p_game: gameId, p_name: name, p_score: score })
        }, 5000);
        return r.ok;
    } catch (e) { return false; }
};

A.addPendingOnlineScore = function (gameId, score) {
    if (A.pendingOnline[gameId] === undefined || score > A.pendingOnline[gameId]) {
        A.pendingOnline[gameId] = score;
    }
};

A.flushPendingOnlineScores = async function () {
    var ids = Object.keys(A.pendingOnline);
    if (ids.length === 0) { return; }
    var now = Date.now();
    if (now - A.pendingLastTry < 45000) { return; }
    A.pendingLastTry = now;
    for (var i = 0; i < ids.length; i++) {
        var gid = ids[i];
        var ok = await A.sendOnlineScore(gid, A.playerName, A.pendingOnline[gid]);
        if (ok) { delete A.pendingOnline[gid]; }
    }
};

A.getOnlineScores = async function (gameId) {
    try {
        var r = await A.fetchJson(A.supabaseUrl + '/rest/v1/scores?game=eq.' + gameId +
            '&select=name,score,created_at&order=score.desc,created_at.asc&limit=10', {
            headers: { 'apikey': A.supabaseKey, 'Authorization': 'Bearer ' + A.supabaseKey }
        }, 4000);
        if (!r.ok) { return null; }
        var rows = await r.json();
        var list = [];
        for (var i = 0; i < rows.length; i++) { list.push({ name: rows[i].name, score: rows[i].score }); }
        return list;
    } catch (e) { return null; }
};

// ---- in-game name prompt (frame buffer, like the console version) ----

A.readPlayerName = async function (def) {
    var name = def || '';
    var cy = Math.floor(A.FbH / 2) + 2;
    while (true) {
        var shown = (name.length === 0) ? '_' : name;
        A.drawBox(24, cy - 3, 32, 5, ' enter your name ', 'accent', null, 'bg2');
        A.setText(27, cy - 1, ('> ' + shown).padEnd(26), 'white', 'bg2');
        A.setText(27, cy + 1, 'letters/numbers, max 16'.padEnd(26), 'dim', 'bg2');
        A.showFrame();
        var k = await A.waitRealKeyChar();
        if (k.key === 'Enter') { break; }
        if (k.key === 'Escape') { name = def || ''; break; }
        if (k.key === 'Backspace') {
            if (name.length > 0) { name = name.substring(0, name.length - 1); }
        } else if (name.length < 16) {
            var ch = k.char;
            if (ch && /[A-Za-z0-9 _\-]/.test(ch)) { name += ch; }
        }
    }
    name = name.trim();
    if (name.length === 0) { name = 'anonymous'; }
    return name;
};

// ---- game over / score flow ----

A.showGameOverScreen = async function (gameName, score, note, subNote) {
    A.drawBox(20, 11, 40, 8, ' game over ', 'red', null, 'bg2');
    A.setTextCentered(13, gameName + ' - score ' + score, 'white', 'bg2');
    if (note && note.length > 0) { A.setTextCentered(14, note, 'yellow', 'bg2'); }
    if (subNote && subNote.length > 0) { A.setTextCentered(15, subNote, 'dim', 'bg2'); }
    A.setTextCentered(16, '[R] play again    [Q] menu', 'fg', 'bg2');
    A.showFrame();
    A.clearKeyBuffer();
    while (true) {
        var k = await A.waitRealKey();
        if (A.headless) { return false; }
        if (k === 'R') { return true; }
        if (k === 'Q' || k === 'Escape' || k === 'Enter') { return false; }
    }
};

A.completeGame = async function (gameId, gameName, score, note) {
    if (A.headless) { return false; }
    note = note || '';
    var sub = '';
    var code = '';
    try { code = A.challengeCode(gameId, score); } catch (e) { }
    if (score > 0) {
        A.sessionRuns++;
        await A.flushPendingOnlineScores();
        var locals = A.getLocalScores(gameId);
        var prevBest = 0;
        for (var i = 0; i < locals.length; i++) {
            if (locals[i].name === A.playerName && locals[i].score > prevBest) { prevBest = locals[i].score; }
        }
        var rank = A.addLocalScore(gameId, A.playerName, score);
        var online = false;
        if (A.testOnlineScores()) {
            online = await A.sendOnlineScore(gameId, A.playerName, score);
            if (!online) { A.addPendingOnlineScore(gameId, score); }
        }
        if (score > prevBest) { note = 'new personal best!'; }
        else if (note === '' && code !== '') { note = 'run code: ' + code; }
        var rankTxt = (rank > 0) ? (' - rank #' + rank) : '';
        var codeTxt = (code !== '') ? (' - ' + code) : '';
        sub = (online ? 'score uploaded' : 'saved locally') + rankTxt + codeTxt;
        if (rank === 1) {
            A.beep(660, 60); A.beep(880, 90); A.beep(1100, 120);
        } else if (score > prevBest && prevBest > 0) {
            A.beep(520, 50); A.beep(700, 70);
        }
        if (rank > A.sessionBestRank) { A.sessionBestRank = rank; }
    }
    return await A.showGameOverScreen(gameName, score, note, sub);
};


// ---- 10-games-a.js ----
// ============================================================
//  GAMES A - snake, tetris, 2048, invaders
// ============================================================

var startSnake = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bx = 10, by = 6, bw = 60, bh = 20;
        var grid = {};
        var snake = [];
        var sx = bx + 12, sy = by + Math.floor(bh / 2);
        for (var i = 0; i <= 4; i++) { snake.push({ x: sx - i, y: sy }); }
        for (var s = 0; s < snake.length; s++) { grid[snake[s].x + ',' + snake[s].y] = true; }
        var dir = { x: 1, y: 0 };
        var pending = null;
        var score = 0;
        var speedMs = 90;
        var alive = true;

        var placeFood = function () {
            var free = [];
            for (var y = by; y < by + bh; y++) {
                for (var x = bx; x < bx + bw; x++) {
                    if (!grid[x + ',' + y]) { free.push([x, y]); }
                }
            }
            if (free.length === 0) { return null; }
            return free[Math.floor(Math.random() * free.length)];
        };
        var food = placeFood();

        try {
            while (true) {
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                for (var ki = 0; ki < keys.length; ki++) {
                    var k = keys[ki];
                    if (k === 'UpArrow' && dir.y === 0) { pending = { x: 0, y: -1 }; }
                    else if (k === 'DownArrow' && dir.y === 0) { pending = { x: 0, y: 1 }; }
                    else if (k === 'LeftArrow' && dir.x === 0) { pending = { x: -1, y: 0 }; }
                    else if (k === 'RightArrow' && dir.x === 0) { pending = { x: 1, y: 0 }; }
                    else if (k === 'W' && dir.y === 0) { pending = { x: 0, y: -1 }; }
                    else if (k === 'S' && dir.y === 0) { pending = { x: 0, y: 1 }; }
                    else if (k === 'A' && dir.x === 0) { pending = { x: -1, y: 0 }; }
                    else if (k === 'D' && dir.x === 0) { pending = { x: 1, y: 0 }; }
                }
                if (pending) { dir = pending; pending = null; }
                var head = snake[0];
                var nx = head.x + dir.x, ny = head.y + dir.y;
                if (nx < bx || nx >= bx + bw || ny < by || ny >= by + bh || grid[nx + ',' + ny]) {
                    alive = false;
                    A.beep(120, 180);
                    break;
                }
                snake.unshift({ x: nx, y: ny });
                grid[nx + ',' + ny] = true;
                if (food && nx === food[0] && ny === food[1]) {
                    score += 10;
                    A.beep(660, 30);
                    food = placeFood();
                    if (score % 50 === 0 && speedMs > 45) { speedMs -= 6; }
                } else {
                    var tail = snake.pop();
                    delete grid[tail.x + ',' + tail.y];
                }

                A.clearFrame();
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                A.gameHeader('Snake', score, 'len ' + snake.length);
                A.setTextCentered(28, 'arrows/wasd steer - q menu', 'dim');
                if (food) { A.setCell(food[0], food[1], A.ch.Diam, 'red'); }
                for (var si = snake.length - 1; si >= 0; si--) {
                    var seg = snake[si];
                    if (si === 0) { A.setCell(seg.x, seg.y, '@', 'white'); }
                    else { A.setCell(seg.x, seg.y, A.ch.Full, 'green'); }
                }
                A.showFrame();
                await A.waitFrame(speedMs);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('snake', 'Snake', score))) { break; }
    }
};

var TetrisShapes = {
    I: [[0, 1], [1, 1], [2, 1], [3, 1]], O: [[1, 0], [2, 0], [1, 1], [2, 1]],
    T: [[1, 0], [0, 1], [1, 1], [2, 1]], S: [[1, 0], [2, 0], [0, 1], [1, 1]],
    Z: [[0, 0], [1, 0], [1, 1], [2, 1]], J: [[0, 0], [0, 1], [1, 1], [2, 1]],
    L: [[2, 0], [0, 1], [1, 1], [2, 1]]
};
var TetrisColors = { I: 'cyan', O: 'yellow', T: 'purple', S: 'green', Z: 'red', J: 'blue', L: 'orange' };

var tetrisRotated = function (kind, rot) {
    var base = TetrisShapes[kind];
    var out = [];
    for (var i = 0; i < base.length; i++) {
        var x = base[i][0], y = base[i][1];
        var r = rot % 4;
        if (r === 0) { out.push([x, y]); }
        else if (r === 1) { out.push([(3 - y), x]); }
        else if (r === 2) { out.push([(3 - x), (3 - y)]); }
        else { out.push([y, (3 - x)]); }
    }
    return out;
};

var startTetris = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 12, bh = 20, ox = 26, oy = 5;
        var grid = {};
        var bag = [];
        var score = 0, lines = 0, level = 1;
        var dropMs = 500;
        var gameOver = false;

        var refillBag = function () {
            var kinds = ['I', 'O', 'T', 'S', 'Z', 'J', 'L'];
            for (var i = kinds.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1));
                var t = kinds[i]; kinds[i] = kinds[j]; kinds[j] = t;
            }
            for (var n = 0; n < kinds.length; n++) { bag.push(kinds[n]); }
        };
        var newPiece = function () {
            if (bag.length === 0) { refillBag(); }
            var kind = bag.shift();
            if (bag.length === 0) { refillBag(); }
            return { kind: kind, rot: 0, x: 4, y: -1 };
        };
        var tetrisFits = function (piece, dx, dy, rot) {
            var cells = tetrisRotated(piece.kind, rot);
            for (var i = 0; i < cells.length; i++) {
                var x = piece.x + cells[i][0] + dx, y = piece.y + cells[i][1] + dy;
                if (x < 0 || x >= bw || y >= bh) { return false; }
                if (y >= 0 && grid[x + ',' + y]) { return false; }
            }
            return true;
        };
        var lockPiece = function (piece) {
            var cells = tetrisRotated(piece.kind, piece.rot);
            for (var i = 0; i < cells.length; i++) {
                var x = piece.x + cells[i][0], y = piece.y + cells[i][1];
                if (y < 0) { return true; }
                grid[x + ',' + y] = piece.kind;
            }
            return false;
        };
        var clearLines = function () {
            var cleared = 0;
            for (var y = bh - 1; y >= 0; y--) {
                var full = true;
                for (var x = 0; x < bw; x++) { if (!grid[x + ',' + y]) { full = false; break; } }
                if (full) {
                    cleared++;
                    for (var yy = y; yy > 0; yy--) {
                        for (var x2 = 0; x2 < bw; x2++) {
                            if (grid[x2 + ',' + (yy - 1)]) { grid[x2 + ',' + yy] = grid[x2 + ',' + (yy - 1)]; }
                            else { delete grid[x2 + ',' + yy]; }
                        }
                    }
                    for (var x3 = 0; x3 < bw; x3++) { delete grid[x3 + ',0']; }
                    y++;
                }
            }
            return cleared;
        };
        var piece = newPiece();
        var tick = 0;

        try {
            while (true) {
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                for (var ki = 0; ki < keys.length; ki++) {
                    var k = keys[ki];
                    if (k === 'LeftArrow') { if (tetrisFits(piece, -1, 0, piece.rot)) { piece.x--; A.beep(220, 15); } }
                    else if (k === 'RightArrow') { if (tetrisFits(piece, 1, 0, piece.rot)) { piece.x++; A.beep(220, 15); } }
                    else if (k === 'DownArrow') { if (tetrisFits(piece, 0, 1, piece.rot)) { piece.y++; score += 1; } }
                    else if (k === 'UpArrow') { if (tetrisFits(piece, 0, 0, piece.rot + 1)) { piece.rot++; A.beep(330, 20); } }
                    else if (k === 'Space') { while (tetrisFits(piece, 0, 1, piece.rot)) { piece.y++; score += 2; } A.beep(180, 40); }
                }

                tick++;
                var dropped = false;
                if (A.headless || (tick % Math.max(1, Math.floor(dropMs / 50))) === 0) {
                    if (tetrisFits(piece, 0, 1, piece.rot)) {
                        piece.y++;
                    } else {
                        var over = lockPiece(piece);
                        var n = clearLines();
                        if (n > 0) {
                            lines += n;
                            score += [0, 100, 300, 500, 800][n] * level;
                            level = 1 + Math.floor(lines / 8);
                            dropMs = Math.max(120, 500 - ((level - 1) * 45));
                            A.beep(520, 50); A.beep(700, 60);
                        } else {
                            A.beep(140, 40);
                        }
                        if (over) { gameOver = true; break; }
                        piece = newPiece();
                        if (!tetrisFits(piece, 0, 0, piece.rot)) { gameOver = true; break; }
                    }
                    dropped = true;
                }
                if (!dropped) { await A.sleep(50); }

                A.clearFrame();
                A.gameHeader('Tetris', score, 'lvl ' + level + '  lines ' + lines);
                A.drawBox(ox - 1, oy - 1, bw * 2 + 2, bh + 2, null, 'wall');
                for (var key in grid) {
                    var p = key.split(',');
                    var gx = parseInt(p[0], 10), gy = parseInt(p[1], 10);
                    A.setText(ox + gx * 2, oy + gy, '[]', TetrisColors[grid[key]]);
                }
                var cells = tetrisRotated(piece.kind, piece.rot);
                for (var ci = 0; ci < cells.length; ci++) {
                    var cx = piece.x + cells[ci][0], cy = piece.y + cells[ci][1];
                    if (cy >= 0) { A.setText(ox + cx * 2, oy + cy, '[]', TetrisColors[piece.kind]); }
                }
                var nxp = ox + bw * 2 + 4;
                A.setText(nxp, oy + 1, 'NEXT', 'dim');
                var nc = TetrisShapes[bag[0]];
                if (nc) { for (var ni = 0; ni < nc.length; ni++) { A.setText(nxp + nc[ni][0] * 2, oy + 3 + nc[ni][1], '[]', TetrisColors[bag[0]]); } }
                A.setText(nxp, oy + 8, 'arrows move', 'dim');
                A.setText(nxp, oy + 9, 'up rotate', 'dim');
                A.setText(nxp, oy + 10, 'space drop', 'dim');
                A.showFrame();
                await A.waitFrame(50);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('tetris', 'Tetris', score))) { break; }
    }
};

var startG2048 = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var cells = new Array(16).fill(0);
        var score = 0;
        var won = false;

        var addTile = function () {
            var empty = [];
            for (var i = 0; i < 16; i++) { if (cells[i] === 0) { empty.push(i); } }
            if (empty.length === 0) { return false; }
            cells[empty[Math.floor(Math.random() * empty.length)]] = (Math.floor(Math.random() * 10) === 0) ? 4 : 2;
            return true;
        };
        var slide = function (idx) {
            var vals = [];
            for (var i = 0; i < idx.length; i++) { if (cells[idx[i]] !== 0) { vals.push(cells[idx[i]]); cells[idx[i]] = 0; } }
            var gained = 0;
            var out = [];
            for (var j = 0; j < vals.length; j++) {
                if (j < vals.length - 1 && vals[j] === vals[j + 1]) {
                    out.push(vals[j] * 2);
                    gained += vals[j] * 2;
                    j++;
                } else {
                    out.push(vals[j]);
                }
            }
            for (var m = 0; m < out.length; m++) { cells[idx[m]] = out[m]; }
            return gained;
        };
        var move = function (d) {
            var total = 0;
            for (var r = 0; r < 4; r++) {
                var idx = [];
                for (var c = 0; c < 4; c++) {
                    if (d === 'left') { idx.push(r * 4 + c); }
                    else if (d === 'right') { idx.push(3 - c + r * 4); }
                    else if (d === 'up') { idx.push(c * 4 + r); }
                    else { idx.push((3 - c) * 4 + r); }
                }
                total += slide(idx);
            }
            return total;
        };
        var canMove = function () {
            for (var i = 0; i < 16; i++) { if (cells[i] === 0) { return true; } }
            for (var r = 0; r < 4; r++) {
                for (var c = 0; c < 4; c++) {
                    var v = cells[r * 4 + c];
                    if (c < 3 && cells[r * 4 + c + 1] === v) { return true; }
                    if (r < 3 && cells[(r + 1) * 4 + c] === v) { return true; }
                }
            }
            return false;
        };
        var tileColor = function (v) {
            var map = { 0: 'bg2', 2: 'dim', 4: 'fg', 8: 'accent', 16: 'green', 32: 'cyan', 64: 'blue', 128: 'purple', 256: 'orange', 512: 'yellow', 1024: 'red' };
            return map[v] || 'white';
        };

        addTile(); addTile();
        var ox = 22, oy = 8;

        try {
            var running = true;
            while (running) {
                var moved = false;
                if (!A.headless) {
                    A.clearFrame();
                    A.gameHeader('2048', score, 'q menu');
                    A.setTextCentered(5, 'merge tiles to make 2048', 'dim');
                    A.drawBox(ox - 2, oy - 2, 36, 19, null, 'wall');
                    for (var r = 0; r < 4; r++) {
                        for (var c = 0; c < 4; c++) {
                            var v = cells[r * 4 + c];
                            var x = ox + c * 8, y = oy + r * 4;
                            var col = tileColor(v);
                            for (var yy = y; yy < y + 3; yy++) {
                                for (var xx = x; xx < x + 7; xx++) { A.setCell(xx, yy, ' ', col, col); }
                            }
                            var t = '';
                            if (v > 0) { t = String(v); if (t.length > 4) { t = '2k+'; } }
                            A.setText(x + Math.floor((7 - t.length) / 2), y + 1, t, (v >= 8) ? 'ink' : 'bg', col);
                        }
                    }
                    A.setTextCentered(28, 'arrows to slide - q menu', 'dim');
                    A.showFrame();
                }

                var k = await A.waitRealKey();
                if (k === 'Q' || k === 'Escape') { return; }
                if (k === 'LeftArrow' || k === 'A') { score += move('left'); moved = true; }
                else if (k === 'RightArrow' || k === 'D') { score += move('right'); moved = true; }
                else if (k === 'UpArrow' || k === 'W') { score += move('up'); moved = true; }
                else if (k === 'DownArrow' || k === 'S') { score += move('down'); moved = true; }
                if (A.headless) { moved = (A.testFrames % 2 === 0); }

                if (moved) {
                    if (!A.headless) { A.beep(300, 20); }
                    addTile();
                    for (var v2 = 0; v2 < 16; v2++) { if (cells[v2] >= 2048) { won = true; } }
                    if (!canMove()) { running = false; }
                    if (won) { running = false; }
                }
                await A.waitFrame(20);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        var note = '';
        if (won) { note = 'you made 2048!'; }
        else if (!canMove()) { note = 'no moves left'; }
        if (!(await A.completeGame('2048', '2048', score, note))) { break; }
    }
};

var startInvaders = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 60, bh = 19, bx = 10, by = 6;
        var shipX = Math.floor(bw / 2);
        var bullets = [];
        var bombs = [];
        var aliens = [];
        var wave = 1, score = 0, lives = 3;
        var dirR = true;
        var cooldown = 0;

        var newWave = function () {
            aliens.length = 0;
            for (var r = 0; r < 3; r++) {
                for (var c = 0; c < 8; c++) {
                    aliens.push({ x: 6 + c * 6, y: 1 + r * 3, alive: true, kind: r });
                }
            }
        };
        newWave();
        var frame = 0;
        var stepEvery = 12;

        try {
            var running = true;
            while (running) {
                frame++;
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                if (keys.indexOf('LeftArrow') >= 0 || keys.indexOf('A') >= 0) { shipX -= 2; }
                if (keys.indexOf('RightArrow') >= 0 || keys.indexOf('D') >= 0) { shipX += 2; }
                if (shipX < 1) { shipX = 1; }
                if (shipX > bw - 2) { shipX = bw - 2; }
                if (keys.indexOf('Space') >= 0 && cooldown <= 0) {
                    bullets.push({ x: shipX, y: bh - 2 });
                    cooldown = 3;
                    A.beep(880, 25);
                }
                if (cooldown > 0) { cooldown--; }

                var newB = [];
                for (var bi = 0; bi < bullets.length; bi++) {
                    var b = bullets[bi];
                    b.y -= 2;
                    if (b.y >= 0) { newB.push(b); }
                }
                bullets = newB;

                if ((frame % stepEvery) === 0) {
                    var aliveCount = 0, minX = 999, maxX = -1, maxY = -1;
                    for (var ai = 0; ai < aliens.length; ai++) {
                        var a0 = aliens[ai];
                        if (a0.alive) {
                            aliveCount++;
                            if (a0.x < minX) { minX = a0.x; }
                            if (a0.x > maxX) { maxX = a0.x; }
                            if (a0.y > maxY) { maxY = a0.y; }
                        }
                    }
                    if (aliveCount === 0) {
                        wave++;
                        score += 100;
                        stepEvery = Math.max(5, 12 - wave);
                        newWave();
                        A.beep(520, 60); A.beep(780, 80);
                    } else {
                        var edge = false;
                        if (dirR && (maxX + 2) >= (bw - 1)) { edge = true; }
                        if (!dirR && (minX - 1) <= 0) { edge = true; }
                        if (edge) {
                            dirR = !dirR;
                            for (var a1 = 0; a1 < aliens.length; a1++) { if (aliens[a1].alive) { aliens[a1].y++; } }
                            if (maxY >= (bh - 3)) { lives--; if (lives <= 0) { running = false; } }
                        } else {
                            for (var a2 = 0; a2 < aliens.length; a2++) {
                                if (aliens[a2].alive) { if (dirR) { aliens[a2].x++; } else { aliens[a2].x--; } }
                            }
                        }
                        if (Math.floor(Math.random() * 100) < 30) {
                            var shooters = aliens.filter(function (a) { return a.alive; });
                            if (shooters.length > 0) {
                                var sh = shooters[Math.floor(Math.random() * shooters.length)];
                                bombs.push({ x: sh.x, y: sh.y });
                            }
                        }
                    }
                }

                var newBo = [];
                for (var bi2 = 0; bi2 < bombs.length; bi2++) {
                    var bo = bombs[bi2];
                    bo.y += 1;
                    if (bo.y < bh) {
                        if ((frame % 2) === 0 && Math.abs(bo.x - shipX) <= 1 && bo.y >= (bh - 2)) {
                            lives--;
                            A.beep(110, 120);
                            if (lives <= 0) { running = false; newBo.push(bo); } else { shipX = Math.floor(bw / 2); }
                        } else { newBo.push(bo); }
                    }
                }
                bombs = newBo;

                for (var bi3 = 0; bi3 < bullets.length; bi3++) {
                    var b2 = bullets[bi3];
                    for (var a3 = 0; a3 < aliens.length; a3++) {
                        var al = aliens[a3];
                        if (al.alive && Math.abs(al.x - b2.x) <= 1 && Math.abs(al.y - b2.y) <= 1) {
                            al.alive = false;
                            b2.y = -99;
                            score += (3 - al.kind) * 10;
                            A.beep(220, 30);
                        }
                    }
                }
                bullets = bullets.filter(function (b) { return b.y >= 0; });

                A.clearFrame();
                A.gameHeader('Space Invaders', score, 'wave ' + wave + '  ' + A.ch.Heart + lives);
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                for (var a4 = 0; a4 < aliens.length; a4++) {
                    var al2 = aliens[a4];
                    if (al2.alive) {
                        var col = ['purple', 'cyan', 'green'][al2.kind];
                        A.setCell(bx + al2.x, by + al2.y, A.ch.Med, col);
                        A.setCell(bx + al2.x + 1, by + al2.y, A.ch.Med, col);
                    }
                }
                for (var bi4 = 0; bi4 < bullets.length; bi4++) { A.setCell(bx + bullets[bi4].x, by + bullets[bi4].y, '|', 'yellow'); }
                for (var bi5 = 0; bi5 < bombs.length; bi5++) { A.setCell(bx + bombs[bi5].x, by + bombs[bi5].y, '!', 'red'); }
                A.setText(bx + shipX - 1, by + bh - 1, '/' + A.ch.Full + '\\', 'white');
                A.setTextCentered(by + bh + 2, 'arrows move - SPACE shoots - q menu', 'dim');
                A.showFrame();
                await A.waitFrame(50);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('invaders', 'Space Invaders', score))) { break; }
    }
};


// ---- 11-games-b.js ----
// ============================================================
//  GAMES B - flappy, breakout, frogger, dodge
// ============================================================

var startFlappy = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 60, bh = 20, bx = 10, by = 6;
        var birdY = Math.floor(bh / 2);
        var vel = 0.0;
        var pipes = [];
        var score = 0, frame = 0;
        var gravity = 0.35, flapV = -1.6, speed = 0.7, gap = 7;
        var started = false;

        var randGap = function () { return 3 + Math.floor(Math.random() * (bh - gap - 4 - 3)); };
        for (var i = 0; i < 3; i++) { pipes.push({ x: bw + 10 + i * 24, gap: randGap(), scored: false }); }

        var drawPipes = function () {
            for (var p = 0; p < pipes.length; p++) {
                var px = Math.floor(pipes[p].x);
                for (var y = 0; y < bh; y++) {
                    if (y < pipes[p].gap || y > pipes[p].gap + gap) {
                        A.setCell(bx + px, by + y, A.ch.Full, 'green');
                        if (px + 1 < bw) { A.setCell(bx + px + 1, by + y, A.ch.Full, 'green'); }
                    }
                }
            }
        };

        try {
            var running = true;
            while (running) {
                frame++;
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }

                if (!started) {
                    if (keys.indexOf('Space') >= 0 || keys.indexOf('UpArrow') >= 0 || keys.indexOf('W') >= 0) {
                        started = true;
                        vel = flapV;
                        A.beep(500, 20);
                    }
                    A.clearFrame();
                    A.gameHeader('Flappy', score, '');
                    A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                    drawPipes();
                    A.setCell(bx + 4, by + Math.floor(birdY), A.ch.Star, 'yellow');
                    A.setTextCentered(by + bh + 2, 'press SPACE to flap - the bird falls, so keep tapping!', 'dim');
                    A.showFrame();
                    await A.waitFrame(50);
                    continue;
                }

                if (keys.indexOf('Space') >= 0 || keys.indexOf('UpArrow') >= 0 || keys.indexOf('W') >= 0) {
                    vel = flapV;
                    A.beep(500, 20);
                }

                vel += gravity;
                birdY += vel;

                for (var pi = 0; pi < pipes.length; pi++) { pipes[pi].x -= speed; }
                if (pipes[0].x < -3) {
                    pipes.shift();
                    pipes.push({ x: pipes[pipes.length - 1].x + 24, gap: randGap(), scored: false });
                }

                for (var pj = 0; pj < pipes.length; pj++) {
                    if (!pipes[pj].scored && pipes[pj].x < 4) {
                        pipes[pj].scored = true;
                        score++;
                        A.beep(700, 30);
                    }
                }

                if (birdY >= (bh - 1) || birdY < 0) { running = false; A.beep(120, 150); }
                for (var pk = 0; pk < pipes.length && running; pk++) {
                    if (pipes[pk].x < 5 && pipes[pk].x > 2) {
                        if (birdY < pipes[pk].gap || birdY > (pipes[pk].gap + gap)) {
                            running = false;
                            A.beep(120, 150);
                        }
                    }
                }

                A.clearFrame();
                A.gameHeader('Flappy', score, '');
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                drawPipes();
                A.setCell(bx + 4, by + Math.floor(birdY), A.ch.Star, 'yellow');
                A.showFrame();
                await A.waitFrame(50);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('flappy', 'Flappy', score))) { break; }
    }
};

var startBreakout = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 50, bh = 20, bx = 15, by = 6;
        var paddleW = 9;
        var padX = Math.floor((bw - paddleW) / 2);
        var ballX = bw / 2, ballY = bh - 4;
        var vx = 0.5, vy = -0.6;
        var level = 1, score = 0, lives = 3;
        var bricks = {};

        var newWall = function (rows, cols) {
            var w = {};
            for (var r = 0; r < rows; r++) {
                for (var c = 0; c < cols; c++) {
                    if (Math.floor(Math.random() * 10) < 9) { w[r + ',' + c] = 3 - Math.min(2, r); }
                }
            }
            return w;
        };
        bricks = newWall(4, 12);

        try {
            var running = true;
            while (running) {
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                if (keys.indexOf('LeftArrow') >= 0 || keys.indexOf('A') >= 0) { padX -= 3; }
                if (keys.indexOf('RightArrow') >= 0 || keys.indexOf('D') >= 0) { padX += 3; }
                if (padX < 1) { padX = 1; }
                if (padX > (bw - paddleW - 1)) { padX = bw - paddleW - 1; }

                ballX += vx; ballY += vy;

                if (ballX < 0.5) { ballX = 0.5; vx = -vx; A.beep(240, 15); }
                if (ballX > (bw - 0.5)) { ballX = bw - 0.5; vx = -vx; A.beep(240, 15); }
                if (ballY < 0.5) { ballY = 0.5; vy = -vy; A.beep(240, 15); }

                var ibx = Math.round(ballX), iby = Math.round(ballY);
                if (vy > 0 && iby >= (bh - 2) && iby <= (bh - 1) && ibx >= padX && ibx < (padX + paddleW)) {
                    vy = -Math.abs(vy);
                    var hit = (ibx - padX) / paddleW;
                    vx = (hit - 0.5) * 1.6;
                    A.beep(330, 20);
                }

                var cw = 4;
                if (iby >= 0 && iby < 12) {
                    var bc = Math.floor(ballX / cw);
                    var br = Math.floor(ballY / 3);
                    var key = br + ',' + bc;
                    if (bricks[key] !== undefined) {
                        bricks[key]--;
                        if (bricks[key] <= 0) { delete bricks[key]; score += 10 * level; }
                        else { score += 3; }
                        if (bc === 0 || bc === 11) { vx = -vx; } else { vy = -vy; }
                        A.beep(440, 20);
                    }
                }

                if (ballY >= bh) {
                    lives--;
                    A.beep(100, 150);
                    if (lives <= 0) { running = false; }
                    else { ballX = bw / 2; ballY = bh - 4; vx = 0.5; vy = -0.6; }
                }

                if (Object.keys(bricks).length === 0) {
                    level++;
                    score += 150;
                    bricks = newWall(4 + Math.min(4, level), 12);
                    ballX = bw / 2; ballY = bh - 4;
                    vx = 0.5 * (1 + 0.1 * level); vy = -0.65;
                    A.beep(520, 60); A.beep(780, 80);
                }

                A.clearFrame();
                A.gameHeader('Breakout', score, 'lvl ' + level + '  ' + A.ch.Heart + lives);
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                for (var bkey in bricks) {
                    var pp = bkey.split(',');
                    var rr = parseInt(pp[0], 10), cc = parseInt(pp[1], 10);
                    var col = ['red', 'orange', 'yellow'][rr % 3];
                    var cx = bx + cc * cw + 1, cy = by + rr * 3;
                    for (var seg = 0; seg < 3; seg++) { A.setCell(cx + seg, cy, A.ch.Med, col); }
                }
                var padStr = '';
                for (var pw = 0; pw < paddleW; pw++) { padStr += A.ch.Full; }
                A.setText(bx + padX, by + bh - 1, padStr, 'cyan');
                A.setCell(bx + ibx, by + iby, A.ch.Diam, 'white');
                A.setTextCentered(by + bh + 2, 'arrows move the paddle - ball angle depends on hit spot - q menu', 'dim');
                A.showFrame();
                await A.waitFrame(40);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('breakout', 'Breakout', score))) { break; }
    }
};

var startFrogger = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 50, bh = 18, bx = 15, by = 7;
        var goalRow = 0;
        var riverRows = [1, 2, 3, 4];
        var roadRows = [6, 7, 8, 9];
        var medianRow = 5;
        var lives = 3, score = 0, level = 1;
        var frogX = 0, frogY = 0;

        var newLane = function (y, dir, spd, len, count, isLog) {
            var items = [];
            var spacing = Math.floor((bw + 8) / count);
            for (var i = 0; i < count; i++) {
                items.push({ x: -8 + i * spacing + Math.floor(Math.random() * 4), len: len });
            }
            return { y: y, dir: dir, speed: spd, items: items, log: !!isLog };
        };
        var buildLanes = function (lvl) {
            var lanes = [];
            var sp = 0.25 + 0.08 * Math.min(6, lvl);
            lanes.push(newLane(4, -1, sp + 0.05, 5, 3, true));
            lanes.push(newLane(3, 1, sp + 0.15, 4, 3, true));
            lanes.push(newLane(2, -1, sp + 0.25, 6, 2, true));
            lanes.push(newLane(1, 1, sp + 0.35, 4, 3, true));
            lanes.push(newLane(9, 1, sp + 0.10, 3, 3, false));
            lanes.push(newLane(8, -1, sp + 0.20, 2, 4, false));
            lanes.push(newLane(7, 1, sp + 0.30, 3, 3, false));
            lanes.push(newLane(6, -1, sp + 0.40, 2, 4, false));
            return lanes;
        };
        var resetFrog = function () {
            frogX = Math.floor(bw / 2);
            frogY = bh - 1;
        };
        var lanes = buildLanes(level);
        resetFrog();

        try {
            var running = true;
            while (running) {
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                for (var ki = 0; ki < keys.length; ki++) {
                    var k = keys[ki];
                    if ((k === 'UpArrow' || k === 'W') && frogY > 0) { frogY--; A.beep(400, 15); }
                    else if ((k === 'DownArrow' || k === 'S') && frogY < (bh - 1)) { frogY++; A.beep(300, 15); }
                    else if ((k === 'LeftArrow' || k === 'A') && frogX > 0) { frogX--; }
                    else if ((k === 'RightArrow' || k === 'D') && frogX < (bw - 1)) { frogX++; }
                }

                for (var li = 0; li < lanes.length; li++) {
                    var lane = lanes[li];
                    for (var ii = 0; ii < lane.items.length; ii++) {
                        var it = lane.items[ii];
                        it.x += lane.speed * lane.dir;
                        if (it.x > (bw + 8)) { it.x = -it.len - 6; }
                        if ((it.x + it.len) < -8) { it.x = bw + 6; }
                    }
                }

                var fx = frogX, fy = frogY;
                var dead = false;

                if (roadRows.indexOf(fy) >= 0) {
                    var rlane = null;
                    for (var rl = 0; rl < lanes.length; rl++) { if (lanes[rl].y === fy) { rlane = lanes[rl]; break; } }
                    for (var ri = 0; ri < rlane.items.length; ri++) {
                        var rit = rlane.items[ri];
                        var rsx = Math.ceil(rit.x);
                        if (fx >= rsx && fx < (rsx + rit.len)) { dead = true; }
                    }
                } else if (riverRows.indexOf(fy) >= 0) {
                    var onLog = false;
                    var vlane = null;
                    for (var vl = 0; vl < lanes.length; vl++) { if (lanes[vl].y === fy) { vlane = lanes[vl]; break; } }
                    for (var vi = 0; vi < vlane.items.length; vi++) {
                        var vit = vlane.items[vi];
                        var vsx = Math.ceil(vit.x);
                        if (fx >= vsx && fx < (vsx + vit.len)) {
                            onLog = true;
                            frogX = frogX + (vlane.speed * vlane.dir);
                        }
                    }
                    if (!onLog) { dead = true; }
                    if (frogX < 0 || frogX >= bw) { dead = true; }
                } else if (fy === goalRow) {
                    score += 200;
                    level++;
                    lanes = buildLanes(level);
                    resetFrog();
                    A.beep(520, 50); A.beep(780, 70);
                    continue;
                }

                if (dead) {
                    lives--;
                    A.beep(110, 140);
                    if (lives <= 0) { running = false; } else { resetFrog(); }
                }

                A.clearFrame();
                A.gameHeader('Frogger', score, 'lvl ' + level + '  ' + A.ch.Heart + lives);
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                for (var gx = 0; gx < bw; gx++) { A.setCell(bx + gx, by + 0, A.ch.Dot, 'yellow'); }
                for (var mx = 0; mx < bw; mx++) { A.setCell(bx + mx, by + medianRow, ' ', 'fg', 'bg2'); }
                for (var lj = 0; lj < lanes.length; lj++) {
                    var ln = lanes[lj];
                    for (var ij = 0; ij < ln.items.length; ij++) {
                        var item = ln.items[ij];
                        var sx = Math.ceil(item.x);
                        for (var seg = 0; seg < item.len; seg++) {
                            var px = sx + seg;
                            if (px >= 0 && px < bw) {
                                if (ln.log) { A.setCell(bx + px, by + ln.y, A.ch.BH, 'orange'); }
                                else { A.setCell(bx + px, by + ln.y, A.ch.Med, 'red'); }
                            }
                        }
                    }
                }
                A.setCell(bx + Math.round(frogX), by + frogY, A.ch.Diam, 'green');
                A.setTextCentered(by + bh + 2, 'arrows hop - ride logs, dodge cars - q menu', 'dim');
                A.showFrame();
                await A.waitFrame(50);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('frogger', 'Frogger', score))) { break; }
    }
};

var startDodge = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bw = 60, bh = 20, bx = 10, by = 6;
        var px = Math.floor(bw / 2), py = Math.floor(bh / 2);
        var enemies = [];
        var score = 0, frame = 0;
        var spawnEvery = 35;
        var dashCd = 0, invul = 0;

        try {
            var running = true;
            while (running) {
                frame++;
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }

                var dx = 0, dy = 0;
                for (var ki = 0; ki < keys.length; ki++) {
                    var k = keys[ki];
                    if (k === 'UpArrow' || k === 'W') { dy = -1; }
                    else if (k === 'DownArrow' || k === 'S') { dy = 1; }
                    else if (k === 'LeftArrow' || k === 'A') { dx = -1; }
                    else if (k === 'RightArrow' || k === 'D') { dx = 1; }
                }
                var step = 1;
                if (keys.indexOf('Space') >= 0 && dashCd <= 0) {
                    step = 4;
                    dashCd = 25;
                    invul = 10;
                    A.beep(700, 30);
                }
                if (dashCd > 0) { dashCd--; }
                if (invul > 0) { invul--; }
                for (var s = 0; s < step; s++) {
                    var nx = px + dx, ny = py + dy;
                    if (nx >= 0 && nx < bw) { px = nx; }
                    if (ny >= 0 && ny < bh) { py = ny; }
                }

                if ((frame % spawnEvery) === 0) {
                    var side = Math.floor(Math.random() * 4);
                    if (side === 0) { enemies.push({ x: Math.floor(Math.random() * bw), y: 0 }); }
                    else if (side === 1) { enemies.push({ x: Math.floor(Math.random() * bw), y: bh - 1 }); }
                    else if (side === 2) { enemies.push({ x: 0, y: Math.floor(Math.random() * bh) }); }
                    else { enemies.push({ x: bw - 1, y: Math.floor(Math.random() * bh) }); }
                    if (spawnEvery > 12) { spawnEvery--; }
                }

                if ((frame % 2) === 0) {
                    for (var ei = 0; ei < enemies.length; ei++) {
                        var e = enemies[ei];
                        if (e.x < px) { e.x++; } else if (e.x > px) { e.x--; }
                        if (e.y < py) { e.y++; } else if (e.y > py) { e.y--; }
                    }
                }

                if (invul <= 0) {
                    for (var ej = 0; ej < enemies.length; ej++) {
                        if (enemies[ej].x === px && enemies[ej].y === py) {
                            running = false;
                            A.beep(100, 200);
                            break;
                        }
                    }
                }

                score = Math.floor(frame / 10) * 5;

                A.clearFrame();
                A.gameHeader('Dodge', score, 'dash ' + ((dashCd <= 0) ? 'ready' : String(dashCd)));
                A.drawBox(bx - 1, by - 1, bw + 2, bh + 2, null, 'wall');
                for (var ek = 0; ek < enemies.length; ek++) {
                    A.setCell(bx + enemies[ek].x, by + enemies[ek].y, A.ch.Med, 'red');
                }
                var pcol = (invul > 0) ? 'cyan' : 'green';
                A.setCell(bx + px, by + py, A.ch.Diam, pcol);
                A.setTextCentered(by + bh + 2, 'arrows move - SPACE = quick dash (short cooldown) - q menu', 'dim');
                A.showFrame();
                await A.waitFrame(50);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('dodge', 'Dodge', score))) { break; }
    }
};


// ---- 12-games-c.js ----
// ============================================================
//  GAMES C - ttt, hangman, pong
// ============================================================

var tttWinner = function (b) {
    var lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (b[l[0]] !== ' ' && b[l[0]] === b[l[1]] && b[l[1]] === b[l[2]]) { return b[l[0]]; }
    }
    var open = 0;
    for (var j = 0; j < 9; j++) { if (b[j] === ' ') { open++; } }
    if (open === 0) { return 'D'; }
    return ' ';
};

var tttCpuMove = function (b) {
    var empties = [];
    for (var i = 0; i < 9; i++) { if (b[i] === ' ') { empties.push(i); } }
    var tries = ['O', 'X'];
    for (var t = 0; t < tries.length; t++) {
        for (var e = 0; e < empties.length; e++) {
            var tb = b.slice();
            tb[empties[e]] = tries[t];
            if (tttWinner(tb) === tries[t]) { return empties[e]; }
        }
    }
    if (b[4] === ' ') { return 4; }
    var corners = [0, 2, 6, 8].filter(function (c) { return b[c] === ' '; });
    if (corners.length > 0) { return corners[Math.floor(Math.random() * corners.length)]; }
    return empties[Math.floor(Math.random() * empties.length)];
};

var startTtt = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var score = 0, round = 1;

        var drawBoard = function (b, cur, msg, msgCol) {
            A.clearFrame();
            A.gameHeader('Tic-Tac-Toe', score, 'round ' + round);
            var ox = 28, oy = 9;
            for (var r = 0; r < 3; r++) {
                for (var c = 0; c < 3; c++) {
                    var x = ox + c * 9, y = oy + r * 4;
                    var col = 'bg2', fg = 'fg';
                    if (r * 3 + c === cur) { col = 'accent'; fg = 'ink'; }
                    for (var yy = y; yy < y + 3; yy++) {
                        for (var xx = x; xx < x + 8; xx++) { A.setCell(xx, yy, ' ', fg, col); }
                    }
                    var v = b[r * 3 + c];
                    if (v !== ' ') { A.setText(x + 3, y + 1, v, (v === 'X') ? 'green' : 'red', col); }
                    else { A.setText(x + 3, y + 1, String(r * 3 + c + 1), 'dim', col); }
                }
            }
            A.setTextCentered(22, msg, msgCol);
            A.setTextCentered(24, 'arrows + enter, or 1-9 - q menu', 'dim');
            A.showFrame();
        };

        try {
            var sessionOver = false;
            while (!sessionOver) {
                var b = [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '];
                var cur = 4;
                var msg = 'your move (X)', msgCol = 'dim';
                var result = ' ';
                while (true) {
                    await A.waitFrame(16);
                    drawBoard(b, cur, msg, msgCol);
                    var k = await A.waitRealKey();
                    if (A.headless) { k = String(1 + (A.testFrames % 9)); }
                    if (k === 'Q' || k === 'Escape') { return; }
                    var moved = false;
                    if (k === 'UpArrow') { if (cur >= 3) { cur -= 3; moved = true; } }
                    else if (k === 'DownArrow') { if (cur <= 5) { cur += 3; moved = true; } }
                    else if (k === 'LeftArrow') { if (cur % 3 > 0) { cur--; moved = true; } }
                    else if (k === 'RightArrow') { if (cur % 3 < 2) { cur++; moved = true; } }
                    else if (k === 'Enter' || k === 'Space') {
                        if (b[cur] === ' ') {
                            b[cur] = 'X';
                            A.beep(440, 25);
                            var w = tttWinner(b);
                            if (w !== ' ') { result = w; }
                            else {
                                b[tttCpuMove(b)] = 'O';
                                A.beep(330, 25);
                                w = tttWinner(b);
                                if (w !== ' ') { result = w; }
                                else { msg = 'your move (X)'; }
                            }
                        } else { msg = 'occupied - pick another'; msgCol = 'yellow'; }
                    } else if (/^[1-9]$/.test(k)) {
                        var idx = parseInt(k, 10) - 1;
                        if (b[idx] === ' ') {
                            cur = idx;
                            b[idx] = 'X';
                            A.beep(440, 25);
                            var w2 = tttWinner(b);
                            if (w2 !== ' ') { result = w2; }
                            else {
                                b[tttCpuMove(b)] = 'O';
                                A.beep(330, 25);
                                w2 = tttWinner(b);
                                if (w2 !== ' ') { result = w2; }
                                else { msg = 'your move (X)'; }
                            }
                        } else { msg = 'occupied - pick another'; msgCol = 'yellow'; }
                    }
                    if (result !== ' ') { break; }
                }

                if (result === 'X') {
                    score += 100;
                    round++;
                    if (A.headless) { sessionOver = true; }
                    drawBoard(b, cur, 'you win! next round...', 'green');
                    A.beep(660, 60); A.beep(880, 80);
                    await A.arcadeSleep(900);
                } else if (result === 'D') {
                    score += 30;
                    if (A.headless) { sessionOver = true; }
                    drawBoard(b, cur, 'draw! replaying...', 'yellow');
                    await A.arcadeSleep(900);
                } else {
                    drawBoard(b, cur, 'CPU wins - run over', 'red');
                    A.beep(200, 120); A.beep(150, 160);
                    await A.arcadeSleep(1100);
                    sessionOver = true;
                }
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('ttt', 'Tic-Tac-Toe', score))) { break; }
    }
};

var HangWords = [
    'arcade', 'pixel', 'joystick', 'console', 'keyboard', 'monitor', 'controller', 'cartridge',
    'neon', 'wizard', 'dragon', 'castle', 'puzzle', 'rocket', 'galaxy', 'planet', 'meteor', 'orbit',
    'cobra', 'panda', 'falcon', 'shark', 'tiger', 'zebra', 'wolf', 'eagle', 'dolphin', 'penguin',
    'pizza', 'burger', 'noodle', 'coffee', 'donut', 'waffle', 'mango', 'banana', 'carrot', 'pepper',
    'guitar', 'drums', 'piano', 'violin', 'trumpet', 'banjo', 'harmonica', 'accordion',
    'mountain', 'river', 'forest', 'desert', 'island', 'volcano', 'glacier', 'canyon', 'meadow',
    'robot', 'circuit', 'laser', 'server', 'python', 'script', 'memory', 'cache', 'kernel'
];

var startHangman = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var score = 0, solved = 0;

        var drawHang = function (word, guessed, wrong, msg, msgCol, solvedN, scoreN) {
            A.clearFrame();
            A.gameHeader('Hangman', scoreN, 'solved ' + solvedN);
            A.setText(12, 8, '/' + A.ch.BH + A.ch.BH + A.ch.BH + A.ch.BH + '\\', 'wall');
            A.setText(17, 9, '|', 'wall');
            A.setText(17, 10, '|', 'wall');
            A.setText(17, 11, '|', 'wall');
            A.setText(17, 16, '|', 'wall');
            A.setText(11, 16, A.ch.BH, 'wall');
            var stages = ['O', 'O\u2502', 'O/\u2502', 'O/\u2502\\', 'O/\u2502\\', 'O/\u2502\\ /'];
            if (wrong > 0) {
                var parts = stages[wrong - 1].split('');
                A.setText(16, 10, parts[0], 'red');
                if (parts.length > 1) { A.setText(17, 11, parts[1], 'red'); }
                if (parts.length > 2) { A.setText(16, 12, parts[2], 'red'); }
                if (parts.length > 3) { A.setText(18, 12, parts[3], 'red'); }
                if (parts.length > 4) { A.setText(16, 13, parts[4], 'red'); }
                if (parts.length > 5) { A.setText(18, 13, parts[5], 'red'); }
            }
            var wx = 28;
            var reveal = '';
            for (var i = 0; i < word.length; i++) {
                reveal += (guessed.indexOf(word.charAt(i)) >= 0) ? (word.charAt(i) + ' ') : '_ ';
            }
            A.setText(wx, 10, reveal, 'white');
            A.setText(wx, 12, 'length ' + word.length, 'dim');
            var g = guessed.slice().sort().join(' ');
            if (g.length > 40) { g = g.substring(0, 40); }
            A.setText(wx, 14, 'used: ' + g, 'dim');
            A.setText(wx, 16, 'wrong: ' + wrong + '/6', 'red');
            A.setText(wx, 19, msg, msgCol);
            A.setText(wx, 21, 'press a letter - q menu', 'dim');
            A.showFrame();
        };

        try {
            var runOver = false;
            while (!runOver) {
                var word = HangWords[Math.floor(Math.random() * HangWords.length)].toUpperCase();
                var guessed = [];
                var wrong = 0;
                var msg = 'guess a letter', msgCol = 'dim';
                var state = 'play';
                while (state === 'play') {
                    await A.waitFrame(16);
                    drawHang(word, guessed, wrong, msg, msgCol, solved, score);
                    var kc = await A.waitRealKeyChar();
                    var k = kc.key;
                    if (A.headless) { k = String.fromCharCode(65 + (A.testFrames % 26)); }
                    if (k === 'Q' || k === 'Escape') { return; }
                    var ch = kc.char ? kc.char.toUpperCase() : k;
                    if (ch.length === 1 && /^[A-Z]$/.test(ch)) {
                        if (guessed.indexOf(ch) >= 0) {
                            msg = 'already tried ' + ch; msgCol = 'yellow';
                        } else {
                            guessed.push(ch);
                            if (word.indexOf(ch) >= 0) {
                                msg = ch + ' is in the word!'; msgCol = 'green';
                                A.beep(520, 30);
                            } else {
                                wrong++;
                                msg = 'no ' + ch + ' in the word'; msgCol = 'red';
                                A.beep(200, 40);
                            }
                            var done = true;
                            for (var wi = 0; wi < word.length; wi++) {
                                if (guessed.indexOf(word.charAt(wi)) < 0) { done = false; }
                            }
                            if (done) { state = 'won'; }
                            else if (wrong >= 6) { state = 'lost'; }
                        }
                    }
                }
                if (state === 'won') {
                    score += 50 + (6 - wrong) * 20;
                    solved++;
                    drawHang(word, guessed, wrong, 'the word was ' + word + ' - next one!', 'green', solved, score);
                    A.beep(660, 60); A.beep(880, 80);
                    await A.arcadeSleep(1200);
                } else {
                    drawHang(word, guessed, wrong, 'it was ' + word + ' - run over', 'red', solved, score);
                    A.beep(150, 200);
                    await A.arcadeSleep(1400);
                    runOver = true;
                }
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('hangman', 'Hangman', score))) { break; }
    }
};

var startPong = async function () {
    while (true) {
        A.startFrames();
        A.startScreen(30);
        var bx0 = 14, by0 = 4, bw = 52, bh = 20;
        var pX = 17, cX = 62;
        var p = 11, c = 11;
        var pPts = 0, cPts = 0, hits = 0;
        var bx = 40.0, by = 13.0;
        var dx = (Math.floor(Math.random() * 2) === 0) ? 1 : -1;
        var dy = 0.75 * ((Math.floor(Math.random() * 2) === 0) ? 1 : -1);
        var speed = 1;
        var moveEvery = 2;
        var mvCount = 0;
        var trail = [];

        try {
            var running = true;
            while (running) {
                var keys = A.keysPressed();
                A.muteToggleRequested(keys);
                if (keys.indexOf('Q') >= 0) { return; }
                if (A.headless) { keys = [String(1 + (A.testFrames % 9))]; }
                for (var ki = 0; ki < keys.length; ki++) {
                    var k = keys[ki];
                    if (k === 'UpArrow' || k === 'W' || k === '1' || k === '2' || k === '3') { p--; }
                    else if (k === 'DownArrow' || k === 'S' || k === '7' || k === '8' || k === '9') { p++; }
                }
                if (p < 5) { p = 5; }
                if (p > 19) { p = 19; }

                var target = 12;
                if (dx > 0) { target = Math.floor(by) + Math.floor(Math.random() * 3) - 1; }
                if (c < (target - 1)) { c++; }
                else if (c > (target + 1)) { c--; }
                if (c < 5) { c = 5; }
                if (c > 19) { c = 19; }

                mvCount++;
                if (mvCount >= moveEvery) {
                    mvCount = 0;
                    var pointScored = false;
                    var serve = 1;
                    for (var step = 0; step < speed && !pointScored; step++) {
                        trail.push({ x: bx, y: by });
                        while (trail.length > 3) { trail.shift(); }
                        bx += dx;
                        by += dy;
                        var row = Math.floor(by);
                        if (row <= 5) { by = 5.01; dy = Math.abs(dy); }
                        if (row >= 22) { by = 21.99; dy = -Math.abs(dy); }
                        row = Math.floor(by);
                        if (dx < 0 && bx <= pX) {
                            if (row >= p && row <= (p + 3)) {
                                var off = row - p;
                                dy = 0.66 * (off - 1.5);
                                if (Math.abs(dy) < 0.25) { dy = 0.4; if (Math.floor(Math.random() * 2) === 0) { dy = -0.4; } }
                                bx = pX + 1;
                                dx = speed;
                                hits++;
                                A.beep(520, 18);
                                if (hits >= 8) { speed = 2; }
                            }
                        } else if (dx > 0 && bx >= cX) {
                            if (row >= c && row <= (c + 3)) {
                                var off2 = row - c;
                                dy = 0.66 * (off2 - 1.5);
                                if (Math.abs(dy) < 0.25) { dy = 0.4; if (Math.floor(Math.random() * 2) === 0) { dy = -0.4; } }
                                bx = cX - 1;
                                dx = -speed;
                                hits++;
                                A.beep(440, 18);
                                if (hits >= 8) { speed = 2; }
                            }
                        }
                        if (bx < 16) { cPts++; pointScored = true; serve = -1; }
                        else if (bx > 63) { pPts++; pointScored = true; serve = 1; }
                    }
                    if (pointScored) {
                        A.beep(200, 120);
                        if (pPts >= 5 || cPts >= 5) { running = false; }
                        else {
                            bx = 40.0; by = 13.0;
                            dx = serve;
                            dy = (3 + Math.floor(Math.random() * 5)) / 10;
                            if (Math.floor(Math.random() * 2) === 0) { dy = -dy; }
                            speed = 1; hits = 0;
                            trail.length = 0;
                        }
                    }
                }

                A.clearFrame();
                A.gameHeader('Pong', pPts, 'cpu ' + cPts + ' - first to 5');
                A.drawBox(bx0, by0, bw, bh, null, 'wall');
                for (var yy = 5; yy <= 22; yy += 2) { A.setCell(40, yy, A.ch.Dot, 'wall'); }
                for (var t = 0; t < trail.length; t++) {
                    var tx = Math.floor(trail[t].x), ty = Math.floor(trail[t].y);
                    if (tx >= 15 && tx <= 64 && ty >= 5 && ty <= 22) { A.setCell(tx, ty, '.', 'dim'); }
                }
                A.setCell(Math.floor(bx), Math.floor(by), '@', 'yellow');
                for (var pi = 0; pi < 4; pi++) {
                    A.setCell(pX, p + pi, A.ch.Full, 'accent');
                    A.setCell(cX, c + pi, A.ch.Full, 'red');
                }
                A.setTextCentered(25, 'up/down or w/s move - q menu', 'dim');
                A.showFrame();
                await A.waitFrame(45);
            }
        } catch (e) { if (e instanceof A.SelfTestDone) { throw e; } throw e; }

        if (!(await A.completeGame('pong', 'Pong', pPts * 1000 + hits))) { break; }
    }
};


// ---- 30-ui.js ----
// ============================================================
//  UI - game registry, logo, menu, highscores, challenge, help
// ============================================================

A.games = [
    { id: 'snake', name: 'Snake', desc: 'eat, grow, survive', fn: startSnake },
    { id: 'tetris', name: 'Tetris', desc: 'stack and clear lines', fn: startTetris },
    { id: '2048', name: '2048', desc: 'merge tiles to 2048', fn: startG2048 },
    { id: 'invaders', name: 'Space Invaders', desc: 'shoot the alien fleet', fn: startInvaders },
    { id: 'flappy', name: 'Flappy', desc: 'flap through the gaps', fn: startFlappy },
    { id: 'breakout', name: 'Breakout', desc: 'smash every brick', fn: startBreakout },
    { id: 'frogger', name: 'Frogger', desc: 'hop across road and river', fn: startFrogger },
    { id: 'dodge', name: 'Dodge', desc: 'survive the swarm', fn: startDodge },
    { id: 'ttt', name: 'Tic-Tac-Toe', desc: 'beat the CPU', fn: startTtt },
    { id: 'hangman', name: 'Hangman', desc: 'guess the word', fn: startHangman },
    { id: 'pong', name: 'Pong', desc: 'classic paddle duel', fn: startPong }
];

A.showMenuLogo = function (y) {
    var art = [
        '  _____   _____              _____   _____          _____  ______ ',
        ' |  __ \\ / ____|       /\\   |  __ \\ / ____|   /\\   |  __ \\|  ____|',
        ' | |__) | (___ ______ /  \\  | |__) | |       /  \\  | |  | | |__   ',
        ' |  ___/ \\___ \\______/ /\\ \\ |  _  /| |      / /\\ \\ | |  | |  __|  ',
        ' | |     ____) |    / ____ \\| | \\ \\| |____ / ____ \\| |__| | |____ ',
        ' |_|    |_____/    /_/    \\_\\_|  \\_\\\\_____/_/    \\_\\_____/|______|'
    ];
    for (var i = 0; i < art.length; i++) { A.setTextCentered(y + i, art[i], 'accent'); }
};

// ---- challenge codes (MUST stay in sync with the PS version) ----

A.challengeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

A.challengeCode = function (gameId, score) {
    var gi = 0;
    for (var i = 0; i < A.games.length; i++) { if (A.games[i].id === gameId) { gi = i; } }
    var l1 = A.challengeAlphabet[gi];
    var l2 = A.challengeAlphabet[(gi * 7 + 5) % 24];
    var s = Math.min(Math.max(score, 0), 999999);
    var scoreStr = ('000000' + s).slice(-6);
    var chk = (score + gi * 7919) % 10;
    return l1 + '' + l2 + '-' + scoreStr + '-' + chk;
};

A.challengeTarget = function (code) {
    var c = String(code).replace(/[^A-Za-z0-9\-]/g, '').toUpperCase();
    var m = c.match(/^([A-Z])([A-Z])-(\d{6})-(\d)$/);
    if (!m) { return null; }
    var i1 = A.challengeAlphabet.indexOf(m[1]);
    var i2 = A.challengeAlphabet.indexOf(m[2]);
    if (i1 < 0 || i2 < 0) { return null; }
    if (i2 !== (i1 * 7 + 5) % 24) { return null; }
    var gi = i1;
    var score = parseInt(m[3], 10);
    var chk = parseInt(m[4], 10);
    if (((score + gi * 7919) % 10) !== chk) { return null; }
    return { gameIdx: gi, score: score };
};

A.showChallengeScreen = async function () {
    A.clearFrame();
    A.drawBox(12, 6, 56, 17, ' challenge ', 'accent');
    A.setTextCentered(8, 'beat this run:', 'dim');
    var half = Math.ceil(A.games.length / 2);
    for (var i = 0; i < A.games.length; i++) {
        var col = 0, row = i;
        if (i >= half) { col = 1; row = i - half; }
        var yy = 10 + row, xx = 17 + col * 26;
        A.setText(xx, yy, A.games[i].id.padEnd(8), 'accent');
        A.setText(xx + 9, yy, A.games[i].name, 'fg');
    }
    A.setText(17, 19, '> '.padEnd(14), 'yellow');
    A.setTextCentered(21, 'type a code like AF-004821-1, enter = check', 'dim');
    A.showFrame();
    var code = '';
    while (true) {
        A.setText(17, 19, ('> ' + code).padEnd(14), 'yellow');
        A.showFrame();
        var kc = await A.waitRealKeyChar();
        var k = kc.key;
        if (k === 'Escape') { return; }
        if (k === 'Enter') {
            var target = A.challengeTarget(code.trim());
            if (target === null) {
                A.setTextCentered(21, 'invalid code - check the letters and numbers', 'red');
            } else {
                var gname = 'game #' + target.gameIdx;
                if (target.gameIdx >= 0 && target.gameIdx < A.games.length) { gname = A.games[target.gameIdx].name; }
                A.setTextCentered(21, 'beat ' + target.score + ' in ' + gname + ' - pick it and go!', 'green');
            }
            A.setText(17, 19, ('> ' + code).padEnd(14), 'yellow');
            A.showFrame();
            await A.waitRealKey();
            return;
        }
        if (k === 'Backspace') { if (code.length > 0) { code = code.substring(0, code.length - 1); } }
        else if (code.length < 12) {
            var ch = kc.char;
            if (ch && ch.length === 1 && /[A-Za-z0-9\-]/.test(ch)) { code += ch.toUpperCase(); }
        }
    }
};

A.showHighscoresScreen = async function (gameId) {
    var ids = A.games.map(function (g) { return g.id; });
    if (ids.indexOf(gameId) < 0) { gameId = 'snake'; }
    var idx = ids.indexOf(gameId);
    while (true) {
        var gid = ids[idx];
        var g = null;
        for (var gi = 0; gi < A.games.length; gi++) { if (A.games[gi].id === gid) { g = A.games[gi]; } }
        var online = await A.getOnlineScores(gid);
        var list, source, srcCol;
        if (online !== null) {
            list = online; source = 'global leaderboard (live)'; srcCol = 'cyan';
        } else {
            list = A.getLocalScores(gid); source = 'local scores (offline mode)'; srcCol = 'dim';
        }
        A.clearFrame();
        A.drawBox(10, 3, 60, 24, ' high scores ', 'accent');
        A.setText(14, 5, '<', 'dim');
        A.setText(65, 5, '>', 'dim');
        A.setTextCentered(5, g.name, 'yellow');
        A.setTextCentered(6, g.desc, 'dim');
        A.setText(16, 8, '#', 'dim');
        A.setText(20, 8, 'player', 'dim');
        A.setText(59, 8, 'score', 'dim');
        if (list.length === 0) {
            A.setTextCentered(13, 'no scores yet', 'dim');
            A.setTextCentered(14, 'be the first!', 'dim');
        } else {
            for (var i = 0; i < Math.min(10, list.length); i++) {
                var rank = i + 1;
                var name = String(list[i].name);
                if (name.length > 16) { name = name.substring(0, 16); }
                var scoreStr = String(list[i].score);
                var col = (rank === 1) ? 'yellow' : 'fg';
                A.setText(16, 9 + i, ('  ' + rank + '.').slice(-3), col);
                A.setText(20, 9 + i, name.padEnd(17), col);
                A.setText(64 - scoreStr.length, 9 + i, scoreStr, col);
                if (A.playerName && name === A.playerName) { A.setText(38, 9 + i, '<- you', 'accent'); }
            }
        }
        var local = A.getLocalScores(gid);
        var pb = 'your local best: --';
        if (local.length > 0) { pb = 'your local best: ' + local[0].score + '  (' + local[0].name + ')'; }
        A.setTextCentered(20, pb, 'dim');
        A.setTextCentered(22, 'left/right: other games   esc: back', 'dim');
        A.setTextCentered(23, source, srcCol);
        A.showFrame();
        var k = await A.waitRealKey();
        if (k === 'LeftArrow' || k === 'A') { idx = (idx - 1 + ids.length) % ids.length; }
        else if (k === 'RightArrow' || k === 'D') { idx = (idx + 1) % ids.length; }
        else if (k === 'Q' || k === 'Escape' || k === 'Enter' || k === 'Space') { return; }
    }
};

A.showHelpScreen = async function () {
    A.clearFrame();
    A.drawBox(14, 4, 52, 21, ' how to play ', 'accent');
    var lines = [
        ['arrows / wasd', 'move in most games'],
        ['space', 'action: shoot / flap / dash'],
        ['q', 'quit to menu from any game'],
        ['m', 'toggle sound on/off'],
        ['esc', 'back / cancel'],
        ['', ''],
        ['highscores', 'saved per game, top 10'],
        ['online board', 'auto-uploads if configured'],
        ['', ''],
        ['touch', 'use the on-screen dpad + A button'],
        ['', 'on phones and tablets']
    ];
    for (var i = 0; i < lines.length; i++) {
        A.setText(17, 6 + i, lines[i][0].padEnd(18), 'accent');
        A.setText(35, 6 + i, lines[i][1], 'fg');
    }
    A.setTextCentered(23, 'press any key to go back', 'dim');
    A.showFrame();
    A.clearKeyBuffer();
    await A.waitRealKey();
};

A.showMenu = async function () {
    var sel = 0;
    while (true) {
        await A.flushPendingOnlineScores();
        A.clearFrame();
        A.showMenuLogo(3);
        A.setTextCentered(10, 'a tiny terminal arcade - ' + A.games.length + ' games - hi ' + (A.playerName || 'player'), 'dim');
        for (var i = 0; i < A.games.length; i++) {
            var y = 11 + i;
            var g = A.games[i];
            var prefix = '  ', nameCol = 'fg', descCol = 'dim';
            if (i === sel) {
                prefix = A.ch.Arrow + ' ';
                nameCol = 'yellow';
                A.setText(26, y, ' ', 'fg', 'bg2');
                A.setText(27, y, ' ', 'fg', 'bg2');
            }
            A.setText(28, y, prefix + g.name, nameCol);
            A.setText(46, y, g.desc, descCol);
        }
        var top = A.getLocalScores(A.games[sel].id);
        var hsText = 'your best: --';
        if (top.length > 0) { hsText = 'your best: ' + top[0].score + '  (' + top[0].name + ')'; }
        A.setTextCentered(23, hsText, 'dim');
        if (A.updateKnown) {
            var msg;
            if (A.updateAvailable) { msg = 'update available: v' + A.updateRemoteVersion + ' - reload the page'; }
            else { msg = 'you have the latest version (v' + A.version + ')'; }
            A.setTextCentered(22, msg, A.updateAvailable ? 'yellow' : 'dim');
        }
        var stats = '';
        if (A.sessionBestRank > 0) { stats = 'rank #' + A.sessionBestRank + ' this session'; }
        if (A.sessionRuns > 0) {
            if (stats !== '') { stats += '  -  '; }
            stats += A.sessionRuns + ' run' + (A.sessionRuns === 1 ? '' : 's') + ' this session';
        }
        if (stats !== '') { A.setTextCentered(24, stats, 'dim'); }
        A.setTextCentered(25, 'up/down select - enter play - h highscores - c challenge - ? help - m sound - q quit', 'dim');
        A.setTextCentered(26, 'sound: ' + (A.soundOn ? 'on' : 'off') + '   global board: connected', 'dim');
        A.showFrame();
        var blink = false;
        var k = await A.waitKeyOrIdle(3);
        while (k === null) {
            A.setTextCentered(21, blink ? '            ' : 'insert coin', 'orange');
            A.showFrame();
            blink = !blink;
            k = await A.waitKeyOrIdle(1);
        }
        if (blink) { A.setTextCentered(21, ' ', 'orange'); }
        if (k === 'UpArrow' || k === 'W') { sel = (sel - 1 + A.games.length) % A.games.length; A.beep(350, 12); }
        else if (k === 'DownArrow' || k === 'S') { sel = (sel + 1) % A.games.length; A.beep(350, 12); }
        else if (k === 'Enter' || k === 'Space') {
            var gsel = A.games[sel];
            A.clearKeyBuffer();
            await gsel.fn();
        }
        else if (k === 'H') { await A.showHighscoresScreen(A.games[sel].id); }
        else if (k === 'C') { await A.showChallengeScreen(); }
        else if (k === 'OemQuestion' || k === 'Slash' || k === 'F1') { await A.showHelpScreen(); }
        else if (k === 'M') { A.soundOn = !A.soundOn; A.saveConfig(); }
        else if (k === 'Q' || k === 'Escape') { return; }
    }
};


// ---- 40-main.js ----
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

