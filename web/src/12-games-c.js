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
