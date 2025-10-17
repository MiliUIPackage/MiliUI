AutoMark
========

AutoMark is designed so that it can be used out of the box.

The following information can be used to add additional NPCs and/or modify existing entries if required.


Custom NPCs and Overrides
=========================

Additional NPCs can be added and default NPCs can be overridden.

Entries are stored in the addon's Saved Variables file and will not be overwritten when the addon is updated.

Open the Configuration window (Shift-click the minimap icon or type /automark).

Select the "NPCs" tab.


Adding Custom NPCs
------------------
To add a new Custom NPC, click on the ID drop-down and select "New NPC".

Enter the NPC ID. (If an existing default NPC exists, an Override will be created. See Modifying Default NPCs below.)

Set the Instance, Name and required marking options.

If you are in an instance and have an NPC targeted when you add the NPC, the ID, Instance and Name will be set automatically.


Modifying Default NPCs
----------------------
To modify an existing default NPC, select it from the ID drop-down.

Modify the marking options and click "Update". This creates an Override for the NPC.

To disable marking for an NPC, set the Auto field to "Never".


Adding Custom Instances
=======================

If you want to create entries for an instance which is not already used in the addon, select the "Instances" tab.

Click on the ID drop-down and select "New Instance".

Enter the Instance ID and then update the entry with the correct Instance Name and Type.

If you are in the instance the ID and Name will be set automatically.


Notes
=====
NPC and Instance IDs are used for marking. The Names are for reference only.

The Marks field allows up to 8 marks to be entered. Avoid using marks reserved for party members (tank/healer).

Select "Standard" and leave the Marks field blank to use the list of default marks.
Select the "Marks" tab to change the list of default marks.

Click the "Save" button to save the changes.

When changes are pending you must either Save or Cancel them before you can select another ID.

The "Remove" button can be used to remove a Custom NPC or an Override.
A confirmation dialog is shown.
This will not remove the addon's default entry for the NPC.

Entries are color coded as follows:

Default		Green

Override	Blue
			Light Blue if marking disabled.
			Purple if Override has same settings as Default entry.
			
Custom		White
			Gray if marking disabled.
