param(
    [ValidateSet("template_debug", "template_release")]
    [string]$Target = "template_debug",

    [ValidateRange(1, 64)]
    [int]$Jobs = 4
)

$ErrorActionPreference = "Stop"
$extensionRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotCpp = Join-Path $extensionRoot "godot-cpp"

if (-not (Test-Path $godotCpp)) {
    git clone --depth 1 --branch 10.0.0-rc1 `
        https://github.com/godotengine/godot-cpp.git $godotCpp
}

Push-Location $extensionRoot
try {
	scons platform=windows target=$Target arch=x86_64 api_version=4.6 `
		"-j$Jobs"
	if ($LASTEXITCODE -ne 0) {
		throw "SCons failed with exit code $LASTEXITCODE."
	}
}
finally {
    Pop-Location
}
