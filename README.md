# StarCitizen VR EAC Bypass

This is a bypass for EAC in StarCitizen that prevents VR usage.

## Required Software
* [StarCitizen](https://robertsspaceindustries.com/enlist?referral=STAR-4N3T-JYVF) _(Launcher and installed branch(es).)_
* [VorpX](https://www.vorpx.com/) _(Make sure you've ran this at least once and registered.)_
* [PowerShell 5+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

## How-To
1. Download the latest release and extract to folder somewhere (it will create files when ran for the first time, so make sure it's a folder for just this).
2. _(Not necessary, but makes life easier)._ Create a shortcut to StarCitizen_EnableVR.ps1 on your desktop.
3. Open **UserSettings.xml** in a file editor of your choice and update **LauncherPath** and **InstallationPath** _(refer to FAQ for clarification on paths)_.
4. Run the script (right-click and 'Run with PowerShell'). The launcher while automatically launch when ready and the PowerShell window will remain open.
5. When you're done playing, close the launcher completely (don't let it minimize to taskbar) and all of your settings will revert.

On first run, the script will backup your hosts file and your attributes.xml files. It will create copies that will be modified. These are how we will toggle the modification on/off in future runs.

## FAQ
* LauncherPath
* * This should be the full path to your launcher, including file extension.
* InstallationPath
* * This should be the parent folder that contains all of your installed branches (i.e., LIVE, PTU, EPTU, etc.). The new launcher forces these into the same folder.
* Why does the script need Admin privileges?
* * Part of enabling VR for StarCitizen includes blocking EasyAntiCheat (EAC). The process involves simply redirecting traffic destined for EAC's servers to localhost, which we accomplish with the hosts file. The hosts file is technically a protected system file, which is why admin rights are needed.
* Help! I need to modify my resolution or FoV every time I play in VR.
* * Refer to the **Advanced Configuration** section.

## Advanced Configuration
These steps are only needed if you need to modify the resolution or FoV. For now, I've decided to not expose this in UserSettings.xml, but that may change in the future.

1. Ensure that your on your original configuration by closing the RSI launcher and checking that the script is not running.
2. Remove all files in the script directory except **StarCitizen_EnableVR.ps1**, and **UserSettings.xml**.
3. Open **StarCitizen_EnableVR.ps1** in a editor of your choice. _(I recommend Visual Studio Code, but other editors such as PowerShell ISE, NotePad++, or good old NotePad work just as well.)_
4. Locate the section labeled **Static variables**.
5. Locate the variable named **$attributes_to_change**.
6. The only three I recommend changing if you need are: **Height**, **Width**, and **FOV**.
7. Save your changes.
8. Run the script. It will perform initial setup again but use your new settings.

## Credits
_Original credit goes to Chachi Sanchez (https://www.youtube.com/watch?v=lt4w73C6Wpo)_
