Param(
    [Switch]$Help = $(if (Test-Path variable:Help) { $Help }),
    [Switch]$Quiet = $(if (Test-Path variable:Quiet) { $Quiet }),
    [Switch]$Verbose = $(if (Test-Path variable:Verbose) { $Verbose }),
    [String]$ProductName = $(if (Test-Path variable:ProductName) { "${ProductName}" } else { "obs-plugin" }),
    [String]$BuildDirectory = $(if (Test-Path variable:BuildDirectory) { "${BuildDirectory}" } else { "build" }),
    [String]$BuildArch = $(if (Test-Path variable:BuildArch) { "${BuildArch}" } else { (Get-WmiObject Win32_OperatingSystem).OSArchitecture}),
    [String]$BuildConfiguration = $(if (Test-Path variable:BuildConfiguration) { "${BuildConfiguration}" } else { "RelWithDebInfo" })
)

##############################################################################
# Windows libobs library build function
##############################################################################
#
# This script file can be included in build scripts for Windows or run
# directly
#
##############################################################################

$ErrorActionPreference = "Stop"

function Build-OBS-Libs {
    Param(
        [String]$BuildDirectory = $(if (Test-Path variable:BuildDirectory) { "${BuildDirectory}" }),
        [String]$BuildArch = $(if (Test-Path variable:BuildArch) { "${BuildArch}" }),
        [String]$BuildConfiguration = $(if (Test-Path variable:BuildConfiguration) { "${BuildConfiguration}" })
    )

    Write-Status "Build libobs and obs-frontend-api"

    Configure-OBS-Libs

    Ensure-Directory ${ObsBuildDir}
    Write-Step "Build OBS targets..."

    Invoke-Expression "cmake --build plugin_${BuildDirectory}$(if (${BuildArch} -eq "64-bit") { "64" } else { "32" }) -t obs-frontend-api --config ${BuildConfiguration}"

    Ensure-Directory ${CheckoutDir}
}

function Configure-OBS-Libs {
    Ensure-Directory ${ObsBuildDir}
    Write-Status "Configuration of OBS library build"

    $QtDirectory = "${CheckoutDir}/../obs-build-dependencies/Qt_${WindowsQtVersion}/msvc2019$(if (${BuildArch} -eq "64-bit") { "_64" })"
    $DepsDirectory = "${CheckoutDir}/../obs-build-dependencies/dependencies${WindowsDepsVersion}/win$(if (${BuildArch} -eq "64-bit") { "64" } else { "32" })"
    $CmakePrefixPath = "${QtDirectory};${DepsDirectory}/bin;${DepsDirectory}"
    $BuildDirectoryActual = "plugin_${BuildDirectory}$(if (${BuildArch} -eq "64-bit") { "64" } else { "32" })"
    $GeneratorPlatform = "$(if (${BuildArch} -eq "64-bit") { "x64" } else { "Win32" })"

    $CmakeCommand = @(
        "-S . -B `"${BuildDirectoryActual}`"",
        "-G `"Visual Studio 16 2019`"",
        "-DCMAKE_SYSTEM_VERSION=`"${CmakeSystemVersion}`"",
        "-DCMAKE_GENERATOR_PLATFORM=`"${GeneratorPlatform}`"",
        "-DCMAKE_PREFIX_PATH=`"${CmakePrefixPath}`"",
        "-DENABLE_PLUGINS=OFF",
        "-DENABLE_UI=ON",
        "-DENABLE_SCRIPTING=OFF",
        "$(if (Test-Path Variable:$Quiet) { "-Wno-deprecated -Wno-dev --log-level=ERROR" })"
    )

    Invoke-Expression "cmake ${CmakeCommand}"

    Ensure-Directory ${ObsBuildDir}
}

function Build-OBS-Libs-Standalone {
    try {
        $CheckoutDir = Invoke-Expression "git rev-parse --show-toplevel"
    } Catch {
        Write-Failure "Not a git checkout or no git client installed. Please install git on your system and use a git checkout to use this build script."
        exit 1
    }

    if (Test-Path ${CheckoutDir}/CI/include/build_environment.ps1) {
        . ${CheckoutDir}/CI/include/build_environment.ps1
    }

    $ObsBuildDir = "${CheckoutDir}/../obs-studio"

    . ${CheckoutDir}/CI/include/build_support_windows.ps1

    Build-OBS-Libs
}

function Print-Usage {
    $Lines = @(
        "Usage: ${_ScriptName}",
        "-Help                    : Print this help",
        "-Quiet                   : Suppress most build process output",
        "-Verbose                 : Enable more verbose build process output",
        "-BuildDirectory          : Directory to use for builds - Default: build64 on 64-bit systems, build32 on 32-bit systems",
        "-BuildArch               : Build architecture to use (32bit or 64bit) - Default: local architecture",
        "-BuildConfiguration      : Build configuration to use - Default: RelWithDebInfo"
    )

    $Lines | Write-Host
}

if(!(Test-Path variable:_RunObsBuildScript)) {
    $_ScriptName = "$($MyInvocation.MyCommand.Name)"
    if($Help.isPresent) {
        Print-Usage
        exit 0
    }

    Build-OBS-Libs-Standalone
}
