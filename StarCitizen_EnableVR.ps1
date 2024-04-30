# User variables
#TODO: Move this OUT of the script to prevent user mistakes...
# -> You are required to set these variables. If you don't the script will not work properly.
$sc_launcher_path = "C:\Program Files\Roberts Space Industries\RSI RC Launcher\RSI RC Launcher.exe"
# -> For the installation path, do NOT include the branch (EPTU, PTU, LIVE, TECH-PREVIEW, etc.)
$sc_installation_path = "L:\Games\RSI\StarCitizen"

# Static variables
$exec_policy_file = ".\execution_policy.setting"
$original_hosts_file = ".\hosts.bak"
$modified_hosts_file = ".\hosts.mod"
$eac_settings_json = "\EasyAntiCheat\Settings.json"
$vorpx_path = "$env:ProgramData\Animation Labs\vorpX\vorpControl.ini"
$vorpx_exclusions = @("StarCitizen_Launcher.exe", "EasyAntiCheat_EOS_Setup.exe", "RSI Launcher.exe", "RSI RC Launcher.exe")
$attributes_path = "\user\client\0\Profiles\default\attributes.xml"
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

# Functions
#TODO: Add comments on what's happening here...
function Start-ExitCleanup {
    # Cleans up temporary files.
    PROCESS {
        #TODO: Does this need more cleanup?
        if (Test-Path -Path $exec_policy_file) {
            $old_execution_policy = Get-Content -Path $exec_policy_file
            Remove-Item -Path $exec_policy_file -Force
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $old_execution_policy -Force
        }
    }
}
function Get-ExclusionInfo {
    param (
        $_vorpx_ini
    )
    PROCESS {
        $_last_exclusion = ($_vorpx_ini.Split("`r`n") | Where-Object { $_ -like "sExcl*" })[-1]
        $_cur_indx = [int]$_last_exclusion.Split("l")[1].Split("=")[0]
        $_cur_indx++
        $_last_exclusion_indx = $_vorpx_ini.IndexOf($_last_exclusion)
        $_last_exclusion_indx += $_last_exclusion.Length
        return @{
            'NewCount' = $_cur_indx;
            'NewIndex' = $_last_exclusion_indx;
        }
    }
}

# User variable cleanup
#TODO: Need more safeties...
if ($sc_installation_path[-1] -ne "\") {
    $sc_installation_path = "$sc_installation_path\"
}
$sc_branch_paths = Get-ChildItem -Path "$sc_installation_path" -Directory | Select-Object -ExpandProperty FullName

# Check if we're administrator... This is REQUIRED since we're modifying system files.
$current_user = [Security.Principal.WindowsIdentity]::GetCurrent()
$is_current_user_admin = (New-Object Security.Principal.WindowsPrincipal $current_user).IsInRole(`
        [Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $is_current_user_admin) {
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
    exit
}

# Check if this is the first execution.
#TODO: Try to combine all "first execution" tasks here...
if (-not (Test-Path -Path $original_hosts_file)) {
    # This is the first execution.
    Write-Host ">> This is your first execution. We're creating a backup of your hosts file and a copy we'll modify..."
    # Backup the original hosts file...
    Copy-Item -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Destination $original_hosts_file
    # Duplicate the original hosts file to something we can modify freely...
    Copy-Item -Path $original_hosts_file -Destination $modified_hosts_file
    # Add the EAC block...
    "`r`n`r`n# Star Citizen EAC Block for VorpX`r`n127.0.0.1`tmodules-cdn.eac-prod.on.epicgames.com" | `
        Out-File -FilePath $modified_hosts_file -Encoding utf8 -Append
}

# Iterate over every branch
#TODO: This should be ran every time, move it down to the launcher area.
foreach ($branch in $sc_branch_paths) {
    $json_change_made = $false
    $settings_json = $null = Get-Content -Path "$branch$eac_settings_json" -Raw | ConvertFrom-Json
    $settings_json | Get-Member -MemberType NoteProperty | ForEach-Object {
        if ($_.Name -like "*id") {
            if ($settings_json.$($_.Name) -notlike "*vorpx-eac-bypass") {
                $json_change_made = $true
                $settings_json.$($_.Name) = "vorpx-eac-bypass"
            }
        }
    }
    if ($json_change_made) {
        $settings_json | ConvertTo-Json -Depth 32 | Set-Content -Path "$branch$eac_settings_json"
    }
}

# VorpX Exclusions
#TODO: This should only be ran on "first execution"...
$vorpx_ini = Get-Content -Path "$vorpx_path" -Raw
foreach ($exclusion in $vorpx_exclusions) {
    if ($vorpx_ini -notlike "*$($exclusion)*") {
        $vorpx_change_made = $true
        $vorpx_info = Get-ExclusionInfo -_vorpx_ini $vorpx_ini
        $vorpx_ini = $vorpx_ini.Insert(
            $vorpx_info.NewIndex,
            "`r`nsExcl$($vorpx_info.NewCount)=$($exclusion)"
        )
    }
}
if ($vorpx_change_made) {
    $vorpx_ini | Out-File -FilePath "$vorpx_path" -Encoding ascii -Force
}

# Attributes modifications
#TODO: The modifications should only happen on "first execution"...
#TODO: Need section to add/remove original/modified version on launch.
foreach ($branch_path in $sc_branch_paths) {
    $branch_name = $branch_path.Split('\')[-1]
    if (-not (Test-Path -Path ".\$($branch_name)_attributes.xml.bak")) {
        Copy-Item -Path "$branch_path$attributes_path" -Destination ".\$($branch_name)_attributes.xml.bak"
        Copy-Item -Path ".\$($branch_name)_attributes.xml.bak" -Destination ".\$($branch_name)_attributes.xml.mod"
        $branch_mod_path = Convert-Path -Path ".\$($branch_name)_attributes.xml.mod"
        [xml]$attributes_xml = Get-Content -Path "$branch_mod_path"
        $nodes = $attributes_xml.SelectNodes("/Attributes/Attr")
        foreach ($attrib in $attributes_to_change) {
            if ($nodes | Where-Object { $_.name -eq "$($attrib.name)" }) {
                ($nodes | Where-Object { $_.name -eq "$($attrib.name)" }).SetAttribute("value", "$($attrib.value)")
            } else {
                $new_node = ($nodes | Where-Object { $_.name -eq "Preset0" }).Clone()
                $new_node.SetAttribute("name", "$($attrib.name)")
                $new_node.SetAttribute("value", "$($attrib.value)")
                $attributes_xml.Attributes.AppendChild($new_node)
            }
        }
        $attributes_xml.Save("$branch_mod_path")
    }
}

# Enable the EAC block...
#TODO: Expand this a lot... Needs things like Attributes.xml modifications here.
Write-Host "Enabling the EAC block..." -NoNewline
Copy-Item -Path $modified_hosts_file -Destination "$env:SystemRoot\System32\drivers\etc\hosts" -Force
Write-Host " Enabled!" -ForegroundColor Cyan

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

# Disable the EAC block...
#TODO: Expand this a lot... Needs things like Attributes.xml modifications here.
Write-Host "Disabling the EAC block..." -NoNewline
Copy-Item -Path $original_hosts_file -Destination "$env:SystemRoot\System32\drivers\etc\hosts" -Force
Write-Host " Disabled!" -ForegroundColor Cyan

# Exit cleanly
Start-ExitCleanup
exit