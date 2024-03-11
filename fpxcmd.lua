--fpxcmd.lua

local lfs = require("lfs")
local ini = dofile("inifile.lua")
local json = dofile("rxi_json.lua")



local fpx_dir = lfs.currentdir()
local fpx_log = "fpxcmd v1.0.3, made by Luxen De'Mark (2024)\n    operating out of " .. fpx_dir .. "\n"
print(fpx_log)

local config = {
	FateLocation = "C:\\SteamLibrary\\steamapps\\common\\FATE", --where the game is stored
	DataLocation = "C:\\ProgramData\\WildTangent\\FateSteam", --used by FatePatcher, not fpxcmd
	debug = "2", --print log levels below this are not shown (still saved to log file)
	make_json_pretty = "NO", --very slow! Makes json files human-readable by adding whitespacing
	progress_interval = "10", --update interval on pretty-formatting json
	allow_overwrite = "NO", --update will overwrite existing files, only enable for debugging!
}

local levels = {
	[1] = "DEBUG",
	[2] = "INFO",
	[3] = "WARNING",
	[4] = "ERROR",
}

local cp = function(instr, level)
	local instr = os.date() .. " [" .. tostring(levels[level or 1]) .. "] " .. tostring(instr)
	
	if (tonumber(config.debug) or 2) <= (level or 1) then
		print(instr)
	end
	
	fpx_log = fpx_log .. instr .. "\n"
end

local spickle
spickle = function(intable)
	local retstr = ""
	retstr = retstr .. "\n" .. tostring(intable) .. " {"
	for k, v in pairs(intable) do
		if type(v) == "table" then
			retstr = retstr .. "\n" .. tostring(k) .. " >> "
			if tostring(k) == "_G" or tostring(k) == "package" or tostring(k) == "iup" then
				retstr = retstr .. "\n(Nope)"
			else
				retstr = retstr .. spickle(v)
			end
		else
			retstr = retstr .. "\n" .. tostring(k) .. " >> " .. tostring(v)
		end
	end
	retstr = retstr .. "\n}"
	
	return retstr
end

if lfs.attributes("config.ini", "mode") == "file" then
	config = ini.parse("config.ini").config
	cp("Loaded config!", 2)
	cp("Configuration: " .. spickle(config), 1)
else
	cp("Config missing! Replacing with default data", 4)
	ini.save("config.ini", {config=config})
end

if config.skip_validity_check ~= "YES" then
	if lfs.attributes(config.FateLocation .. "\\fate.exe", "mode") == "file" then
		cp("Fate directory identified successfully at " .. config.FateLocation, 2)
	elseif lfs.attributes(".\\fate.exe", "mode") == "file" then
		cp("Fate directory not configured, but the active directory appears to be the game directory (yay!); applying this now!", 2)
		config.FateLocation = ".\\"
	else
		cp("Fate directory not configured properly! Either modify the directory manually in config.ini or use '-set FateLocation <path\\to\\FATE>'", 4)
	end
else
	cp("Fate directory validity check was skipped!", 3)
end

if not lfs.attributes(".\\mods", "mode") == "directory" then
    lfs.mkdir(".\\mods")
end

local function readFile(filePath)
    local file = io.open(filePath, "r")
	
    if not file then
        cp("    Unable to open file: " .. filePath, 3)
		return
    end
	
    local content = file:read("*a") --Read all
    file:close()
	
    return content
end

local function writeFile(filePath, contents)
	local file = io.open(filePath, "w")
	
	if not file then
		cp("Unable to save file: " .. filePath, 4)
		return
	end
	
	file:write(contents)
	file:close()
	cp("Wrote to " .. filePath, 1)
end

local function copyFile(source, destination)
	cp("Copying " .. source .. " to " .. destination, 1)
    local sourceFile = io.open(source, "rb")
    if not sourceFile then
        cp("    Unable to open file: " .. source, 4)
        return false, "Failed to open source file"
    end
    
    local destinationFile = io.open(destination, "wb")
    if not destinationFile then
        sourceFile:close()
        cp("    Unable to open file: " .. destination, 4)
        return false, "Failed to open destination file"
    end
    
    -- Read and write data in chunks to conserve memory
    local chunkSize = 8192 -- Adjust as needed
    while true do
        local chunk = sourceFile:read(chunkSize)
        if not chunk then break end
        if not destinationFile:write(chunk) then
            sourceFile:close()
            destinationFile:close()
			
			cp("    Unable to write data to file: " .. destination, 4)
            return false, "Failed to write to destination file"
        end
    end
    
    sourceFile:close()
    destinationFile:close()
    
    return true
end

local function copyFolder(source, destination, structure)
    -- Create the destination directory if it doesn't exist
    lfs.mkdir(destination)

    -- Initialize the structure table if not provided
    structure = structure or {files = {}}

    -- Iterate over the files and directories in the source directory
    for file in lfs.dir(source) do
        if file ~= "." and file ~= ".." then
            local sourcePath = source .. "\\" .. file
            local destinationPath = destination .. "\\" .. file

            local mode = lfs.attributes(sourcePath, "mode")

            if mode == "file" then
                -- Copy the file
				
				if (config.allow_overwrite == "YES") or (lfs.attributes(destinationPath, "mode") ~= "file") then
					cp("copying " .. sourcePath .. " " .. destinationPath, 1)
					local status, err = copyFile(sourcePath, destinationPath)
					if not status then
						cp("Error during file copy: " .. tostring(err), 4)
					end
				end
                
                -- Add the file to the structure table
                table.insert(structure.files, destinationPath)
				
            elseif mode == "directory" then
                -- Recursively copy the subdirectory
				if file == "master" or file == "mods" then
					cp("skipping directory " .. file, 1)
				else
					local subStructure = {files = {}}
					structure[file] = subStructure
					copyFolder(sourcePath, destinationPath, subStructure)
				end
            end
        end
    end

    return structure
end

local function getAllDirectories(directory)
    local directories = {}

    for entry in lfs.dir(directory) do
        local path = directory .. "\\" .. entry
        if entry ~= "." and entry ~= ".." then
            local mode = lfs.attributes(path, "mode")
            if mode == "directory" then
                table.insert(directories, entry)
            end
        end
    end

    return directories
end

local pretty_format_json_string = function(jsonString)
	cp("Formatting JSON data for readability. To improve performance, disable this in the config!", 3)
	local total_required = string.len(jsonString)
	local interval = tonumber(config.progress_interval) or 10
	local progress = 0
	local last_update = 0
	
    local indent = 0
    local formattedJson = ""

    for i = 1, total_required do
		progress = math.floor((i / total_required) * 100)
		if progress ~= last_update then
			last_update = progress
			if (progress % interval == 0) then
				cp("	formatting progress: " .. tostring(progress) .. "%", 1)
			end
		end
		
        local char = jsonString:sub(i, i)

        if char == "{" or char == "[" then
            indent = indent + 1
            formattedJson = formattedJson .. char .. "\n" .. string.rep("\t", indent)
        elseif char == "}" or char == "]" then
            indent = indent - 1
            formattedJson = formattedJson .. "\n" .. string.rep("\t", indent) .. char
        elseif char == "," then
            formattedJson = formattedJson .. char .. "\n" .. string.rep("\t", indent)
        else
            formattedJson = formattedJson .. char
        end
    end
	
	cp("Reformatting complete!", 1)

    return formattedJson
end

local save_structure = function(dir, struct)
	local modstring = json.encode(struct)
	if config.make_json_pretty == "YES" then
		modstring = pretty_format_json_string(modstring)
	end
	writeFile(dir, modstring)
end

local strip_path_from_file = function(path)
	return path:match(".+\\([^\\]+)$")
end




--The modlist tracks the user's existing mods and whether they're enabled or not

local modlist = {
	updated = os.date(),
	mods = {},
	index_table = {
		['NO_DATA'] = ".\\no_index.txt",
	},
}
--load modlist.json
if lfs.attributes("modlist.json", "mode") == "file" then
	local modstring = readFile("modlist.json")
	modlist = json.decode(modstring)
	cp("modlist loaded successfully", 2)
else
	save_structure("modlist.json", modlist)
	cp("modlist not found! Empty modlist created! Use -scan to update!", 3)
end

--The masterlist is a table representation of the game files

local masterlist = {}

if lfs.attributes(".\\master\\map.json", "mode") == "file" then
	local mlstring = readFile(".\\master\\map.json")
	masterlist = json.decode(mlstring)
	cp("Masterlist loaded successfully", 2)
else
	cp("Masterlist not found! Please run -update !", 3)
	config.make_json_pretty = "NO"
end


local argstring = ""

for _, v in ipairs(arg) do
    -- If the argument contains spaces, enclose it in double quotes
    if string.find(v, "%s") then
        v = '"' .. v .. '"'
    end
    argstring = argstring .. " " .. tostring(v)
end

--parse arg
local arg_priority = {
	['-file']	=	1, --these get skipped during the priority execution, as they're handled before then
	['-set']	=	100,
	['-remove']	=	200,
	['-update']	=	300,
	['-scan']	=	400,
	['-flag']	=	500,
	['-index']	=	700,
	['-deploy']	=	1000,
}

--read an argstring and return as an argtable {{-function1 arg1 arg2}{-function2}...}
local function parse_arguments(input)
    local arguments = {}
    local currentFunction = nil
	local inQuotes = false
	local quotedArg = ""
	
	print("")
	
    for part in input:gmatch("%S+") do
		
		cp("processing " .. part, 1)
		
		if part:sub(1, 1) == "-" then
            -- If we encounter a new function, store the previous one if exists
            if currentFunction then
                table.insert(arguments, currentFunction)
            end
            -- Start a new function
            currentFunction = {part}
        elseif currentFunction then
            -- If there's a current function, check for quoted
			if part:sub(1, 1) == '"' then
				--start quoted process
				inQuotes = true
				quotedArg = part:sub(2)
			elseif inQuotes and part:sub(-1) == '"' then
				--end quoted process and add the complete item as a single argument
				inQuotes = false
				quotedArg = quotedArg .. " " .. part:sub(1, -2)
				table.insert(currentFunction, quotedArg)
			elseif inQuotes then
				--continue quoted process
				quotedArg = quotedArg .. " " .. part
			else
				--add the non-quoted argument to it
				table.insert(currentFunction, part)
			end
        else
            -- If there's no current function, this argument is invalid
            cp("    skipping unattached argument: " .. part, 1)
        end
    end

    -- Add the last function if it exists
    if currentFunction then
        table.insert(arguments, currentFunction)
    end

    return arguments
end









local files = {}
local argtable = parse_arguments(argstring)

cp("\n\nProcessing these functions with arguments: ", 1)

local index = 0
while true do
	index = index + 1
	local func_object = argtable[index]
	if type(func_object) ~= "table" then
		break
	end
	
	cp("    " .. table.concat(func_object, " "), 1)
	
	if func_object[1] == "-file" then
		if files[func_object[2]] then
			cp("        skipped " .. func_object[2] .. "; already opened!", 1)
		else
			cp("        opening " .. func_object[2], 1)
			files[func_object[2]] = true
			
			local argstring = readFile(func_object[2])
			local new_table = parse_arguments(argstring)
			for k, v in ipairs(new_table) do
				table.insert(argtable, v)
			end
		end
	end
end



cp("\n\nOrdering based on execution priority...", 1)
local comp_priority = function(a, b)
	local priority_a = arg_priority[a[1]] or 0
	local priority_b = arg_priority[b[1]] or 0
	
	return priority_a < priority_b
end

table.sort(argtable, comp_priority)

cp("Ordering complete!", 1)

local create_lookup = function(intable)
	local lookup = {}
	for index, mod_obj in ipairs(intable) do
		lookup[mod_obj.name] = lookup[mod_obj.name] or {}
		lookup[mod_obj.name][mod_obj.version] = index
	end
	return lookup
end

local modlist_lookup = create_lookup(modlist.mods)

local find_mod = function(id, ver, lookup_table)
	if not lookup_table then
		lookup_table = modlist_lookup
	end
	
	local versions = lookup_table[id]
	if versions then
		return versions[ver]
	end
end

local err_flag = false
local queue_funcs
queue_funcs = {
	['-index'] = function(obj)
		--[[
			-index index_name "path/to/file"
			
			Files that are patchable are stored in the index table. 
			Mods can add new indexes themselves in their patch.json, or the user can specify a new index with this command.
			
			modlist.index_table {
				index = path/to/file
			}
		]]--
		local new_index = obj[2]
		local index_path = obj[3]
		cp("new index: " .. new_index .. " >> " .. index_path, 2)
		modlist.index_table[new_index] = index_path
	end,
	['-set'] = function(obj)
		--[[
			-set config value
			
			used to change a configuration value from the command line
		]]--
		local cfg = obj[2]
		local val = obj[3]
		cp("configuration: " .. cfg .. " >> " .. val, 2)
		config[cfg] = val
	end,
	['-remove'] = function()
		--[[
			-remove <no arguments>
			
			shortcut argument to disable all plugins and deploy, effectively restoring the game state to the copy in master.
		]]--
		cp("Resetting game back to master...", 2)
		for _, mod_obj in ipairs(modlist.mods) do
			mod_obj.enabled = "NO"
		end
		queue_funcs['-deploy']()
	end,
	['-update'] = function()
		--[[
			-update (no arguments)
			
			Creates a master copy of the game files, used for recovery
		]]--
		if config.master_made == "YES" then
			cp("Ignoring -master flag; use '-set master_made NO' to reset this", 1)
			return
		end
		
		cp("creating master copy...", 2)
		if lfs.attributes(config.FateLocation .. "\\fate.exe", "mode") ~= "file" then
			cp("Game location not configured!", 4)
			err_flag = true
			return
		end
		
		local master_struct = copyFolder(config.FateLocation, ".\\master")
		save_structure(".\\master\\map.json", master_struct)
		
		config.master_made = "YES"
	end,
	['-scan'] = function()
		--[[
			-scan (no arguments)
			
			updates the list of games. 
			-set external_manager YES if mods are managed by vortex
		]]--
		cp("scanning the \\mods directory...", 2)
		local dirs = getAllDirectories(".\\mods")
		
		local patch_files = {}
		for _, mod_dir in ipairs(dirs) do
			if lfs.attributes("mods\\" .. mod_dir .. "\\patch.json", "mode") == "file" then
				table.insert(patch_files, "mods\\" .. mod_dir)
				cp("	Found a mod at " .. mod_dir, 2)
			end
		end
		
		local new_modlist = {
			updated = os.date(),
			mods = {
				--[[
					[1] = {
						folder = patch
						name = mod name
						version = mod version
						enabled = "YES" or "NO"
					},
				]]--
			},
			index_table = {
				--base indexes used for patch files
				ITEMS = "ITEMS\\items.dat",
				ITEMS_US = "ITEMS\\en-US\\items.dat",
				ITEMS_UK = "ITEMS\\en-UK\\items.dat",
				ITEMS_DE = "ITEMS\\de\\items.dat",
				ITEMS_ES = "ITEMS\\es\\items.dat",
				ITEMS_FR = "ITEMS\\fr\\items.dat",
				ITEMS_IT = "ITEMS\\it\\items.dat",
				
				MONSTERS = "MONSTERS\\monsters.dat",
				MONSTERS_US = "MONSTERS\\en-US\\monsters.dat",
				MONSTERS_UK = "MONSTERS\\en-UK\\monsters.dat",
				MONSTERS_DE = "MONSTERS\\de\\monsters.dat",
				MONSTERS_ES = "MONSTERS\\es\\monsters.dat",
				MONSTERS_FR = "MONSTERS\\fr\\monsters.dat",
				MONSTERS_IT = "MONSTERS\\it\\monsters.dat",
				
				NAME_PREFIX = "NAMES\\prefix.dat",
				NAME_PREFIX2 = "NAMES\\prefix2.dat",
				NAME_SUFFIX = "NAMES\\suffix.dat",
				NAME_SUFFIX2 = "NAMES\\suffix2.dat",
				NAME_TITLE = "NAMES\\title.dat",
				
				NAME_PREFIX_US = "NAMES\\en-US\\prefix.dat",
				NAME_PREFIX2_US = "NAMES\\en-US\\prefix2.dat",
				NAME_SUFFIX_US = "NAMES\\en-US\\suffix.dat",
				NAME_SUFFIX2_US = "NAMES\\en-US\\suffix2.dat",
				NAME_TITLE_US = "NAMES\\en-US\\title.dat",
				
				NAME_PREFIX_UK = "NAMES\\en-UK\\prefix.dat",
				NAME_PREFIX2_UK = "NAMES\\en-UK\\prefix2.dat",
				NAME_SUFFIX_UK = "NAMES\\en-UK\\suffix.dat",
				NAME_SUFFIX2_UK = "NAMES\\en-UK\\suffix2.dat",
				NAME_TITLE_UK = "NAMES\\en-UK\\title.dat",
				
				NAME_PREFIX_DE = "NAMES\\de\\prefix.dat",
				NAME_PREFIX2_DE = "NAMES\\de\\prefix2.dat",
				NAME_SUFFIX_DE = "NAMES\\de\\suffix.dat",
				NAME_SUFFIX2_DE = "NAMES\\de\\suffix2.dat",
				NAME_TITLE_DE = "NAMES\\de\\title.dat",

				NAME_PREFIX_ES = "NAMES\\es\\prefix.dat",
				NAME_PREFIX2_ES = "NAMES\\es\\prefix2.dat",
				NAME_SUFFIX_ES = "NAMES\\es\\suffix.dat",
				NAME_SUFFIX2_ES = "NAMES\\es\\suffix2.dat",
				NAME_TITLE_ES = "NAMES\\es\\title.dat",

				NAME_PREFIX_FR = "NAMES\\fr\\prefix.dat",
				NAME_PREFIX2_FR = "NAMES\\fr\\prefix2.dat",
				NAME_SUFFIX_FR = "NAMES\\fr\\suffix.dat",
				NAME_SUFFIX2_FR = "NAMES\\fr\\suffix2.dat",
				NAME_TITLE_FR = "NAMES\\fr\\title.dat",

				NAME_PREFIX_IT = "NAMES\\it\\prefix.dat",
				NAME_PREFIX2_IT = "NAMES\\it\\prefix2.dat",
				NAME_SUFFIX_IT = "NAMES\\it\\suffix.dat",
				NAME_SUFFIX2_IT = "NAMES\\it\\suffix2.dat",
				NAME_TITLE_IT = "NAMES\\it\\title.dat",
				
				PARTICLES = "PARTICLES\\particles.dat",
				GLOWS = "PARTICLES\\glows.dat",
				
				QUESTS = "QUESTS\\quests.dat",
				QUESTS_US = "QUESTS\\en-US\\quests.dat",
				QUESTS_UK = "QUESTS\\en-UK\\quests.dat",
				QUESTS_DE = "QUESTS\\de\\quests.dat",
				QUESTS_ES = "QUESTS\\es\\quests.dat",
				QUESTS_FR = "QUESTS\\fr\\quests.dat",
				QUESTS_IT = "QUESTS\\it\\quests.dat",
				
				SPELLS = "SPELLS\\spells.dat",
				SPELLS_US = "SPELLS\\en-US\\spells.dat",
				SPELLS_UK = "SPELLS\\en-UK\\spells.dat",
				SPELLS_DE = "SPELLS\\de\\spells.dat",
				SPELLS_ES = "SPELLS\\es\\spells.dat",
				SPELLS_FR = "SPELLS\\fr\\spells.dat",
				SPELLS_IT = "SPELLS\\it\\spells.dat",
			},
		}
		
		for _, folder in ipairs(patch_files) do
			local patch = folder .. "\\patch.json"
			local json_data = readFile(patch)
			local patch_data = json.decode(json_data)
			
			local mod_name = patch_data.name
			local mod_version = patch_data.version
			
			--find in current modlist, get current state
			local state = config.external_manager or "NO"
			local index = find_mod(mod_name, mod_version)
			if index then
				state = modlist.mods[index].enabled
			end
			
			local mod_data = {
				folder = folder,
				patch = patch,
				name = mod_name,
				version = mod_version,
				enabled = state,
			}
			
			table.insert(new_modlist.mods, mod_data)
		end
		
		local new_modlist_lookup = create_lookup(new_modlist.mods)
		
		cp("New modlist has been generated!", 2)
		modlist = new_modlist
		modlist_lookup = new_modlist_lookup
	end,
	['-flag'] = function(obj)
		local modname = obj[2]
		local modversion = obj[3]
		local new_status = obj[4]
		cp("Changing status of " .. modname .. " v" .. modversion .. " to " .. new_status, 2)
		local index = find_mod(modname, modversion)
		if index then
			modlist.mods[index].enabled = new_status
		else
			cp("Mod " .. modname .. " v" .. modversion .. " not found!", 3)
		end
	end,
	['-deploy'] = function()
		cp("building lists defining the current state", 2)
		
		local copy_list = {
			--[[
			destination_file = mod_source_file,
			...
			
			only the last edited files are stored.
			]]--
		}
		
		local patch_list = {
			--[[
			file_to_patch = {
				mod_file,
				mod_file,
				mod_file,
			},
			...
			series of patches applied to singular file
			]]--
		}
		
		for _, mod_obj in ipairs(modlist.mods) do
			if mod_obj.enabled == "YES" then
				cp("Fetching mod " .. mod_obj.name .. " v" .. mod_obj.version, 1)
				local mod_folder = mod_obj.folder
				local patch_str = readFile(mod_obj.patch)
				local patch_data = json.decode(patch_str)
				
				for new_index, file_to_index in pairs(patch_data.index or {}) do
					if not modlist.index_table[new_index] then
						cp("	Mod creating index " .. new_index .. " to file " .. file_to_index, 1)
						modlist.index_table[new_index] = file_to_index
					end
				end
				
				for _, folder_table in ipairs(patch_data.copy or {}) do
					local destination_folder = folder_table.folder .. "\\"
					for _, outfile in ipairs(folder_table.content) do
						copy_list[destination_folder .. (strip_path_from_file(outfile) or outfile)] = mod_folder .. "\\" .. outfile
					end
				end
				
				for _, ap_table in ipairs(patch_data.patch or {}) do
					local destination_file = ap_table.container
					patch_list[destination_file] = patch_list[destination_file] or {}
					for _, ap_content in ipairs(ap_table.content) do
						table.insert(patch_list[destination_file], mod_folder .. "\\" .. ap_content)
					end
				end
			end
		end
		
		cp("mod data collated; identifying reversions...", 1)
		
		--we have lists that tell what need to be done, but old files need to be identified and reverted. first, all indexed files not already in patch are added to it. these ensure untouched files are restored.
		
		for index, index_file in pairs(modlist.index_table) do
			patch_list[index] = patch_list[index] or {}
		end
		
		--get last_edited file list to find files to revert/remove
		local efstring = readFile(".\\master\\edited.json") or "{}"
		local edited_files = json.decode(efstring)
		
		--compare to copy_list's keys to find files we need to revert/remove
		for changed_file, source in pairs(edited_files) do
			if source ~= "REMOVE" then
				copy_list[changed_file] = copy_list[changed_file] or "REMOVE"
			end
		end
		
		save_structure(".\\master\\edited.json", copy_list)
		save_structure(".\\master\\patched.json", patch_list)
		
		--all files are accounted for. time to begin application.
		--[[
			copy_list - files to add/replace
			patch_list - files to directly edit
		]]--
		
		cp("Copy step: Adding new asset files to the game", 1)
		
		for destination_file, source_file in pairs(copy_list) do
			local skip_this_file = false
			if source_file == "REMOVE" then
				local master_ver_exists = lfs.attributes(".\\master\\" .. destination_file, "mode") == "file"
				if master_ver_exists then
					source_file = ".\\master\\" .. destination_file
				else
					cp("DELETE " .. destination_file, 2)
					os.remove(config.FateLocation .. "\\" .. destination_file)
					skip_this_file = true
				end
			end
			if not skip_this_file then
				cp("COPY " .. source_file .. " to " .. destination_file, 2)
				copyFile(".\\" .. source_file, config.FateLocation .. "\\" .. destination_file)
			end
		end
		
		cp("Patch step: Adding additional content to existing data files", 1)
		
		for destination_index, patch_table in pairs(patch_list) do
			cp("PATCH " .. destination_index, 2)
			local destination_file = modlist.index_table[destination_index] or "no_index.txt"
			local open_file = readFile(".\\master\\" .. destination_file) or ""
			
			for _, patch_to_apply in ipairs(patch_table) do
				cp("	+" .. patch_to_apply, 2)
				local patch_data = readFile(patch_to_apply)
				open_file = open_file .. "\n\n" .. patch_data
			end
			
			writeFile(config.FateLocation .. "\\" .. destination_file, open_file)
		end
		
		cp("Deployment Complete!", 1)
	end,
}

for index, func_object in ipairs(argtable) do
	if queue_funcs[func_object[1]] then
		queue_funcs[func_object[1]](func_object)
		if err_flag then
			break
		end
	end
end



cp("Execution has completed! Saving application data...", 2)

--save the configuration in case of changes
ini.save("config.ini", {config=config})

--save the modlist
save_structure("modlist.json", modlist)

--save the message log for debugging
writeFile("errors.log", fpx_log)

return err_flag or 0