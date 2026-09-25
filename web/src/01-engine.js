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
