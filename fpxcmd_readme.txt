fpxcmd is the core CLI utility for modding FATE. Follow installation instructions found in the FatePatcher general readme.

Terms:
================================================================================
Master: A saved copy of your game, used when determining files that need to be patched, changed, or restored.

index: Files that can be edited are referenced by a unique name, and are stored in the "file index". 



Command line USAGE:
================================================================================
These are arguments you provide in the command line when calling fpxcmd. individual functions are prepended with a -. Commands are processed based on the function priority, and then from first to last. This ensures configuration changes are processed before application deployment.

-file <path\to\file.txt>
	Process the provided text file as a list of arguments.
	
-set <configuration option> <value>
	Changes fpxcmd configuration
	
-remove
	disables all installed mods and deploys immediately. This should revert FATE back to the original state when fpxcmd first ran.
	
-update
	Creates a referencial backup of FATE's game files in /master. This is used when determining what files are needed during the deployment process. fpxcmd requires this command is run at least once.
	
-scan
	Search the /mods folder for mods and rebuild the modlist. Use after adding new mods or removing any. Any new mods found are disabled by default unless "external_manager=YES" in the configuration.
	
-flagall <YES or NO>
	changes the 'enabled' state of all mods. Only mods that are enabled are deployed.
	
-flag <mod name> <mod version> <YES or NO>
	changes the 'enabled' state of the specified mod. Only enabled mods are deployed. 
	
-index <name> <path\to\file>
	Adds a new file to the patching index. Mods can automatically do this, but cannot overwrite existing indexes. Use this command to overwrite. Usually not needed.
	
-deploy
	Build a list of files to be copied and patched, then do these actions. Will restore files no longer being modded based on the master.
	
	
	
configuration
================================================================================
These are values stored and used in config.ini

progress_interval: Frequency of message updates during json reformatting.

FateLocation: path to the FATE game installation. Must be set for fpxcmd to work correctly! If fpxcmd is installed into the game directory itself, it will automatically set this. Otherwise, the user must manually configure the game's location.

DataLocation: path to the FATE save data directory. Not used by fpxcmd.

make_json_pretty: Makes the json files human-legible by adding whitespace. Takes a long time to process; turn off to make fpxcmd a LOT faster.

allow_overwrite: Turn on if you need to re-run -update for some reason. This will destroy your old copy of the game in /master.

master_made: Tracks if the master copy has been made. Also needs to be set to "NO" if you want to re-run -update.

debug: A number 1-4, related to message filtering. default is 2. Messages with a lower priority than this number are hidden in the command line interface (they still appear in errors.log)

external_manager: YES or NO, set YES if you are using vortex or another mod manager to handle your mods, or simply want to default new mods to an enabled state.



modlist.json
================================================================================
Created by the -scan command, this stores all known mods and their current state. It will also store all current file indexes, used by the patching process. This file is stored with fpxcmd.



edited.json
================================================================================
Created during -deploy, this is a list of all files that were added or edited by the COPY process or the similar SEQCOPY process. This file is used to revert changes when a file is no longer being modified. This file is stored in the \master folder.



patched.json
================================================================================
Created during -deploy, this is a list of all indexed files and the files that are patching them. This file is stored in the \master folder.