param(
	[ValidateSet("template_debug", "template_release")]
	[string]$Target = "template_release",

	[ValidateRange(1, 64)]
	[int]$Jobs = 4,

	[string]$EmsdkPath = ""
)

$ErrorActionPreference = "Stop"
$emscriptenVersion = "4.0.11"
$extensionRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotCpp = Join-Path $extensionRoot "godot-cpp"

if (-not (Test-Path $godotCpp)) {
	git clone --depth 1 --branch 10.0.0-rc1 `
		https://github.com/godotengine/godot-cpp.git $godotCpp
	if ($LASTEXITCODE -ne 0) {
		throw "Cloning godot-cpp failed with exit code $LASTEXITCODE."
	}
}

if ([string]::IsNullOrWhiteSpace($EmsdkPath)) {
	if (-not [string]::IsNullOrWhiteSpace($env:EMSDK)) {
		$EmsdkPath = $env:EMSDK
	}
	else {
		$EmsdkPath = Join-Path $env:LOCALAPPDATA "Godot\emsdk"
	}
}

$emsdkScript = Join-Path $EmsdkPath "emsdk.ps1"
if (-not (Test-Path $emsdkScript)) {
	$emsdkParent = Split-Path -Parent $EmsdkPath
	New-Item -ItemType Directory -Force -Path $emsdkParent | Out-Null
	git clone --depth 1 https://github.com/emscripten-core/emsdk.git $EmsdkPath
	if ($LASTEXITCODE -ne 0) {
		throw "Cloning emsdk failed with exit code $LASTEXITCODE."
	}
}

$emcc = Join-Path $EmsdkPath "upstream\emscripten\emcc.bat"
& $emsdkScript install $emscriptenVersion
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $emcc)) {
	throw "Installing Emscripten $emscriptenVersion failed with exit code $LASTEXITCODE."
}

& $emsdkScript activate $emscriptenVersion
if ($LASTEXITCODE -ne 0) {
	throw "Activating Emscripten $emscriptenVersion failed with exit code $LASTEXITCODE."
}

. (Join-Path $EmsdkPath "emsdk_env.ps1")

Push-Location $extensionRoot
try {
	scons platform=web target=$Target arch=wasm32 threads=no api_version=4.6 `
		"-j$Jobs"
	if ($LASTEXITCODE -ne 0) {
		throw "SCons failed with exit code $LASTEXITCODE."
	}
}
finally {
	Pop-Location
}
