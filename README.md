# Rally Run

Rally Run is a Playdate SDK Lua arcade game about threading a tiny rally car through maze roads, collecting flags, and outmaneuvering rival cars before the fuel runs dry.

The game is inspired by classic maze-driving chase games, with procedural stages, a side HUD, radar, synth audio, smoke clouds, and a saved high score.

## Gameplay

- Collect all 10 flags to clear a stage.
- Each flag is worth more than the last flag collected in the stage.
- Avoid the rival cars. Crashing costs one life.
- Watch the fuel gauge. Running out of fuel also costs one life.
- Drop smoke to stun rivals and score a small bonus.
- Clearing a stage refills some fuel and generates a fresh maze.
- Rival cars speed up from stage 3 onward.

## Controls

- `A` on the title screen: start
- D-pad: queue a turn
- Crank undocked: point the crank up/right/down/left to queue a turn
- `A` while driving: drop smoke
- `B` while driving: brake

Turns are queued and applied when the car reaches the center of an open tile, so you can hold the next direction a little early.

## Build And Run

Install the [Playdate SDK](https://play.date/dev/) and make sure `pdc` is available on your shell path.

```sh
pdc source RallyRun.pdx
```

Then open `RallyRun.pdx` in the Playdate Simulator, or sideload it onto a Playdate device.

## Project Structure

- `source/RallyRun.lua`: main game code
- `source/pdxinfo`: Playdate package metadata
- `source/images/launcher/`: launcher card, icon, and launch images
- `source/fonts/`: bitmap fonts used by the game
- `art/source-art/`: source artwork for launcher assets
- `RallyRun.pdx/`: compiled Playdate bundle

## Fonts

Rally Run uses third-party font assets that are not part of the Playdate SDK. Before building, distributing, or modifying the game, make sure you have the appropriate license for:

- [Supermini (Playdate font)](https://gingerbeardman.itch.io/supermini-playdate-font) by gingerbeardman, used by the game as `source/fonts/Supermini.fnt`.
- [Full Circle](https://www.fontspace.com/full-circle-font-f10794) by mgl23, included as `source/fonts/full-circle.fnt`. Commercial use may require a donation or commercial license from the designer.

## Package Metadata

- Name: `Rally Run`
- Author: `Mathan Games`
- Bundle ID: `com.mathan.rallyrun`
- Version: `1.0`

