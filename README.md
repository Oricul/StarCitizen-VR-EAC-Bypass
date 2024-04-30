# StarCitizen VR EAC Bypass

This is a bypass for EAC in StarCitizen that prevents VR usage.

## Required Software
* [StarCitizen](https://robertsspaceindustries.com/enlist?referral=STAR-4N3T-JYVF) _(Launcher and installed branch(es).)_
* [VorpX](https://www.vorpx.com/) _(Make sure you've ran this at least once and registered.)_
* [PowerShell 5+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

## How-To
1. Save StarCitizen_EnableVR.ps1 into a folder somewhere (it will create files, so make sure it lives by itself).
2. _(Not necessary, but makes life easier)._ Create a shortcut to the script on your desktop.
3. _(This step will change soon!)_ Edit the script's 'User Variables' section with your Launcher and Branch installation paths.
4. Run the script (right-click and 'Run with PowerShell').

On first run, the script will backup your hosts file and your attributes.xml files. It will create copies that will be modified. These are how we will toggle the modification on/off in future runs.

## Credits
_Original credit goes to Chachi Sanchez (https://www.youtube.com/watch?v=lt4w73C6Wpo)_
