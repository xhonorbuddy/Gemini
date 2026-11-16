GEMINI 1.0.0

Place this Gemini folder in Interface/AddOns. Reload the UI and run /gemini.
Requires the current grid.dll C API and separately installed .wnav mesh packages.

Navigation: load world.wnavindex, pick terrain or enter XYZ, Find route, Steer.
The terrain button samples the cursor after three seconds. Ctrl+left-click
terrain picks immediately. Ctrl+Alt stops movement or cancels a pending pick.
Close the manager, Pause, or Stop to release its movement inputs.

Objects: searchable, paged spreadsheet and full-field inspector.
Settings and named destination itineraries persist between sessions.

The normal camera fallback is estimated. Re-center behind your player before
picking and adjust pitch/FOV in Settings. The top-down route remains exact.
Steering does not activate doors, jump links or portals.
