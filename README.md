# BC Quake

Quake (id Software, 1996) running inside Microsoft Dynamics 365 Business Central.

The whole game runs as AL code on the Business Central server: the engine, the game logic and the software
renderer. The browser only shows the frames, plays the sounds and sends your keyboard and mouse input back.

## How it works

- **The engine is AL.** [src/QuakeEngine.Codeunit.al](src/QuakeEngine.Codeunit.al) is Quake's C source code
  (the WinQuake software renderer) translated to AL by c2al, a C-to-AL compiler. It is about 64,000 generated
  lines; don't edit it by hand.
- **C memory is a list.** The translated code works on a `List of [Integer]` with one element per byte, and C
  pointers are integer addresses into it. Floats are AL Decimals, stored in that memory as their IEEE bytes.
- **The game data is in a table.** The shareware `pak0.pak` ships zipped in the app
  ([Resources/PAK0.zip](Resources/PAK0.zip)). On the first start it is imported into the table *Quake Pak File*,
  one record per file in the PAK, and Quake reads its files from there.
- **Software rendering, sent as row deltas.** Every frame, Quake renders 320×200 palette-indexed pixels in AL.
  Only the rows that changed since the previous frame are sent to the browser (base64), plus the palette when it
  changes.
- **Sound plays in the browser.** Quake's sound code runs in AL and decides what plays on which channel and at
  what volume, but mixes nothing. The control add-in gets those events and plays the WAV files from the PAK with
  Web Audio.
- **The browser drives the game.** The control add-in asks the server for frames and sends the input since the
  last request with each one. Game time follows the wall clock.

## Requirements

- Business Central with application 29.0 or later (AL runtime 18.0), as set in [app.json](app.json).
- Free object IDs 65000–65999.
- About 20 MB of database space for the imported PAK.

## Installing

1. Open the folder in VS Code with the AL Language extension.
2. Add a `.vscode/launch.json` for your Business Central server (it is not in the repository) and download the
   symbols.
3. Publish the app. With `"startupObjectId": 65000` in `launch.json`, the game page opens right away.
4. Assign the permission set **BC Quake** to the users who should play.

## Playing

Open the page **BC Quake** (search for it, or page 65000).

- **First start:** the shareware PAK is imported into the database. This happens once and takes a while.
- **Startup:** Quake starts the way it did in 1996, with the demos running. Press Escape for the menu, then
  choose Single Player → New Game.
- **Level loads:** loading a level takes several seconds. The screen says "Quake is loading in Business
  Central..." meanwhile.
- **Mouse:** click the screen to use it (the browser locks the pointer to the game).
- **Sound:** starts after your first key press or click (browsers block audio until then).

### Controls

| Input | Action |
|---|---|
| Mouse | Look around (mouse look is on) |
| W A S D | Move and strafe |
| Arrow keys | Move forward and back, turn |
| Left mouse button, Ctrl | Fire |
| Right mouse button, Space | Jump |
| Shift | Run |
| 1–8 | Weapons |
| Tab | Scores |
| F6 | Quicksave |
| Escape | Menu |
| ` (backquote) | Console |

The WASD and mouse button bindings are set the first time you play, since Quake's 1996 defaults predate them.
After that, your settings, including any keys you rebind in the menu or console, are saved in `config.cfg`.

The control add-in keeps a few function keys for itself, and they don't reach Quake. So Quake's quickload (F9)
isn't available: type `load quick` in the console instead.

| Key | Action |
|---|---|
| F8 | Pipelining on/off (see Performance) |
| F9 / F10 | Fewer / more frames per server request |
| F11 | Upscaling filter |
| F12 | Performance overlay |

### Settings and save games

Quake's files are kept per user in the table *Quake User File*: `config.cfg` (settings and key bindings), the
save games `s0.sav`–`s11.sav` and the quicksave `quick.sav`. The page **Quake Settings and Save Games** lists them. Delete `config.cfg` there to
go back to the default settings.

### The registered version

The page **Quake PAK Files** has an **Import PAK File** action. Upload `pak1.pak` from a registered copy of Quake,
open **BC Quake** again, and Quake loads it next to the shareware PAK. This path hasn't been tested much yet.

## Performance

On the server we tested on:

- **Startup:** about a second.
- **One frame:** about 85–100 ms of server time.
- **Round trip:** the client-to-server round trip costs about as much again, so the add-in pipelines its
  requests. The next request is sent before the previous frame arrives, timed to reach the server just as it
  finishes. F8 turns this off for comparison.

F12 shows the timings per frame and a small benchmark of the AL operations the engine is made of (`Mem.Get`,
procedure calls, float conversions and so on), measured on your server.

## Limitations

- No music. Quake played its music from the CD.
- Single player only. There is no network play.
- 320×200, like the original software renderer.
- The game lives in the page's session, so closing the page ends it. Save first.

## Hacker's guide

The game is plain AL, so you can change it like any other AL code. Two things to know first:

- **The engine codeunit is generated.** If [src/QuakeEngine.Codeunit.al](src/QuakeEngine.Codeunit.al) is
  regenerated from the C sources, your edits are lost, and the addresses and offsets below can change. They
  match the code in this repository.
- **These cheats are for single player.**

Every example below compiles, and was checked against a JavaScript build of the same code.

### Finding your way around

- **Every C function is an AL procedure with the same name.** A comment above it says where it came from, e.g.
  `// sv_user.c:380` above `SV_ClientThink`. id's original source,
  [id-Software/Quake](https://github.com/id-Software/Quake) (the WinQuake folder), is the best map. The line
  numbers are from a slightly patched copy, so they're close, not exact. C names that start with `_` get a `u_`
  prefix: `_Host_Frame` is `u_Host_Frame`.
- **C memory is `Mem`**, a `List of [Integer]` with one byte per element. The byte at C address `A` is
  `Mem.Get(A + 1)`. The public procedures `PeekInt`, `PokeInt`, `PeekByte` and `PokeByte` take C addresses.
- **Simple C globals are AL variables with the C name:** `sv_player`, `host_frametime`, `cmd_source` and so on.
  Structs and arrays live in `Mem` at a fixed address, which shows up in the code as a plain number.
- **Floats are Decimals.** A long expression like `F32[Mem.Get(A + 4) * 2 + ...] * (...)` reads the float at
  address `A`, and `Rt_StoreF32(A, Value)` writes one.
- **Struct fields are offsets.** `sv_player + 288` is `sv_player->v.health`. To find a field, read the AL of a C
  function that uses it. For example, `Host_Give_f` (the `give` command) writes all the ammo fields.

The player's fields, as offsets from `sv_player`. QuakeC keeps everything as floats.

| Offset | Field |
|---|---|
| 128 | `movetype` |
| 136 | `origin` (x, y, z) |
| 160 | `velocity` (x, y, z) |
| 288 | `health` |
| 312, 316, 320, 324 | `ammo_shells`, `ammo_nails`, `ammo_rockets`, `ammo_cells` |
| 328 | `items` (the weapons and powerups you have, as bits) |
| 400 | `flags` (64 = god mode, 128 = notarget) |

### Cheat 1: Quake's own cheats (no code)

Quake has cheat commands for single player. Open the console with ` (backquote) and type one:

| Command | Effect |
|---|---|
| `god` | You can't be hurt |
| `noclip` | Fly through walls |
| `fly` | Fly |
| `notarget` | Monsters ignore you |
| `impulse 9` | All weapons and ammo |
| `impulse 255` | Quad damage |
| `give r 50` | 50 rockets (`s`, `n`, `r`, `c` for ammo, `h` for health) |
| `map e1m8` | Go to another level |

### Cheat 2: cheat keys

The engine's public procedure `bc_command` runs console commands, and `AllocText` copies AL text into C memory.
In the page **BC Quake** ([src/BCQuake.Page.al](src/BCQuake.Page.al)), procedure `StartQuake`, add one line
after `Quake.StartQuake();`:

```al
            Quake.StartQuake();
            // cheat keys: G god mode, N noclip, I all weapons and ammo
            Quake.bc_command(Quake.AllocText('bind g god; bind n noclip; bind i "impulse 9"'));
```

Key bindings are saved in `config.cfg`, so they stay after you remove the line again (`unbind g` removes one).
`AllocText` takes C memory that is never freed. That's fine for a command now and then, but don't do it every
frame.

### Cheat 3: health and ammo that never run low

This one changes the engine. `SV_ClientThink` runs every server frame with `sv_player` pointing at you. Add two
procedures to the codeunit **Quake Engine**:

```al
    // the float at C address Addr: the decode that the generated code writes out inline
    local procedure LoadFloat(Addr: Integer): Decimal
    begin
        exit(F32[Mem.Get(Addr + 4) * 2 + Mem.Get(Addr + 3) div 128 + 1] *
            ((Mem.Get(Addr + 3) mod 128) * 65536 + Mem.Get(Addr + 2) * 256 + Mem.Get(Addr + 1) + 8388608));
    end;

    // runs for the player every server frame (called from SV_ClientThink)
    local procedure Cheats()
    var
        Health: Decimal;
        i: Integer;
    begin
        // sv_player->v.health never drops below 100 while you're alive
        Health := LoadFloat(sv_player + 288);
        if (Health > 0) and (Health < 100) then
            Rt_StoreF32(sv_player + 288, 100);
        // ammo_shells, ammo_nails, ammo_rockets, ammo_cells: 4 floats from offset 312
        for i := 0 to 3 do
            if LoadFloat(sv_player + 312 + i * 4) < 100 then
                Rt_StoreF32(sv_player + 312 + i * 4, 100);
    end;
```

Then call `Cheats()` first thing in `SV_ClientThink`:

```al
    local procedure SV_ClientThink()
    var
        v_angle_0: Decimal;
        v_angle_1: Decimal;
        v_angle_2: Decimal;
    begin
        Cheats();
        ...
```

A hit that does more than 100 damage at once can still kill you. For real invulnerability, also switch on god
mode (bit 64 of `flags`, offset 400) at the end of `Cheats`:

```al
        if LoadFloat(sv_player + 400) div 1 mod 128 < 64 then
            Rt_StoreF32(sv_player + 400, LoadFloat(sv_player + 400) + 64);
```

### Cheat 4: moon gravity

In `SV_AddGravity` (from `sv_phys.c`), entities without a gravity of their own fall with gravity 1. Change
that line:

```al
        end else begin
            ent_gravity := 0.25;
        end;
```

Everything now falls at a quarter of the speed: you, the monsters, grenades and gibs. Jump and you hit the
ceiling.

### Cheat 5: slow motion

`Frame`, in the same codeunit, gets the real time that passed since the previous frame. Halve it as the first
line:

```al
    procedure Frame(ElapsedMs: Integer)
    begin
        ElapsedMs := ElapsedMs div 2; // slow motion: half the time passes in the game
```

The server still renders as many frames per second, but the game world moves at half speed.

### Trying your changes

Publish the app and open the page **BC Quake** again. Each page has its own Quake, so the change applies from
the next page you open. If an edit makes a loop run forever, the loop guard stops the frame after a minute.
The error then shows the AL call stack, whose procedure names are the C function names.

## Things AL taught us along the way

The translated code ran fine under a JavaScript test build that mirrors AL, but Business Central still had
some surprises:

- **`and` / `or` evaluate both sides.** `(j >= 1) and (List.Get(j) > x)` calls `List.Get(0)`.
- **`Round(x, 1, '>')` is not `ceil` for negative numbers.** It rounds away from zero: `Round(-0.3, 1, '>')` is -1,
  and `Round(-0.3, 1, '<')` is 0. Using it as `ceil` put edges on scan line -1 and hung the renderer.
- **An Integer intermediate outside 32 bits is a runtime error**, even inside a larger expression. Use Decimal or
  BigInteger for large products.

## Repository layout

| Path | Contents |
|---|---|
| [src/QuakeEngine.Codeunit.al](src/QuakeEngine.Codeunit.al) | The game: Quake translated to AL (generated) |
| [src/BCQuake.Page.al](src/BCQuake.Page.al) | The page that hosts the game and runs the frames |
| [src/QuakePakImport.Codeunit.al](src/QuakePakImport.Codeunit.al) | Imports PAK files into the table *Quake Pak File* |
| [src/QuakePakFile.Table.al](src/QuakePakFile.Table.al), [src/QuakeUserFile.Table.al](src/QuakeUserFile.Table.al) | Game data, and the per-user settings and save games |
| [src/QuakePakFiles.Page.al](src/QuakePakFiles.Page.al), [src/QuakeUserFiles.Page.al](src/QuakeUserFiles.Page.al) | Pages for both tables |
| [src/controladdin/](src/controladdin/) | The *Quake Screen* control add-in: display, sound, input |
| [Resources/PAK0.zip](Resources/PAK0.zip) | The shareware `pak0.pak` (episode 1) |

The C-to-AL translator (c2al) and the Quake C sources that the engine codeunit is generated from are not part
of this repository.

## Credits and license

- **Quake** is © 1996 id Software. id released the engine source code under the GNU General Public License
  version 2 ([id-Software/Quake](https://github.com/id-Software/Quake)).
- **The port** is based on [ColleagueRiley/quake](https://github.com/ColleagueRiley/quake), with id's WinQuake
  software renderer.
- **The control add-in** started out as the one from BC DOOM.

BC Quake is licensed under the GNU General Public License, version 2 or (at your option) any later version, like
the Quake source code it is derived from. See [LICENSE](LICENSE).

The game data in [Resources/PAK0.zip](Resources/PAK0.zip) is the shareware `pak0.pak`, © id Software. It is not
covered by the GPL.
