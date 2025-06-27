<#
.SYNOPSIS
    Enumerate every Control‑Panel / shell item that surfaces in the God‑Mode
    “All Tasks” view and its upstream sources, then in a second pass resolve
    DeepLink launch strings for legacy Control‑Panel tasks.  Native
    Write‑Progress indicators show overall status.

.DESCRIPTION
    Stage 1 – Harvest metadata from four classic locations (registry + COM):
      1. HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace
      2. HKLM:\SOFTWARE\Classes\Folder\shell
      3. HKCR:\CLSID\{guid}\ShellFolder
      4. God‑Mode folder shell:::{ED7BA470‑8E54‑465E‑825C‑99712043E01C}

    Stage 2 – For every God‑Mode entry that still lacks a command, look up its
    DeepLink in %SystemRoot%\ImmersiveControlPanel\Settings\AllSystemSettings_*.xml.

.PARAMETER OutFile
    Optional path for a UTF‑8 JSON dump of the combined results.

.PARAMETER Force
    Overwrite OutFile if it already exists.

.EXAMPLE
    .\Get‑GodModeGuts.ps1 -OutFile .\godmode.json -Force

.AUTHOR
    DJ Stomp <85457381+DJStompZone@users.noreply.github.com>
.LICENSE
    MIT
.LINK
    https://github.com/djstompzone/apotheosis
#>

[CmdletBinding()]
param(
    [string]$OutFile,
    [switch]$Force
)

$APOTHEOSIS_LOGO = "OgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoAOgA6ADoADQAKADoAOgAgACAAIAAgACAALgBvAG8AIAAgAC4AbwBQAFkAbwAuACAALgBvAFAAWQBvAC4AIABvAG8AbwBvAG8AIAAgAG8AIAAgACAAIABvACAALgBvAFAAWQBvAC4AIAAuAG8AUABZAG8ALgAgAC4AbwBQAFkAbwAuACAAbwAgAC4AbwBQAFkAbwAuACAAOgA6AA0ACgA6ADoAIAAgACAAIAAuAFAAIAA4ACAAIAA4ACAAIAAgACAAOAAgADgAIAAgACAAIAA4ACAAIAAgADgAIAAgACAAIAA4ACAAIAAgACAAOAAgADgALgAgACAAIAAgACAAOAAgACAAIAAgADgAIAA4ACAAIAAgACAAIAAgADgAIAA4ACAAIAAgACAAIAAgADoAOgANAAoAOgA6ACAAIAAgAC4AUAAgACAAOAAgAG8AOABZAG8AbwBQACcAIAA4ACAAIAAgACAAOAAgACAAIAA4ACAAIAAgAG8AOABvAG8AbwBvADgAIABgAGIAbwBvACAAIAAgADgAIAAgACAAIAA4ACAAYABZAG8AbwBvAC4AIAA4ACAAYABZAG8AbwBvAC4AIAA6ADoADQAKADoAOgAgACAAbwBQAG8AbwBvADgAIAAgADgAIAAgACAAIAAgACAAOAAgACAAIAAgADgAIAAgACAAOAAgACAAIAAgADgAIAAgACAAIAA4ACAALgBQACAAIAAgACAAIAA4ACAAIAAgACAAOAAgACAAIAAgACAAYAA4ACAAOAAgACAAIAAgACAAYAA4ACAAOgA6AA0ACgA6ADoAIAAuAFAAIAAgACAAIAA4ACAAIAA4ACAAIAAgACAAIAAgADgAIAAgACAAIAA4ACAAIAAgADgAIAAgACAAIAA4ACAAIAAgACAAOAAgADgAIAAgACAAIAAgACAAOAAgACAAIAAgADgAIAAgACAAIAAgACAAOAAgADgAIAAgACAAIAAgACAAOAAgADoAOgANAAoAOgA6AC4AUAAgACAAIAAgACAAOAAgACAAOAAgACAAIAAgACAAIABgAFkAbwBvAFAAJwAgACAAIAA4ACAAIAAgACAAOAAgACAAIAAgADgAIABgAFkAbwBvAFAAJwAgAGAAWQBvAG8AUAAnACAAYABZAG8AbwBQACcAIAA4ACAAYABZAG8AbwBQACcAIAA6ADoADQAKADoAOgAuAC4AOgA6ADoAOgA6AC4ALgA6AC4ALgA6ADoAOgA6ADoAOgAuAC4ALgAuAC4AOgA6ADoALgAuADoAOgA6AC4ALgA6ADoAOgAuAC4AOgAuAC4ALgAuAC4AOgA6AC4ALgAuAC4ALgA6ADoALgAuAC4ALgAuADoALgAuADoALgAuAC4ALgAuADoAOgA6AA=="

$APOTHEOSIS_BANNER = @"

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
$([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($APOTHEOSIS_LOGO)))
::..:::::..:..::::::.....:::..:::..:::..:.....::.....::.....:..:.....:::
:::::::::::::::::: GodMode Shell Namespace Enumerator ::::::::::::::::::
:::::::::::::::::::::::::: (c) 2025 DJ Stomp :::::::::::::::::::::::::::
::::::::::::::::::::::::: "No Rights Reserved" :::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

"@

function Show-Banner {
	foreach ($line in $APOTHEOSIS_BANNER -split "`r?`n") {
		Write-Host $line -ForegroundColor DarkGreen -BackgroundColor Black
	}
}

function Test-Admin {
    $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = [Security.Principal.WindowsPrincipal]::new($id)
    $pri.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Get-DeepLinkBySettingID {
    param([string]$Guid)
    if ($Guid -notmatch '^{.+}$') { $Guid = "{$Guid}" }
    $xml = Get-ChildItem "$env:SystemRoot\ImmersiveControlPanel\Settings" -Filter 'AllSystemSettings_*.xml' | Select-Object -First 1
    if (-not $xml) { return $null }
    [xml]$doc = Get-Content -LiteralPath $xml.FullName
    $node = $doc.PCSettings.SearchableContent | Where-Object { $_.SettingIdentity.SettingID -eq $Guid }
    if ($node) {
        $dl = $node.ApplicationInformation.SelectSingleNode('DeepLink').InnerText
        return ($dl -replace '%windir%', $env:windir)
    }
    return $null
}

if (-not (Test-Admin)) { Write-Error 'Run elevated.'; exit 1 }

Show-Banner
$results = [System.Collections.Generic.List[pscustomobject]]::new()

# ============================
# Stage 1 - Harvest
# ============================

Write-Progress -Activity 'Stage 1: Harvest' -Status 'Initializing' -PercentComplete 0

# 1. ControlPanel NameSpace
$root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace'
if (Test-Path $root) {
    $kids = Get-ChildItem $root
    $total = $kids.Count
    $i = 0
    foreach ($k in $kids) {
        $i++
        Write-Progress -Activity 'Enumerating Namespace' -Status "$i / $total" -PercentComplete ($i/$total*100)
        $clsid = $k.PSChildName
        $disp  = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\CLSID\{$clsid}" -EA 0).'(Default)'
        $results.Add([pscustomobject]@{ Source='NameSpace'; Key=$clsid; Name=$disp; Command="explorer.exe shell:::{${clsid}}" })
    }
    Write-Progress -Activity 'Enumerating Namespace' -Completed
}

# 2. Folder\shell verbs
$root = 'HKLM:\SOFTWARE\Classes\Folder\shell'
if (Test-Path $root) {
    $kids = Get-ChildItem $root
    $total = $kids.Count
    $i = 0
    foreach ($v in $kids) {
        $i++
        Write-Progress -Activity 'Populating Folder\shell' -Status "$i / $total" -PercentComplete ($i/$total*100)
        $cmd = (Get-ItemProperty -Path ($v.PSPath + '\\command') -EA 0).'(Default)'
        $results.Add([pscustomobject]@{ Source='FolderShellVerb'; Key=$v.PSChildName; Name=$v.GetValue('', $v.PSChildName); Command=$cmd })
    }
    Write-Progress -Activity 'Populating Folder\shell' -Completed
}

# 3. CLSID ShellFolder entries
$root = 'HKCR:\CLSID'
if (Test-Path $root) {
    $kids = Get-ChildItem $root | Where-Object { Test-Path "$($_.PSPath)\\ShellFolder" }
    $total = $kids.Count
    $i = 0
    foreach ($c in $kids) {
        $i++
        Write-Progress -Activity 'Populating CLSID ShellFolder' -Status "$i / $total" -PercentComplete ($i/$total*100)
        $guid = $c.PSChildName.Trim('{}')
        $name = $c.GetValue('', $null)
        $results.Add([pscustomobject]@{ Source='CLSID_ShellFolder'; Key=$guid; Name=$name; Command="explorer.exe shell:::{${guid}}" })
    }
    Write-Progress -Activity 'Populating CLSID ShellFolder' -Completed
}

# 4. GodMode COM
$shell = [Activator]::CreateInstance([type]::GetTypeFromProgID('Shell.Application'))
$god   = $shell.Namespace('shell:::{ED7BA470-8E54-465E-825C-99712043E01C}')
if ($god) {
    $cnt = $god.Items().Count
    for ($n = 0; $n -lt $cnt; $n++) {
        Write-Progress -Activity 'Enumerating GodMode COM' -Status "$($n+1) / $cnt" -PercentComplete (($n+1)/$cnt*100)
        $itm = $god.Items().Item($n)
        $results.Add([pscustomobject]@{
            Source  = 'GodModeTask'
            Key     = $itm.Path
            Name    = $itm.Name
            Command = $itm.ParsingName
        })
    }
    Write-Progress -Activity 'Enumerating GodMode COM' -Completed
} else {
    Write-Warning 'GodMode COM enumeration failed.'
}

# ============================
# Stage 2 - Resolve DeepLinks
# ============================
$needs = $results | Where-Object { $_.Source -eq 'GodModeTask' -and ([string]::IsNullOrWhiteSpace($_.Command)) }
$total = $needs.Count
$i = 0
foreach ($r in $needs) {
    $i++
    Write-Progress -Activity 'Resolving DeepLinks' -Status "$i / $total" -PercentComplete ($i/$total*100)
    $clsid = ($r.Key -split '[{}]' | Where-Object { $_ -match '^[0-9A-Fa-f\-]{36}$' })[-1]
    if ($clsid) {
        $r.Command = Get-DeepLinkBySettingID $clsid
    }
}
Write-Progress -Activity 'Resolving DeepLinks' -Completed

# ============================
# Output
# ============================
$results
if ($OutFile) {
    if (-not $Force -and (Test-Path $OutFile)) {
        Write-Error "File '$OutFile' already exists. Use -Force to overwrite."
    } else {
        $results | ConvertTo-Json -Depth 4 | Set-Content -Path $OutFile -Encoding UTF8
        Write-Host "Saved full dump to $OutFile"
    }
}
