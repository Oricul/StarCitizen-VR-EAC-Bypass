#region User variables
## Import user settings from XML file.
[xml]$user_settings = Get-Content -Path ".\UserSettings.xml"
$sc_launcher_path = $user_settings.UserSettings.LauncherPath
$sc_installation_path = $user_settings.UserSettings.InstallationPath
#endregion User variables

#region Static variables
## These variables are general-use in the script to make some things easier.
$exec_policy_file = ".\execution_policy.setting"
$original_hosts_file = ".\hosts.bak"
$modified_hosts_file = ".\hosts.mod"
$eac_settings_json = "\EasyAntiCheat\Settings.json"
$vorpx_path = "$env:ProgramData\Animation Labs\vorpX\vorpControl.ini"
## These are the VorpX exclusions for files - they only require the name. Should cover most people.
$vorpx_exclusions = @(
    "StarCitizen_Launcher.exe",
    "EasyAntiCheat_EOS_Setup.exe",
    "RSI Launcher.exe",
    "RSI RC Launcher.exe"
)
$attributes_path = "\user\client\0\Profiles\default\attributes.xml"
## These are the 'recommended' attributes for VR in StarCitizen.
#? Should we move some of these to UserSettings.xml? Such as:
#?    Height, Width, FOV?
$attributes_to_change = @(
    @{
        'name'  = 'WindowMode';
        'value' = '2';
    },
    @{
        'name'  = 'VSync';
        'value' = '0';
    },
    @{
        'name'  = 'Height';
        'value' = '1800';
    },
    @{
        'name'  = 'Width';
        'value' = '2400';
    },
    @{
        'name'  = 'FOV';
        'value' = '115';
    },
    @{
        'name'  = 'AutoZoomOnSelectedTarget';
        'value' = '0';
    },
    @{
        'name'  = 'AutoZoomOnSelectedTargetStrength';
        'value' = '0';
    },
    @{
        'name'  = 'HeadtrackingSource';
        'value' = '1';
    },
    @{
        'name'  = 'HeadtrackingToggle';
        'value' = '1';
    }
)
$eac_config_folder = "$env:APPDATA\EasyAntiCheat\"
#endregion Static variables

#region Functions
function Start-ExitCleanup {
    # Cleans up temporary files from script execution.
    PROCESS {
        # Check if we needed to elevate to Admin and change the execution policy.
        if (Test-Path -Path $exec_policy_file) {
            # Since we did, get the old execution policy, revert our change, then remove the temporary file.
            $old_execution_policy = Get-Content -Path $exec_policy_file
            Remove-Item -Path $exec_policy_file -Force
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $old_execution_policy -Force
        }
    }
}
function Get-ExclusionInfo {
    # Gets information from VorpX ini required to make new exclusions.
    param (
        $_vorpx_ini
    )
    PROCESS {
        # Find the last exclusion in the INI file.
        $_last_exclusion = ($_vorpx_ini.Split("`r`n") | Where-Object { $_ -like "sExcl*" })[-1]
        # Find the current integer index of exclusions and increment it.
        $_cur_indx = [int]$_last_exclusion.Split("l")[1].Split("=")[0]
        $_cur_indx++
        # Find the file index where we can insert new exclusions.
        $_last_exclusion_indx = $_vorpx_ini.IndexOf($_last_exclusion)
        $_last_exclusion_indx += $_last_exclusion.Length
        # Return a dictionary with relevant information.
        return @{
            'NewCount' = $_cur_indx;
            'NewIndex' = $_last_exclusion_indx;
        }
    }
}
#endregion Functions

#region User variable error checking
if ($sc_installation_path[-1] -ne "\") {
    $sc_installation_path = "$sc_installation_path\"
}
# Get installed branch paths from installation path.
$sc_branch_paths = Get-ChildItem -Path "$sc_installation_path" -Directory | Select-Object -ExpandProperty FullName
#endregion User variable error checking

#region Admin check
# Check if we're administrator... This is REQUIRED since we're modifying system files.
$current_user = [Security.Principal.WindowsIdentity]::GetCurrent()
$is_current_user_admin = (New-Object Security.Principal.WindowsPrincipal $current_user).IsInRole(`
        [Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $is_current_user_admin) {
    # We're not an administrator, we're going to try to self-elevate.
    Write-Host "You're not an administrator (required). Trying to elevate..." -ForegroundColor Red -NoNewline
    Get-ExecutionPolicy | Out-File -Encoding utf8 -FilePath $exec_policy_file
    $elevated_script = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $elevated_script.Arguments = "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force;`
        Set-Location -Path $($PSScriptRoot);`
        $($MyInvocation.MyCommand.Definition)"
    $elevated_script.Verb = "RunAs"
    try {
        [System.Diagnostics.Process]::Start($elevated_script) | Out-Null
        Write-Host " Success!" -ForegroundColor Cyan
    } catch {
        Write-Host " Failed to launch elevated PowerShell window. Did you deny permissions?" -ForegroundColor Yellow
        Start-ExitCleanup
    }
    # In the end, whether this works or not, we shouldn't let the script continue.
    exit
}
#endregion Admin check

#region Initial/Update Config
#region [HOSTS]
# Check if hosts backup file exists.
if (-not (Test-Path -Path $original_hosts_file)) {
    # Hosts backup file doesn't exist.
    Write-Host ">> [hosts] We're creating a backup of your hosts file and a copy that will be modified..."
    # Backup the original hosts file and then duplicate it for modification.
    Copy-Item -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Destination $original_hosts_file
    Copy-Item -Path $original_hosts_file -Destination $modified_hosts_file
    # Add the EAC block to new modified version.
    "`r`n`r`n# Star Citizen EAC Block for VorpX`r`n127.0.0.1`tmodules-cdn.eac-prod.on.epicgames.com" | `
        Out-File -FilePath $modified_hosts_file -Encoding utf8 -Append
}
#endregion [HOSTS]

#region [ATTRIBUTES.XML]
# Check if attributes.xml backup file exists for each installed branch.
# Iterate over each installed branch.
foreach ($branch_path in $sc_branch_paths) {
    # Grab the branch name used for naming backup files.
    $branch_name = $null = $branch_path.Split('\')[-1]
    # Check if the branch_attributes.xml.bak file exists (original copy).
    if (-not (Test-Path -Path ".\$($branch_name)_attributes.xml.bak")) {
        # attributes.xml backup file doesn't exist.
        Write-Host ">> [$branch_name > attributes.xml] We're creating a backup of your attributes.xml file and a copy that will be modified..."
        # Back it up, fix the name, and make a copy for modification.
        Copy-Item -Path "$branch_path$attributes_path" -Destination ".\$($branch_name)_attributes.xml.bak"
        Copy-Item -Path ".\$($branch_name)_attributes.xml.bak" -Destination ".\$($branch_name)_attributes.xml.mod"
        # Writing XML files from PowerShell is finicky, so let's fix the path.
        $branch_mod_path = Convert-Path -Path ".\$($branch_name)_attributes.xml.mod"
        # Load the current branch modifiable attributes.xml file.
        [xml]$attributes_xml = Get-Content -Path "$branch_mod_path"
        # Pick out all the Nodes in Attributes/Attr. Need to do this since this XML file format is weird.
        $nodes = $attributes_xml.SelectNodes("/Attributes/Attr")
        # Iterate over every attribute we need to modify.
        foreach ($attrib in $attributes_to_change) {
            # Find nodes where the attribute name matches what we need to modify.
            if ($nodes | Where-Object { $_.name -eq "$($attrib.name)" }) {
                # If we find the node, update the value to the VR-friendly value.
                ($nodes | Where-Object { $_.name -eq "$($attrib.name)" }).SetAttribute("value", "$($attrib.value)")
            } else {
                # We didn't find any nodes that matched, so we'll just create them.
                $new_node = ($nodes | Where-Object { $_.name -eq "Preset0" }).Clone()
                $new_node.SetAttribute("name", "$($attrib.name)")
                $new_node.SetAttribute("value", "$($attrib.value)")
                $attributes_xml.Attributes.AppendChild($new_node)
            }
        }
        # If we have to make these changes, then we always have to save the modified version.
        $attributes_xml.Save("$branch_mod_path")
    }
}
#endregion [ATTRIBUTES.XML]

#region [VORPX]
# Check every VorpX exclusion and make changes as necessary.
# Import VorpX configuration file.
$vorpx_ini = Get-Content -Path "$vorpx_path" -Raw
# Iterate over each exclusion in list of exculsions needed for StarCitizen.
foreach ($exclusion in $vorpx_exclusions) {
    # Check if the exclusion doesn't exist.
    if ($vorpx_ini -notlike "*$($exclusion)*") {
        # The exclusion doesn't exist, so let's get the required information and make the exclusion.
        $vorpx_change_made = $true
        $vorpx_info = Get-ExclusionInfo -_vorpx_ini $vorpx_ini
        $vorpx_ini = $vorpx_ini.Insert(
            $vorpx_info.NewIndex,
            "`r`nsExcl$($vorpx_info.NewCount)=$($exclusion)"
        )
    }
}
# Check if we made any changes to VorpX configuration.
if ($vorpx_change_made) {
    # Changes were made, let's save the updated file.
    $vorpx_ini | Out-File -FilePath "$vorpx_path" -Encoding ascii -Force
}
#endregion [VORPX]

#region [EASYANTICHEAT]
# Check if any EasyAntiCheat configuration is needed.
# Iterate over each installed branch.
foreach ($branch in $sc_branch_paths) {
    # Reset the json_change_made variable
    $json_change_made = $false
    # Import and convert the EAC settings json.
    $settings_json = $null = Get-Content -Path "$branch$eac_settings_json" -Raw | ConvertFrom-Json
    # Iterate over all NoteProperties (i.e., keys)
    $settings_json | Get-Member -MemberType NoteProperty | ForEach-Object {
        # Check if the current key name ends with 'id'.
        if ($_.Name -like "*id") {
            # If it does, check that the value isn't already set.
            if ($settings_json.$($_.Name) -notlike "*vorpx-eac-bypass") {
                # Since it's not set, toggle our tracking vars and make the change.
                $json_change_made = $eac_json_change_made = $true
                $settings_json.$($_.Name) = "vorpx-eac-bypass"
            }
        }
    }
    # Check if we made any changes to current branch configuration.
    if ($json_change_made) {
        # Changes were made, convert back to JSON, and save the file.
        $settings_json | ConvertTo-Json -Depth 32 | Set-Content -Path "$branch$eac_settings_json"
    }
}
# Check if any changes were made to any branch's EAC configuration.
if ($eac_json_change_made) {
    # If we had to modify the EAC json, there's a good chance we need to remove the EAC folder too.
    # Check if the folder even exists.
    if (Test-Path -Path "$eac_config_folder") {
        # Remove the folder and all of it's contents.
        Remove-Item -Path "$eac_config_folder" -Force -Recurse
    }
}
#endregion [EASYANTICHEAT]
#endregion Intiial/Update Config

#region Enable
# Enable the VR config.
Write-Host "Enabling the VR configuration..."
# Check if VorpX is running.
Write-Host "[VorpX Check]" -NoNewline
if (-not (Get-Process -Name "vorpControl" -ErrorAction SilentlyContinue)) {
    Write-Host " Failed!" -ForegroundColor Red
    Read-Host -Prompt "`r`nVorpX needs to be running. Press any key to exit..."
    Start-ExitCleanup
    exit
}
Write-Host " Pass!" -ForegroundColor Cyan
Write-Host "[hosts]" -NoNewline
# Copy the hosts file back to the system folder in order to block the EAC domain.
Copy-Item -Path $modified_hosts_file -Destination "$env:SystemRoot\System32\drivers\etc\hosts" -Force
Write-Host " Enabled!" -ForegroundColor Cyan
foreach ($branch_path in $sc_branch_paths) {
    $branch_name = $null = $branch_path.Split('\')[-1]
    Write-Host "[$branch_name > attributes.xml]" -NoNewline
    # Copy the VR-compatible attributes.xml to the appropriate branch path.
    Copy-Item -Path ".\$($branch_name)_attributes.xml.mod" -Destination "$branch_path$attributes_path" -Force
    Write-Host " Enabled!" -ForegroundColor Cyan
}
Write-Host "VR configuration enabled!"
#endregion Enable

#region Launcher
# Launch the patcher and wait for it to close.
$launcher_name = $sc_launcher_path.Split("\")[-1].Split(".")[0]
Write-Host "`r`n>> To disable the EAC block, close the Star Citizen LAUNCHER."
if (-not (Get-Process -Name $launcher_name -ErrorAction SilentlyContinue | Out-Null)) {
    # Patcher isn't running, launch it.
    Start-Process -FilePath $sc_launcher_path -Wait
} else {
    # Patcher is running, kill it and start it again.
    Stop-Process -Name $launcher_name -Force
    Start-Process -FilePath $sc_launcher_path -Wait
}
Write-Host ">> Star Citizen launcher has been closed!" -ForegroundColor Cyan
#endregion Launcher

#region Disable
# Disable the VR config.
Write-Host "Disabling the VR configuration..." -NoNewline
Write-Host "[hosts]" -NoNewline
Copy-Item -Path $original_hosts_file -Destination "$env:SystemRoot\System32\drivers\etc\hosts" -Force
Write-Host " Disabled!" -ForegroundColor Cyan
foreach ($branch_path in $sc_branch_paths) {
    $branch_name = $null = $branch_path.Split('\')[-1]
    Write-Host "[$branch_name > attributes.xml]" -NoNewline
    # Copy the original attributes.xml to the appropriate branch path.
    Copy-Item -Path ".\$($branch_name)_attributes.xml.bak" -Destination "$branch_path$attributes_path" -Force
    Write-Host " Disabled!" -ForegroundColor Cyan
}
Write-Host "VR configuration disabled!"
#endregion Disable

#region exit
# Exit cleanly
Start-ExitCleanup
exit
#endregion exit