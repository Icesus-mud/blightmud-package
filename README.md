# Icesus Blightmud package

Official [Blightmud](https://github.com/Blightmud/Blightmud) starter
package for [Icesus MUD](https://icesus.org). Reads GMCP and gives
you a four-row status area at the bottom of the terminal: where you
are and the way out, what you are doing and what is cooling down,
the fight and what is wrong with you, and your pools, guild
resources and exp. It also binds your saved hotkeys and a momentum
key, and ships a few example aliases and lites to copy from.

It is deliberately small. The Mudlet package has a full HUD, mapper
and chat window; this one is for players who live in a terminal and
want signal without a sidebar.

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

You should see a green `[Icesus] package v0.2.0 loaded.` line and
the status area fill within a few seconds of connecting. Type
`/icesus` for your keys and the package's commands.

**Updating:** `git -C ~/.config/blightmud pull`, then `/reload`.

## What you get

**Status area** (bottom four rows). Each row keeps the most useful
things at its left. When the terminal is too narrow for a row, it
switches to a shorter form first (bond initials, enemy names
dropped), then cuts from the right.

- **Location**: room name, area, `SAFE` and `INN` when they apply,
  and the exits (`n e s w u`, with doors and special exits such as
  `enter tavern` spelled out).
- **Action**:
  - Momentum when it is up, with the key that uses it:
    `» STRIKE alt-m`. Crafting momentum names its source
    (`» mining: CHASE THE RICH VEIN`).
  - A casting bar while a spell runs, or what you are busy with
    (`⋯ Using smelting`).
  - Cooldowns counting down, red while fresh, green when nearly
    done.
- **Condition**:
  - Enemies, with HP coloured by the server's `consider` shape
    buckets, so the bar can't pretend to know more than the game
    does.
  - Afflictions (`STUNNED`, `POISONED`, `BURNING`, `DEATH
    SICKNESS`) and bleeding wounds by body part.
  - Concealment you switched on (`SILENT`, `HIDDEN`, `INVIS`), so
    you see it when one lapses.
  - Karma you spent (`☯ EXP LUCK`).
- **Vitals**:
  - `Hp / Sp / Ep` (and `Psp` if you have `set psp_on`).
  - Your guild resource where it has one: fury, vitae, a templar's
    bond strengths with ▲ / ▼ for filling or draining, and the
    active charm.
  - Exp with progress to your next level. At level 100 it shows
    `AP` and progress to the next advancement point instead.
  - The in-game hour.

**Keys**
- **F1-F12** are the hotkeys saved on your character, the same set
  the [web client](https://play.icesus.org) edits and shows as
  buttons. They arrive when you log in. Every character starts with
  `look`, `score`, `inventory` and so on.
- **alt-m** uses whatever momentum is lit, and **alt-s** uses your
  special momentum. When nothing is lit they say so and send
  nothing.

**Commands**
- `/icesus`: version, your keys, and the rows in use.
- `/icesus guild`: the rest of your guild resources. That covers
  bond load and drain, your souls (largest first), charm abilities,
  and your standing with the nine.

**Examples to copy from**
- `icesus/aliases.lua` — `deposit` shortcut and `dg` (dig grave +
  loot) showing the gag/echo helper pattern.
- `icesus/lites.lua` — single trigger that highlights the
  "stops spinning" line as a stun-recovery cue. Pattern to clone
  for your own lites.
- `icesus/bindings.lua` — `home`/`end` cursor binds, mouse-wheel
  scroll binds, and the momentum keys.

**Connection**
- `servers.ron` ships with `Icesus` preconfigured for TLS on port
  4443. `/connect Icesus` and you're in.
- `settings.ron` enables logging, split scrolling, command search,
  smart history, and input echo.

## Customising

Put your own changes in `local.lua` next to `config.lua`. It loads
after the package, it is in `.gitignore`, and `git pull` leaves it
alone. For example:

```lua
-- Fewer rows: pick any of 'location', 'action', 'condition',
-- 'vitals', in the order you want them (at most five).
Icesus.rows = { 'condition', 'vitals' }
Icesus.layout()

-- Keep F1-F12 for your own binds instead of the saved hotkeys.
-- Turn them off and apply before binding your own.
Icesus.hotkeys.use_server = false
Icesus.apply_hotkeys()
blight.bind('f1', function() mud.send('use strike') end)

-- Move momentum to another key; the status row follows.
Icesus.bind_momentum('f12', 1)   -- 1 = momentum, 2 = special
```

`/reload` re-runs the whole config. Edit a file, type `/reload`,
see your change.

## File layout

```
config.lua             -- top-level: loads icesus/init.lua on connect
servers.ron            -- /connect Icesus → icesus.org:4443 TLS
settings.ron           -- Blightmud client settings
icesus/init.lua        -- entry point, settings, version banner, palette
icesus/status.lua      -- GMCP → status rows
icesus/keys.lua        -- saved hotkeys on F1-F12, momentum keys
icesus/commands.lua    -- /icesus, /icesus guild
icesus/aliases.lua     -- deposit, dg
icesus/lites.lua       -- stun-recovery highlight
icesus/bindings.lua    -- home/end, mouse wheel, momentum keys
icesus/stylua.toml     -- StyLua formatting config
tools/fake_server.py   -- pretend server for trying changes offline
```

## GMCP packages used

```
Char.Vitals      pools, guild scalars (fury, vitae, ...)
Char.Status      exp, enemies, effects, wounds, stealth, karma,
                 momentum, busy activity, psp_on
Char.Casting     casting bar
Char.Cooldowns   cooldowns
Char.Resources   bonds, charm; souls and piety for /icesus guild
Room.Info        location row
World.Time       hour name
Client.Hotkeys   F1-F12
```

Type `help gmcp` in the game for the full spec. There is more on the
wire than this package reads (`Comm.Channel.*`, `Room.Speech`,
`Party.Info`, `Comm.Who`, …).

## Trying changes without the game

`tools/fake_server.py` plays a fixture of GMCP messages and text
lines to a client on your own machine, echoes back what you type,
and prints every GMCP message the client sends, so you can watch a
key or command do its work.

```sh
tools/fake_server.py 4000 tools/fixtures/fight.json
```

The package only loads for `icesus.org`, so for the fake server add
this to `local.lua` and `/connect 127.0.0.1 4000`:

```lua
if store.session_read('cur_host') == '127.0.0.1' then
  script.load(blight.config_dir() .. '/icesus/init.lua')
end
```

Scripts load in the order they are queued, so on this path the rest
of `local.lua` runs before the package. Move anything that touches
`Icesus` into its own file and `script.load` it after that line.

## Roadmap

Ideas that would make a good PR:

1. **Channel feed**: Blightmud has no side panes, but channel and
   tell lines could be tagged so Blightmud's tag filters
   (`blight.filter_tag_key`) can hide or show them.
2. **Party row**: HP per member from `Party.Info`.
3. **Saved triggers**: the web client's triggers (`Client.Triggers`)
   as Blightmud triggers.

## Contributing

Issues and PRs welcome at
<https://github.com/Icesus-mud/blightmud-package>. For Lua style,
match what's already there — `icesus/stylua.toml` has the formatter
config (StyLua, 2-space indent, single quotes, 120-column).

## License

MIT — see [LICENSE](LICENSE).
