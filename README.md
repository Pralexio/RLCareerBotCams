# botcams: pro camera settings on every bot

In RL Career Hub, the player view and the goal replays use the watched car's own
camera settings. A bot has none, so you get the game's defaults (90 FOV).
This gives every bot the real camera of the pro it is named after, in ball cam,
so a player's view looks like the pro's own stream.

Status: works on the author's machine, tested on a handful of career matches
(Ultimate, spectating). Not tested on other setups.

## How it works

Two parts, both outside the hub's own code:

1. `cameras.py` downloads Liquipedia's "List of player camera settings"
   (about 1,400 players, one request) and writes `cameras.txt`, one line per player:

       * 110 100 -3.0 270 0.35 4.00 1.40        everyone not listed
       atow 110 100 -3.0 270 0.40 4.20 1.40     fov height angle distance stiffness swivel transition

   The plugin runs it by itself when the list is missing or a week old. If the
   download fails, the old file stays.

2. `botcams.dll`, a BakkesMod plugin, reads `cameras.txt` and sets the settings on
   every player of the match, every two seconds while a match is on, with ball cam on.
   It never touches your own camera: free cam, RLCS view and player views work as usual;
   when you switch to a bot's view you see it in ball cam. It skips the local player and
   spectators, and does nothing in online games.

Names are compared without case, spaces or punctuation, so the hub's "Atow."
finds Liquipedia's "Atow". A player who is not on the list gets the `*` line
(zen's camera by default).

## Install

Needs RL Career Hub (its Python is used to fetch the list) and BakkesMod.
Download the latest `botcams-x.y.zip` from this repository's **Releases** page
(it contains the compiled `botcams.dll`; the repository itself holds only the source).

1. Close Rocket League.
2. Right-click the zip, **Extract All**, open the extracted folder.
3. Double-click `install.bat`. It checks that RL Career Hub and BakkesMod are installed,
   copies the files, enables the plugin and downloads the camera list, with an `[OK]` or
   `[ERROR]` line for each step. If RL Career Hub is installed somewhere unusual and
   can't be found, it asks you to paste its folder.
4. Start Rocket League.

By hand instead: create `%APPDATA%\rl-career-hub\botswap\` and put `cameras.py` in it,
copy `botcams.dll` to `%APPDATA%\bakkesmod\bakkesmod\plugins\`, and add this line at the
end of `%APPDATA%\bakkesmod\bakkesmod\cfg\plugins.cfg`:

    plugin load botcams

The camera list downloads by itself the first time Rocket League loads the plugin, then
again whenever it is a week old (one Liquipedia request, in the background). The new
list is used from the next kickoff.

## Tactic keys

The hub binds its team tactics to 1 and 2, which are also the keys that switch the
spectator camera to a player: every press changed both the view and the tactic. The
plugin moves the tactics to N (more defensive) and M (more attacking) when the game
loads and at every kickoff, and leaves 1 and 2 to the cameras. The hub puts its keys
back each time it starts, so this is redone automatically; you don't have to do anything.

## Settings

- Default camera: put `{"defaultCamera": "vatira"}` in a `config.json` beside
  `cameras.py`; it applies at the next weekly refresh (or delete `cameras.txt` and restart the game).
- One player by hand: edit his line in `cameras.txt` (overwritten at the next weekly download).
- BakkesMod console: `botcams_apply` applies now and prints how many players were set,
  `botcams_enabled 0` turns the plugin off, `botcams_ballcam 0` leaves the bots' ball cam alone.
- Tactic keys: `botcams_tactic_down_key B` / `botcams_tactic_up_key V` (any key name), or
  `botcams_tactic_keys 0` to leave the hub's keys alone. These settings are saved.

## Bugs and feedback

Open an issue on this repository, with what you did, what you expected, and the
lines starting with `botcams` from `%APPDATA%\bakkesmod\bakkesmod\bakkesmod.log`.
The mod is maintained, but not around the clock: depending on when something comes
up, a fix can take a little while.

## Build from source

`botcams.cpp` is the whole plugin (about 200 lines). `build.bat` builds it with
Visual Studio 2022 and the SDK that ships with BakkesMod, then installs it.
Edit the Visual Studio path in it if yours differs.

## Limits

- Only Liquipedia's "notable players" list is read (career earnings above $2,000).
  Everyone else gets the default camera.
- The table is parsed from Liquipedia's rendered page. If they change its layout,
  the download is refused and the old `cameras.txt` is kept.
- The plugin reads a fixed path under `%APPDATA%\rl-career-hub\botswap\`.
- Built into the hub, none of this would be needed as a separate plugin: the hub's
  own plugin could set the cameras, and the hub could ship or fetch the list itself.

## Credits

Camera settings come from Liquipedia (liquipedia.net/rocketleague), whose text is
licensed CC BY-SA 3.0. Their API terms ask for an identified client and few
requests; this makes one request a week. No Liquipedia data is included in this
package: each install downloads its own copy.
