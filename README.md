# Hero Game Dungeon

Godot 4.7 prototype. Press **F5** to open `Test_level`.

- **Move:** click a destination, or hold the left mouse button to follow the cursor. Release after holding to stop.
- **Battle:** approach an enemy and press **E**, or click the enemy to approach and engage. Obstacles block movement and interaction.
- **D6 combat:** one roll and up to two rerolls per round. Select an enemy card, keep the result, use it once, then end the turn. Faces provide attack, temporary block, or healing. Each surviving enemy attacks, sharing the hero's block pool.
- **Encounters:** `enemy.tscn` starts a duel; the golden `enemy2.tscn` starts a fight against three raiders. Both appear in `Test_level`. Adjust **Encounter Size**, **Max Health**, and **Attack Damage** in the Inspector to configure an encounter.
- **Return:** win, lose, or retreat to resume the same level and position. Victory removes the defeated enemy. Each battle starts at full health.

`scenes/battle.tscn` contains the battle UI, `scripts/combat/battle_state.gd` contains its rules, and `assets/prototype` contains reusable collision props.

Run combat checks with `godot --headless --path . --fixed-fps 60 --script res://tests/test_combat.gd`.

