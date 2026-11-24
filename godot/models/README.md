# Model slots

Drop a Blender export (`.glb`, glTF Binary) in this folder under one of these names and it
replaces the placeholder shape the next time you press Play. Nothing else needs changing.

| File             | Replaces                                  | Placed at                          |
|------------------|-------------------------------------------|------------------------------------|
| `house.glb`      | each of the six houses' walls and roof    | the house's ground centre          |
| `lighthouse.glb` | the lighthouse tower                      | its base on the eastern point      |
| `dock.glb`       | the wooden dock and its T-end             | (3.5, 0, 6), the middle of the dock |
| `boat.glb`       | the rowboat moored by the dock (it bobs)  | the boat's waterline centre        |
| `stall.glb`      | the market stall on the quay              | the stall's ground centre          |
| `lamp.glb`       | every street lamp post (the light stays)  | the foot of the post               |
| `tree.glb`       | the pixel-sprite trees behind the town    | the foot of the trunk              |

## Exporting from Blender

- **Scale:** 1 Blender unit = 1 metre. The fisher is about 1.6 m tall and the textures run
  at 16 pixels per metre, so a 64 px texture covers 4 m.
- **Facing:** the camera looks north (Blender's +Y into the screen, since Godot's -Z is
  Blender's +Y). Put a house's front door on Blender's **-Y** side so it faces the camera.
- **Origin:** at ground level, in the middle of the footprint (the foot of the post for a
  lamp, the waterline centre for the boat).
- **Export:** File > Export > glTF 2.0, Format **glTF Binary (.glb)**, +Y Up on, and
  Apply Modifiers on.
- **Pixel-art textures:** after the first import, select the `.glb` in Godot's FileSystem
  dock, open the Import tab and set the textures' filter to **Nearest**, so they stay crisp.

## Collisions

Houses and the lighthouse already get a collision box from the game, so you only need
visual meshes for those. The **dock** is walked on, so give it a collider: in Blender,
add a simple box mesh over the walkable deck and end its name with `-col` (for example
`deck-col`). Godot turns any mesh ending in `-col` into a static collider when it imports.
