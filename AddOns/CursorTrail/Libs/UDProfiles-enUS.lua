-- ENGLISH (U.S.) --
local kAddonFolderName, private = ...
assert(private.L == nil)  -- Must include this file before other localization files!
private.L = {}
local L = private.L
--[[===========================================================================
CHANGE HISTORY:
    Sep 25, 2024
        - Added L.mUndo, L.UndoDesc .
=============================================================================]]

--''''''''''''''
-- Menu Strings
--''''''''''''''
L.mNewProfile = "New Profile"
L.mLoad = "Load ..."
L.mDefaults = DEFAULTS .." ..."
L.mSave = SAVE
L.mSaveAs = "Save As"
L.mRename = "Rename"
L.mCopyTo = "Copy To ..."
L.mCopyFrom = "Copy From ..."
L.mDelete = DELETE .." ..."
----L.mBackups = "Backups ..."
L.mBackup     = "Backup"
L.mRestore     = "Restore ..."
L.mExport = "Export ..."
L.mImport = "Import"
L.mOptions = "Profile Options"
L.mUndo = "Undo"

--''''''''''''''
-- Misc Strings
--''''''''''''''
L.HeadingPadChar = ":"  -- e.g. ":::::::::: SAVE PROFILE ::::::::::"
L.UnsavedMarker = " *"  -- Characters added to end of a profile name to indicate its not saved yet.
L.EmptyNameText = "Profile Name"
L.Menu = " Menu"  -- (Leading space helps center this word in the control better.)
L.NoUndo = NO .." / Undo"
L.CreateProfile = "Create Profile"
L.DeleteProfile = "Delete Profile"
L.NewBackup  = "+ New Backup +"
L.BackupProfiles = "Backup Profiles"
L.RestoreBackup = "Restore Backup"
L.DeleteBackup = "Delete Backup"
L.BackupName_Prefix = "Backup_"
L.BackupName_Login = "@Login"  -- Must start with "@".
L.BackupName_Orig = "@Original"    -- Must start with "@".
L.Profiles = "Profiles"  -- Upper-case!
L.profiles = "profiles"  -- Lower-case!
L.current_values = "current values"  -- Lower-case!
L.loaded = "loaded"  -- A lower-case word meaning the profile is loaded.
L.modified = "modified"  -- A lower-case word meaning the profile is modified.
L.NewProfileDesc = "Create a new profile using default values."
L.UndoDesc = "Undo all changes to current profile."
L.BackupDesc = "Create a new backup of current profiles."
----L.BackupsDesc = "Create/restore backups of current profiles."
L.RestoreDesc = "Replace current profiles with backed up profiles."

L.Disabled_NoProfiles = "No profiles exist."
L.Disabled_NoBackups = "No backups exist."
L.Disabled_NameIsBlank = "Disabled because profile name is blank."
L.Disabled_Unsaved = "Disabled because profile not saved."
L.Disabled_NotImplemented = "Not implemented yet."

L.SaveProfileFirst = "Save profile first !"
L.MousewheelSwitchesProfiles = "TIP: Mouse wheel switches profiles."
----L.RightclickToSaveProfile = "TIP: Right-click to save profile."
L.SaveProfileHelp = 'Right-click profile name, or\nselect "'.. L.mSaveAs ..'" from '.. L.Menu ..'.'
L.ProfileNotSaved = "*Profile not saved."
L.TopOfList = "At top of list."
L.BottomOfList = "At bottom of list."
L.NewProfileName = "New profile name:"
L.SaveProfileAs = 'Save profile "%s" as:'
L.RenameProfileTo = 'Rename profile "%s" to:'
L.NewBackupName = "New backup name:"
L.AreYouSure = "Are you sure?"
L.SaveChangesFirst = 'Save changes to "%s" first?'
L.SaveBeforeLoading = 'Save "%s" before loading "%s"?'
L.ResetOptionsDesc = "Reset Profile Options"
L.ResetOptionsSucceeded = "Profile options reset."

L.ConfirmOverwriteProfile = 'Profile "%s" already exists!\n\nIt will be replaced with current values.'
L.ConfirmDefaults = 'Profile "%s" already exists!\n\nIt will be replaced with default values.'
L.ConfirmBackup = 'Backup "%s" already exists!\n\nIt will be replaced if you continue.'
L.ConfirmRestore = 'Restore "%s" ?\n\nCurrent profiles will be replaced if you continue.'
L.ConfirmCopyTo = 'Profile "%s" will be overwritten with values from "%s".'
L.ConfirmCopyFrom = 'Profile "%s" will be copied to "%s".'
L.ConfirmKeepChanges = "Keep changes to Profiles?"
L.ConfirmDeleteProfile = L.AreYouSure ..'\n\nProfile "%s" will be deleted.'
L.ConfirmDeleteBackup = L.AreYouSure ..'\n\n"%s"\nwill be permanently removed if you continue!'
L.ConfirmResetOptions = "Reset profile options to their original values?"

L.ProfilesVersion = "Profiles Version: "
L.ControlsVersion = "Controls Version: "
L.InvalidProfileName = "Invalid profile name."
L.NameExceedsMaxLetters = "Name exceeds %d letters."
L.CanceledProfileChanges = "Canceled profile changes."

L.Title_Load = "LOAD"
L.Title_ProfilesChanged = "PROFILES CHANGED"
L.Title_BackupProfiles = "BACKUP PROFILES"
L.Title_RestoreProfiles = "RESTORE PROFILES"
L.Title_Warning = "WARNING"

L.DefaultLoaded = 'Default loaded: "%s"'  -- %s = name of a default
L.DefaultsLoaded = "Defaults loaded."
L.Created = 'Created "%s".'
L.FailedToCreate = 'FAILED to create "%s".'
L.Saved = 'Saved "%s".'
L.FailedToSave = 'FAILED to save "%s".'
L.Loaded = 'Loaded "%s".'
L.FailedToLoad = 'FAILED to load "%s".'
L.Deleted = 'Deleted "%s".'
L.FailedToDelete = 'FAILED to delete "%s".'
L.RenamedOldToNew = 'Renamed "%s" to "%s".'  -- %s %s = old name, new name
L.FailedToRename = 'FAILED to rename "%s".'
L.CopiedSrcToDest = 'Copied "%s" to "%s".'  -- %s %s = source name, destination name
L.CreatedBackup = 'Created backup "%s".'
L.FailedToCreateBackup = "FAILED to backup profiles!"
L.Restored = 'Restored backup "%s".'
L.FailedToRestore = 'FAILED to restore "%s".'
L.DeletedBackup = 'Deleted backup "%s".'
L.FailedToDeleteBackup = 'FAILED to delete "%s".'
L.NotAllowToDelete = 'Not allowed to delete "%s".'
L.UnsavedChangesBackupWarning = "The backup was successful, but unsaved settings in the current profile were not backed up."

L.OptionSaveOnOkay = "Save profile when Okay button is clicked."
L.OptionConfirmDelete = "Ask before deleting profiles."
L.OptionConfirmCopy = "Ask before copying profiles."
L.OptionAccountProfile = "Use same profile for all characters."
L.AccountProfileIconDesc = "Using this profile for all characters."

L.ProfilesHelp = [[
- To create a new profile, select "New Profile" from Menu.

- An asterisk (*) at the end of the active profile name indicates the displayed values have been modified, but those changes have not be saved to the profile yet.

- Unsaved profile changes can be undone by selecting the same profile name from the Load dropdown list.

- To save changes to the active profile, right-click the profile name, or select "Save As" from Menu.

- Clicking the Okay button keeps any changes to displayed values, but does not save those changes to the active profile.  This allows trying different addon settings while still being able to undo those changes later.
To change this behavior, select "Profile Options" from Menu, and turn on "Save profile when Okay button is clicked".

- When selecting a default profile, its name will not appear in the Load dropdown list unless it is saved first.

- While hovering over the profile name, the mouse wheel can be used to load the next/previous profile.

- While the Load dropdown list is open ...
      Holding Shift while clicking a name keeps the list open.
      Holding Shift while using the mouse wheel loads the next/previous profile.

- The small arrows next to the [X] button cycle through profiles in the Load and Defaults dropdown lists.
]]

L.BackupsHelp = [[
- You can backup or restore all your profiles from the main window by selecting "Backup" or "Restore" from Menu.

- Two backups will always be available to restore from:
      @Original - Contains profiles that existed the very first time the profiles UI was used.
      @Login - Contains profiles that existed the last time you logged into the game.

- Old backups can be deleted by selecting "Restore" from Menu, and then clicking the red "X" icon along the right side of the name you want to delete.
]]

--- End of File ---
