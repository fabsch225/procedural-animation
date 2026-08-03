<#
.SYNOPSIS
Exports the game and deploys its Web and Windows builds to itch.io.

.EXAMPLE
./deploy_itch.ps1 -Preview

Exports both builds and previews the changes without uploading them.

.EXAMPLE
./deploy_itch.ps1 -Version 0.1.1

Exports and publishes both builds with version 0.1.1.

.EXAMPLE
./deploy_itch.ps1 -Version 0.1.1 -SkipExport

Publishes the builds already present in _exports.
#>
[CmdletBinding()]
param(
	[string]$Version = '',

	[switch]$Preview,

	[switch]$SkipExport,

	[string]$GodotExecutable = (
		'C:\Godot\4.7\engine\Godot_v4.7.1-stable_win64.exe\' +
		'Godot_v4.7.1-stable_win64_console.exe'
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$itchTarget = 'baconeggsrl/procedural-animation'
$webBuild = Join-Path $projectRoot '_exports\web'
$windowsBuild = Join-Path $projectRoot '_exports\windows'

if (-not $Preview -and [string]::IsNullOrWhiteSpace($Version)) {
	throw 'Version is required when publishing. Example: ./deploy_itch.ps1 -Version 0.1.1'
}


function Invoke-CheckedCommand {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Executable,

		[Parameter(Mandatory = $true)]
		[string[]]$CommandArguments,

		[Parameter(Mandatory = $true)]
		[string]$Description
	)

	Write-Host "`n==> $Description" -ForegroundColor Cyan
	& $Executable @CommandArguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Description failed with exit code $LASTEXITCODE."
	}
}


function Clear-GeneratedBuild {
	param(
		[Parameter(Mandatory = $true)]
		[string]$BuildPath
	)

	$fullProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd(
		[System.IO.Path]::DirectorySeparatorChar
	) + [System.IO.Path]::DirectorySeparatorChar
	$fullBuildPath = [System.IO.Path]::GetFullPath($BuildPath)
	if (-not $fullBuildPath.StartsWith(
		$fullProjectRoot,
		[System.StringComparison]::OrdinalIgnoreCase
	)) {
		throw "Refusing to clean a build directory outside the project: $fullBuildPath"
	}

	if (Test-Path -LiteralPath $fullBuildPath) {
		Write-Host "Cleaning generated build: $fullBuildPath"
		Remove-Item -LiteralPath $fullBuildPath -Recurse -Force
	}
	New-Item -ItemType Directory -Path $fullBuildPath -Force | Out-Null
}


if (-not $SkipExport) {
	if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
		throw "Godot executable was not found at: $GodotExecutable"
	}

	Clear-GeneratedBuild -BuildPath $webBuild
	Clear-GeneratedBuild -BuildPath $windowsBuild

	Invoke-CheckedCommand `
		-Executable $GodotExecutable `
		-CommandArguments @(
			'--headless', '--path', $projectRoot, '--export-release', 'Web'
		) `
		-Description 'Exporting Web release'

	Invoke-CheckedCommand `
		-Executable $GodotExecutable `
		-CommandArguments @(
			'--headless', '--path', $projectRoot, '--export-release', 'Windows Desktop'
		) `
		-Description 'Exporting Windows release'
}

if (-not (Test-Path -LiteralPath (Join-Path $webBuild 'index.html') -PathType Leaf)) {
	throw "Web build is missing: $(Join-Path $webBuild 'index.html')"
}
if (-not (Test-Path -LiteralPath (Join-Path $windowsBuild 'procedural-animation.exe') -PathType Leaf)) {
	throw "Windows build is missing: $(Join-Path $windowsBuild 'procedural-animation.exe')"
}

$butler = Get-Command 'butler' -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $butler) {
	throw 'butler was not found on PATH. Open a new terminal after installing it.'
}

if ($Preview) {
	Invoke-CheckedCommand `
		-Executable $butler.Source `
		-CommandArguments @(
			'push-preview', '--changes-only', $webBuild, "${itchTarget}:html5"
		) `
		-Description 'Previewing Web deployment'

	Invoke-CheckedCommand `
		-Executable $butler.Source `
		-CommandArguments @(
			'push-preview', '--changes-only', $windowsBuild, "${itchTarget}:windows"
		) `
		-Description 'Previewing Windows deployment'

	Write-Host "`nPreview complete. Nothing was uploaded." -ForegroundColor Green
	exit 0
}

Invoke-CheckedCommand `
	-Executable $butler.Source `
	-CommandArguments @(
		'push', $webBuild, "${itchTarget}:html5", '--userversion', $Version
	) `
	-Description "Publishing Web version $Version"

Invoke-CheckedCommand `
	-Executable $butler.Source `
	-CommandArguments @(
		'push', $windowsBuild, "${itchTarget}:windows", '--userversion', $Version
	) `
	-Description "Publishing Windows version $Version"

Write-Host "`nDeployment $Version completed successfully." -ForegroundColor Green
