# Gemini

A standalone bot manager addon for the WoW Forever 1.60.1 / interface 16001 client and the `C` API registered by grid.dll.

The manager has an opaque, draggable window with five pages:

- **Overview:** API availability, player/map state, real mesh-load percentage, active region and session controls.
- **Objects:** alternating spreadsheet rows with type, name, health, position, distance and GUID. Search, filter by type, page through every object, inspect fields and route to a selected object's position.
- **Navigation:** configure a mesh index, pick terrain, enter client XYZ, draw a route, steer, pause, queue destinations and save named routes.
- **Settings:** turn duration, arrival radius, object refresh rate, camera estimate, world drawing, Ctrl+click and water traversal.
- **Activity:** bounded session log with visible API and movement errors.

## Install

Download the `Gemini-1.0.0.zip` release asset and extract its **Gemini** folder into the client's `Interface/AddOns` folder. The resulting file must be `Interface/AddOns/Gemini/Gemini.toc`, with no extra nested Gemini folder.

From a source checkout on this machine:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Install.ps1
```

For another client location, pass `-GameRoot 'D:\Games\World of Warcraft\_forever_'`.

Reload the game UI with `/reload`, enable Gemini in the addon list, load the current grid.dll and run `/gemini`.

```lua
/run print(type(C), C and type(C.Objects), C and type(C.NavStatus))
```

Expected: `table function function`. Gemini can load before grid.dll and will reconnect when the API appears. It does not inject the DLL.

## Navigate

1. Open **Navigation**. The mesh path is filled from `C.NavStatus().index` if available. Enter the full path to `world.wnavindex` and press **Load index**. Existing default packages live in `%LOCALAPPDATA%\vega\navmeshes`. The DLL chooses a region using the player's map and position; Overview displays the DLL's actual loading percentage.
2. Press **Pick terrain (3s)**. Gemini hides the window and samples the cursor after three seconds. Aim at a nearby walkable surface. **Cancel** or **Ctrl+Alt** cancels. Alternatively **Ctrl+left-click** the world to pick immediately. Picking also requests a route. Entering XYZ requires **Find route**.
3. Inspect the top-down route. Teal lines show the planned path; the gold marker is your player. The world overlay projects the same route through the active camera.
4. Press **Steer**. Gemini aligns before starting forward movement, follows waypoints, and releases its movement inputs on arrival. The default full turn takes two seconds. **Pause** retains the route; **Steer** resumes it. **Stop**, **Ctrl+Alt**, closing the window, death, world exit, a map/mesh change, a long frame stall or lack of progress releases movement.
5. **Queue stop** adds the current destination to the pending itinerary. Find/steer the current route first; queued stops follow it. **Save** stores the queue (or the current destination when the queue is empty) under the entered name. **Load** restores the itinerary and plans its first leg, without starting movement. **Next name** cycles saved routes. Routes and settings persist in `GeminiDB`; running movement does not.

Every protected movement call attempts `C.ClearTaint()` immediately beforehand. Start calls are rejected if clearing fails. Stop calls are still attempted so an unavailable bridge does not prevent input release. A rejected stop is retried by the addon driver.

## Camera and traversal limits

The addon supports a client commentator camera when available and an optional `Gemini.CameraProvider()` returning `{x,y,z,yaw,pitch,fov}`. Provider angles use radians and **grid's projection convention**, whose horizontal forward vector is `(-sin(yaw), cos(yaw))`.

In normal follow-camera play, the client may expose no exact rendered camera transform. Gemini then labels its camera **Estimated follow camera**, using player facing, zoom and the Settings pitch/FOV/height. Re-center the camera behind the player before picking. Free camera orbit, pitch changes and inaccurate FOV make picks and world drawings approximate. The top-down route is independent of that estimate. Terrain picking targets the active walkable navmesh, not arbitrary scene geometry.

Steering uses client X/Y headings `(cos(facing), sin(facing))`. The estimate converts these headings to the existing grid projection convention. The former addon used a quarter-turn-offset heading for movement; this rebuild separates the two conventions.

The default route filter allows ground and doors (flags `5`); optional water adds swimming (flags `7`). The addon does not activate doors, jump links or portals. If a door or obstacle prevents progress, it stops with a diagnostic. Native mesh files and grid.dll are separate dependencies and are not included in this repository or ZIP.

## Development and packaging

Files are split by concern: `Core.lua`, `Bridge.lua`, `Objects.lua`, `Navigation.lua`, `Steering.lua`, `Drawing.lua`, `UI.lua`, `Main.lua`. The `.toc` defines their order.

Run with a Lua 5.1 interpreter:

```text
lua5.1 tests/run.lua
```

On Windows with the sibling Vega checkout and VS 2026 v145 tools:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Test.ps1
powershell -ExecutionPolicy Bypass -File scripts/Package.ps1
```

The tests load all addon files into a strict mock of the WoW UI and grid APIs. They exercise startup, missing/late APIs, mesh progress, route errors, scaled cursor coordinates, timed/Ctrl-click picking, heading/turn timing, per-call taint clearing, emergency/error stops, stuck detection, itinerary persistence, object pagination/filtering and world exit. They do not replace live client tests or prove native grid stability.

The Windows test runner links the same Lua 5.1 library as grid.dll. `scripts/Test.ps1` also accepts `-LuaExecutable` to use another Lua 5.1 interpreter. CI runs the suite on stock Lua 5.1 and packages the addon.
