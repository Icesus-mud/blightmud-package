# Icesus Blightmud package

Official [Blightmud](https://github.com/Blightmud/Blightmud) starter
package for [Icesus MUD](https://icesus.org). Reads GMCP and gives
you a two-line status area at the bottom of the terminal — pool
gauges, exp progress, in-game time, and a per-enemy HP strip — plus
a small set of example aliases, lites, and keybindings to copy from.

It is deliberately small. The Mudlet package has a full HUD; this
one is for players who live in a terminal and want signal without
a sidebar.

Built on top of [Tenki's `icesus-blightmud`
starter](https://codeberg.org/nichiren/icesus-blightmud), with bug
fixes and polish for the first official release. Thanks Tenki.

## Install

Blightmud reads its config from `~/.config/blightmud/` on Linux,
`~/Library/Application Support/blightmud/` on macOS.

Fresh install (no existing Blightmud config):

```sh
git clone https://github.com/Icesus-mud/blightmud-package.git ~/.config/blightmud
blightmud
/connect Icesus
```

If you already have a Blightmud config you want to keep, copy the
files in side-by-side and merge `settings.ron` and `servers.ron` by
hand — both are RON dictionaries you can extend.

You should see a green `[Icesus] package v0.1.0 loaded.` line and
the bottom two-row status area populate within a few seconds of
connecting.

## What you get

**Status area** (bottom two rows)
- **Top row** — per-enemy HP percentages, coloured by the server's
  `consider` shape buckets so the bar can't pretend to know more
  than the game does.
- **Bottom row** — `Hp / Sp / Ep` (and `Psp` if you have `set
  psp_on`), `Exp` with progress to next advancement, and the named
  in-game hour from `World.Time`.

**Examples to copy from**
- `icesus/aliases.lua` — `deposit` shortcut and `dg` (dig grave +
  loot) showing the gag/echo helper pattern.
- `icesus/lites.lua` — single trigger that highlights the
  "stops spinning" line as a stun-recovery cue. Pattern to clone
  for your own lites.
- `icesus/bindings.lua` — `home`/`end` cursor binds, mouse-wheel
  scroll binds, and `f1 = use strike`. Replace with your own.

**Connection**
- `servers.ron` ships with `Icesus` preconfigured for TLS on port
  4443. `/connect Icesus` and you're in.
- `settings.ron` enables logging, split scrolling, command search,
  smart history, and input echo.

## File layout

```
config.lua             -- top-level: loads icesus/init.lua on connect
servers.ron            -- /connect Icesus → icesus.org:4443 TLS
settings.ron           -- Blightmud client settings
icesus/init.lua        -- entry point, version banner, colour palette
icesus/status.lua      -- GMCP → two-row status area
icesus/aliases.lua     -- deposit, dg
icesus/lites.lua       -- stun-recovery highlight
icesus/bindings.lua    -- home/end, mouse wheel, f1
icesus/stylua.toml     -- StyLua formatting config
```

`/reload` re-runs the whole config. Edit a file, type `/reload`,
see your change.

## GMCP packages used

This package subscribes to the sub-packages it actually reads:

```
Char.Vitals    pool gauges
Char.Status    enemies, exp, psp_on
World.Time     hour name
```

The full Icesus GMCP spec lives in the mudlib at
`/mud/lib/doc/help/gmcp.doc` — there is much more available
(`Char.Casting`, `Char.Cooldowns`, `Room.Info`, `Comm.Channel.*`,
`Party.Info`, …). PRs that surface more of it are welcome.

## Roadmap

Anything below would make a good first PR:

1. **Casting / busy bar** — `Char.Casting.progress / cps` and
   `Char.Status.activity` as a third status row.
2. **Cooldown row** — pills from `Char.Cooldowns`.
3. **Status effects strip** — colour-coded badges from
   `Char.Status.effects`.
4. **Channel feed** — split window for `Comm.Channel.Text` /
   `Comm.Channel.Tell` / `Room.Speech` so chat doesn't scroll the
   main pane.
5. **Party panel** — `Party.Info` HP bars per member.
6. **Location row** — `Room.Info` name + area + open exits.

## Contributing

Issues and PRs welcome at
<https://github.com/Icesus-mud/blightmud-package>. For Lua style,
match what's already there — `icesus/stylua.toml` has the formatter
config (StyLua, 2-space indent, single quotes, 120-column).

## License

MIT — see [LICENSE](LICENSE).
