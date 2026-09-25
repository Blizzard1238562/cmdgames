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
