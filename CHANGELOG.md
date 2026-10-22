# Changelog

## v0.2.2 — 2026-10-22

- **No more "Can't migrate servers.ron" on every start.** `config.lua`
  symlinked `servers.ron` and `settings.ron` into
  `~/.local/share/blightmud/data/`, with a comment claiming Blightmud
  5.x reads them there. It doesn't: Blightmud moved both files into
  the config directory in 3.0
  ([Blightmud#202](https://github.com/Blightmud/Blightmud/pull/202)),
  reads them from beside `config.lua`, and warned about the links on
  every start. The links are gone, and `config.lua` removes the ones
  earlier versions made (only links that point back at the package).
  Reported by Tenki.

## v0.2.1 — 2026-10-22

- **`/icesus simple` and `/icesus full`** switch between the two-row
  status area of v0.1 (enemies over pools, exp and hour) and the
  four-row one. Blightmud remembers the choice across sessions.
  `/icesus` names the layout in use.
- New `enemies` row (the fight alone) for building your own layout.

## v0.2.0 — 2026-10-22

Catches the package up with what the server has been sending since
May, and with what the Mudlet package and the web client already
show.

- **Four status rows instead of two.** Location (room, area, `SAFE`,
  `INN`, exits), action (momentum, casting or busy bar, cooldowns),
  condition (enemies, afflictions, wounds, concealment, karma) and
  vitals (pools, guild resources, exp, hour). Enemies moved from the
  top row to the condition row and now carry their names when there
  is room.
- **Rows fit the terminal.** A row that is too wide is drawn in a
  shorter form first, then cut from the right with `…`. Before, the
  terminal wrapped it onto the line below.
- **Exp progress was measuring the wrong thing.** It showed progress
  to the next advancement point at every level. It now shows
  progress to the next level, and switches to advancement points
  (`AP`) at level 100, as the Mudlet package and the web client do.
  Exp prints with thousands separators. A full bar reads `100%+`.
- **Pools read `Hp 81%`** instead of `Hp:  81/100`, to make room for
  the rest of the row.
- **Momentum.** The action row shows momentum when it is up, and
  `alt-m` / `alt-s` use whatever is lit in each lane, so the key is
  never pressed blind. This replaces `f1 = use strike`, which sent
  `use strike` whether or not there was a strike to use.
- **Saved hotkeys on F1-F12.** The F-keys follow the hotkeys saved
  on your character (`Client.Hotkeys`), the same set the web client
  edits. Opt out with `Icesus.hotkeys.use_server = false`.
- **Guild resources.** Fury and vitae from `Char.Vitals`, templar
  bond strengths with a filling / draining arrow, and the active
  charm from `Char.Resources` sit beside the pools. `/icesus guild`
  prints bond load and drain, souls, charm abilities and devotion.
- **Casting and busy.** A casting bar from `Char.Casting`, or the
  activity you are busy with from `Char.Status`.
- **Cooldowns** from `Char.Cooldowns`, counting down between the
  server's updates.
- **Afflictions, wounds, concealment, karma** from `Char.Status`:
  `effects`, `wounds`, `stealth` and `karmas`.
- **`/icesus`** lists your keys, the rows in use and the commands.
- **Customising from `local.lua`.** `Icesus.rows`,
  `Icesus.hotkeys.use_server`, `Icesus.bind_momentum()`; see the
  README.
- **Reconnecting no longer doubles the package up.** `config.lua`
  loads the package on every connect, and each load added another
  set of listeners, so after a reconnect every typed line echoed
  twice. The package now loads once per session; `/reload` still
  starts afresh. The status area clears on disconnect.
- **`tools/fake_server.py`** plays GMCP fixtures to a local client
  for trying changes without the game.
- README: the GMCP spec is `help gmcp` in the game, not a server
  path players cannot open.

## v0.1.0 — 2026-05-11

Initial release. Built on top of [Tenki's `icesus-blightmud`
starter](https://codeberg.org/nichiren/icesus-blightmud) — thanks
Tenki for doing the first pass.

Changes from the starter:

- **Bugfix: alias `msend()` gag flag was inverted.** The local `gag`
  was computed but never used; `mud.send()` received `show_sent`
  directly, so `msend('foo', true)` *hid* the input instead of
  showing it. The helper now passes the right value and the body
  collapses to `mud.send(msg, { gag = not show_sent })`.
- **Bugfix: status pane could divide by zero.** `colour_for_ratio`
  and `fmt_pct` divided current by max without guarding against
  `max == 0`, which happens before the first `Char.Vitals` arrives
  and briefly during reincarnation. Both now go through a `pct()`
  helper that returns 0 when max is missing or non-positive.
- **Enemy HP colours aligned with the server's shape buckets.**
  Tenki's thresholds were 66/33/15; the server's documented buckets
  (see `Char.Status.enemies`) are 100/99/90/80/70/60/50/40/30/20/10/5.
  New bands (>=70 / >=40 / >=20 / else) line up with the shape words
  `consider` would tell you so the bar can't pretend to know more than
  the game does.
- **Explicit GMCP sub-package subscriptions.** Switched from
  `gmcp.register('Char')` / `gmcp.register('World')` to explicit
  `Char.Vitals`, `Char.Status`, `World.Time`. Matches the
  Mudlet package's pattern and survives any future server-side
  gating.
- **Version banner on load.** `[Icesus] package v0.1.0 loaded.` so
  players can tell which version they're running.
- **Added `LICENSE` (MIT), `CHANGELOG.md`, `.gitignore`.**
- **README rewritten** — install steps, feature list, GMCP coverage,
  roadmap, credit. Fixed "an starting point" / "complexcity" typos.
