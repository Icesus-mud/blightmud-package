# Changelog

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
