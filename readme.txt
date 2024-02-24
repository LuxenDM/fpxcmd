FatePatcher is a utility meant to allow automated piecemeal modding of Fate. Mods provide a series of files that are individual item patches, and FatePatcher parses these and adds them to the game.

fpxcmd.exe: This is a command-line utility providing the core functionality of FatePatcher.

FatePatcher.exe: This is the GUI frontend that allows users to manage their mods in Fate. Optional if using a manager like vortex. It also just doesn't exist yet...

fpxrun.bat: This is a windows bat file that will launch fpxcmd with a specific set of arguments, deploying all of your installed mods. This is a temporary solution until FatePatcher and/or Vortex integration is finished.

INSTALLATION
==================================================================
Place fpxcmd, fpxrun, and FatePatcher in the game folder next to fate.exe
Create a folder called "mods" in the game folder.

ADDING MODS
==================================================================
To add patch-type mods to fate, place them in their own folder within /mods.

For instance, to add the "MorePotions" mod, you would drag the MorePotions mod folder into the /mods/ folder.
All mods are expected to only be 1 folder deep in the mods directory. If you open /mods/<your mod here>/ then you should see a patch.json file. This is the file that fpxcmd looks for.

Once your mods are added, use a mod manager or manually configure them with fpxcmd. Alternatively, you can use fpxrun to deploy all mods with the base configuration.



-------------------------------------------------------------------
- Please refer to fpxcmd's own readme. Look for fpxcmd_readme.txt -
-------------------------------------------------------------------