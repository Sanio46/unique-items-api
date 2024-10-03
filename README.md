# Unique Items API

Many "Unique Item" mods on the workshop follow a poorly managed basis for their code, leading to the same common issues and the lack of modded character compatibility unless explicitely added by the mod creator. This API aims to solve that issue.

## Features
- For any character, make a unique sprite for any item, familiar, or knife per character
- Unique collcetible sprites update to the first alive player, whlie familiars and knives look to the player that owns them
- Modded character support that can be added by anyone
- Many API functions for just about anything you'd need for modding purposes
- Dynamic Mod Config Menu support. For each character you can choose between multiple of the same mod, disable it, or even randomize between multiple per run
- Sprites are automatically updated to always continue matching your current character and their settings
- Save data powered by [IsaacSaveManager](https://github.com/catinsurance/IsaacSaveManager) for a flawless experience in saving your ModConfigMenu settings, even after uninstalling/reinstalling mods!
