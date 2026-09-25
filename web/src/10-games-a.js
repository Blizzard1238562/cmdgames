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
