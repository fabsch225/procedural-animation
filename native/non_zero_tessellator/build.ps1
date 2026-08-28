param(
    [ValidateSet("template_debug", "template_release")]
    [string]$Target = "template_debug",

    [ValidateSet("macos", "windows")]
    [string]$Platform = "macos",

    [ValidateSet("arm64", "x86_64")]
    [string]$Arch = "arm64",

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
    $buildArgs = @(
        "platform=$Platform"
        "target=$Target"
        "arch=$Arch"
        "api_version=4.6"
        "-j$Jobs"
    )

    if (Get-Command scons -ErrorAction SilentlyContinue) {
        scons @buildArgs
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        python3 -m SCons @buildArgs
    } else {
        throw "Neither scons nor python3 was found on PATH."
    }

	if ($LASTEXITCODE -ne 0) {
		throw "SCons failed with exit code $LASTEXITCODE."
	}
}
finally {
    Pop-Location
}
