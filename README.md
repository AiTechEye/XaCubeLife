# XaCubeLife VoxelGame Prototype

## Controls:

- Move: W,S,A,D  
- Jump: Space  
- Dive/Climb: Shift  
- Run: Ctrl  
- Inventory: E (Point in air or on a chest)  
- Toggle Fly: Tab  
- Content Editor: T  
- Test: §		(Generates and placing you on an island in middle of the map and gives you items)  

## Content Editor:  
- The is an ingame realtime mod editor, that let you create and modify content in in the game, while playing!  
- Every option has defaults, except the name  
- The callback button is only used to output text (easier to add to the game code content (game/game/content.gd)  

#### Node Tab:  
- Create nodes/blocks, require a name to be made.  
- Nodes with inventory is not supported in the editor.  

#### Item Tab:  
- Create items, require a name to be made.  

#### Mapgen Scatter Tab:  
- Adds orens/plants/tress/buildings... things that spawns in the game.  
- Items in the list will be chosen randomly.  
- Require a name and atleast 1 item in the list to be made.  

#### Nodeextractor Tab:  
- Mark and save Buildings, will mark every connected node, require a name to be saved.  
- So to mark a buildings makse sure it is floating and not connected to the ground, the point one of the nodes and press mark.  

#### Object Tab:  
- Empty  
