# PS-ARCADE 🕹️

A tiny terminal arcade for Windows with **10 games**, muted retro colors,
sound, and highscores (local + optional global Supabase leaderboard).

No installs. No dependencies. One file.

## Play it

From any Windows 10/11 PC with PowerShell:

```powershell
irm https://YOUR-RAW-URL/arcade.ps1 | iex
```

Or if you have the file locally:

```powershell
./arcade.ps1
```

## The games

| Game | Controls | About |
|---|---|---|
| Snake | arrows / WASD | eat, grow, survive |
| Tetris | arrows + space | stack, clear lines, level up |
| 2048 | arrows / WASD | merge tiles to 2048 |
| Space Invaders | arrows + space | shoot the alien fleet |
| Flappy | space | flap through the gaps |
| Breakout | arrows | smash every brick |
| Frogger | arrows | cross road and river |
| Dodge | arrows + space (dash) | survive the swarm |
| Tic-Tac-Toe | arrows + enter, 1-9 | beat the CPU (a loss ends the run) |
| Hangman | letters | guess the word |

Global keys in every game: `q` back to menu · `m` mute · `esc` back.

## Highscores

- **Local**: top 10 per game, stored in `~/.ps-arcade/scores.json` — always on.
- **Global (optional)**: if Supabase is configured, every saved score is also
  uploaded and the highscore screen shows the worldwide top 10.

To enable the global board:

1. Create a free project at [supabase.com](https://supabase.com).
2. Apply the SQL in order: `supabase/migrations/20260924000000_init.sql`,
   then `supabase/migrations/20260924010000_hardening.sql`
   (Supabase SQL editor, or `supabase db push`).
3. Set your credentials (either option works):
   - env vars before starting:
     ```powershell
     $env:ARCADE_SUPABASE_URL     = "https://YOURPROJECT.supabase.co"
     $env:ARCADE_SUPABASE_ANON_KEY = "YOUR-ANON-KEY"
     ./arcade.ps1
     ```
   - or once, saved into `~/.ps-arcade/config.json`:
     ```json
     { "supabaseUrl": "https://YOURPROJECT.supabase.co", "supabaseKey": "YOUR-ANON-KEY" }
     ```

The anon key is safe to distribute (the script ships with it baked in).

### Anti-cheat / security model

The public anon key **cannot** write arbitrary scores. All writes go through
a server-side RPC (`submit_score`) that enforces:

- **game whitelist** — only the 10 known game ids are accepted
- **score ceiling** — scores above 1,000,000 are rejected
- **name sanitizing** — control/unicode chars stripped, charset + length limits
- **rate limiting per IP** — 1 submission/minute, 30/day (logged internally)
- **no direct table access** — `INSERT/UPDATE/DELETE/TRUNCATE` revoked from
  anon; the submissions log is invisible to anon too; SELECT is the only
  thing the public key can do.

## For developers

```
src/           game + engine sources, concatenated in filename order
build.ps1      builds the single-file arcade.ps1 (plain UTF-8, no BOM -
               a BOM would break `irm url | iex`)
arcade.ps1     generated artifact - do not edit by hand
supabase/      leaderboard schema + hardening migrations
```

```powershell
./build.ps1        # rebuild
./arcade.ps1 -SelfTest   # headless smoke test of every game
./arcade.ps1 -ListGames  # list the game registry
```

Headless test one game only: `$env:ARCADE_TEST_GAME = "snake"; ./arcade.ps1 -SelfTest`

## Notes

- Needs a console window of at least 84x34; the script tries to resize it.
- Colors are ANSI 256-color; works in Windows Terminal and classic conhost
  on Win10+.
- Sound uses console beeps; toggle with `m`.
