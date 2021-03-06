param (
	[string]$OutputDir,
	[string]$SolutionDir = ".",
	[string]$TargetFileName,
	[string]$TargetFileExt = ".dll",
	[string]$Project = "none",
	[string]$BuildConfig,
	[switch]$WhatIf = $false
)

########################################
# Configuration
$Author = "Tahvohck"
$GameVersion = ([Version]"1.3.7").ToString(3)   # Just to make sure that the Version is consistent
$MetaFile = "Info.json"
$copyItems = @(
	"$OutputDir/$TargetFileName$TargetFileExt",
	"$OutputDir/Properties/$MetaFile"
)
$Errors = @{
	BadDirectory = 2
}

$PBMBH = get-command "$SolutionDir/Output/PBMBH/PBModBuildHelper.exe" -ea SilentlyContinue


########################################
# Code start
if (!(Test-Path $SolutionDir)) {
	exit $Errors.BadDirectory }
if ($OutputDir -eq "" -or !(Test-Path $OutputDir)) {
	exit $Errors.BadDirectory }

$workingDir = "$SolutionDir/Output"
if (!(Test-Path $workingDir)) {
	mkdir -force $workingDir -WhatIf:$WhatIf | Foreach-Object {
		Write-Host "Created directory: $_"
	}
}
copy-item $copyItems[0] "$workingDir/$TargetFileName-$BuildConfig$TargetFileExt" `
	-WhatIf:$WhatIf `
	-ea Continue

$workingDir = "$SolutionDir/Output/$Project"
if (Test-Path $workingDir) {
	remove-item $workingDir -force -recurse -WhatIf:$WhatIf
}

mkdir -force $workingDir -WhatIf:$WhatIf | Foreach-Object {
	Write-Host "Created directory: $_"
}
foreach ($file in $copyItems) { 
	try {
		copy-item $file $workingDir `
			-WhatIf:$WhatIf `
			-ea stop
	} catch [Management.Automation.ItemNotFoundException] {
		Write-Host $_
	}
}

$dll = $copyItems[0]
$infofile = "$workingDir/$MetaFile"
if (Test-Path $infofile) {
    $json = gc $infofile | ConvertFrom-Json
    $json | Add-Member "AssemblyName" "$TargetFileName$TargetFileExt" -Force
    $json | Add-Member "Author" "$Author" -Force
    $json | Add-Member "GameVersion" "$GameVersion" -Force

    $remote = git remote get-url origin 2> $null
    if ($remote -notlike "fatal:*"){
        $json | Add-Member "HomePage" "$remote" -Force
        $json | Add-Member "Repository" "$remote" -Force
    } else {
        $json = $json | Select -Property * -Exclude HomePage,Repository
        Write-Host "Project $Project has no remote."
    }

    if ($PBMBH -ne $null) {
        $entryMethod = & $PBMBH  $dll
        if ($entryMethod -notlike "ERROR*") {
            $json | Add-Member "EntryMethod" "$entryMethod" -Force
        } else {
            Write-Error $entryMethod
        }
    } else {
        Write-Host "PBMBH missing. Auto EntryMethod unable to run."
    }

    $json | ConvertTo-Json | out-file -encoding ascii $infofile
} else {
    Write-Host "No Info file, mod $Project won't load!"
}
