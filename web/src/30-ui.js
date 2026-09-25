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
