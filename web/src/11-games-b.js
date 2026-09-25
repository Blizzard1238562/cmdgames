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
