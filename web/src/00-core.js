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
