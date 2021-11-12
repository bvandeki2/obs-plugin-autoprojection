$CIWorkflow = "${CheckoutDir}/.github/workflows/main.yml"
$WorkflowContent = Get-Content ${CIWorkflow}

$CIDepsVersion = ${WorkflowContent} | Select-String "[ ]+DEPS_VERSION_WIN: '([0-9\-]+)'" | ForEach-Object{$_.Matches.Groups[1].Value}
$CIQtVersion = ${WorkflowContent} | Select-String "[ ]+QT_VERSION_WIN: '([0-9\.]+)'" | ForEach-Object{$_.Matches.Groups[1].Value}
$CIObsVersion = ${WorkflowContent} | Select-String "[ ]+OBS_VERSION: '([0-9\.]+)'" | ForEach-Object{$_.Matches.Groups[1].Value}

function Write-Status {
    param(
        [parameter(Mandatory=$true)]
        [string] $output
    )

    if (!($Quiet.isPresent)) {
        if (Test-Path Env:CI) {
            Write-Host "[${ProductName}] ${output}"
        } else {
            Write-Host -ForegroundColor blue "[${ProductName}] ${output}"
        }
    }
}

function Write-Info {
    param(
        [parameter(Mandatory=$true)]
        [string] $output
    )

    if (!($Quiet.isPresent)) {
        if (Test-Path Env:CI) {
            Write-Host " + ${output}"
        } else {
            Write-Host -ForegroundColor DarkYellow " + ${output}"
        }
    }
}

function Write-Step {
    param(
        [parameter(Mandatory=$true)]
        [string] $output
    )

    if (!($Quiet.isPresent)) {
        if (Test-Path Env:CI) {
            Write-Host " + ${output}"
        } else {
            Write-Host -ForegroundColor green " + ${output}"
        }
    }
}

function Write-Failure {
    param(
        [parameter(Mandatory=$true)]
        [string] $output
    )

    if (Test-Path Env:CI) {
        Write-Host " + ${output}"
    } else {
        Write-Host -ForegroundColor red " + ${output}"
    }
}

function Test-CommandExists {
    param(
        [parameter(Mandatory=$true)]
        [string] $Command
    )

    $CommandExists = $false
    $OldActionPref = $ErrorActionPreference
    $ErrorActionPreference = "stop"

    try {
        if (Get-Command $Command) {
            $CommandExists = $true
        }
    } Catch {
        $CommandExists = $false
    } Finally {
        $ErrorActionPreference = $OldActionPref
    }

    return $CommandExists
}

function Ensure-Directory {
    param(
        [parameter(Mandatory=$true)]
        [string] $Directory
    )

    if (!(Test-Path $Directory)) {
        $null = New-Item -ItemType Directory -Force -Path $Directory
    }

    Set-Location -Path $Directory
}

$BuildDirectory = "$(if (Test-Path Env:BuildDirectory) { $Env:BuildDirectory } else { $BuildDirectory })"
$BuildConfiguration = "$(if (Test-Path Env:BuildConfiguration) { $Env:BuildConfiguration } else { $BuildConfiguration })"
$BuildArch = "$(if (Test-Path Env:BuildArch) { $Env:BuildArch } else { $BuildArch })"
$OBSBranch = "$(if (Test-Path Env:OBSBranch) { $Env:OBSBranch } else { $OBSBranch })"
$WindowsDepsVersion = "$(if (Test-Path Env:WindowsDepsVersion ) { $Env:WindowsDepsVersion } else { $CIDepsVersion })"
$WindowsQtVersion = "$(if (Test-Path Env:WindowsQtVersion ) { $Env:WindowsQtVersion } else { $CIQtVersion })"
$CmakeSystemVersion = "$(if (Test-Path Env:CMAKE_SYSTEM_VERSION) { $Env:CMAKE_SYSTEM_VERSION } else { "10.0.18363.657" })"
$OBSVersion = "$(if ( Test-Path Env:OBSVersion ) { $Env:ObsVersion } else { $CIObsVersion })"

function Install-Windows-Dependencies {
    Write-Status "Checking Windows build dependencies"

    $ObsBuildDependencies = @(
        @("7z", "7zip"),
        @("cmake", "cmake --install-arguments 'ADD_CMAKE_TO_PATH=System'"),
        @("iscc", "innosetup")
    )

    if(!(Test-CommandExists "choco")) {
        Set-ExecutionPolicy AllSigned
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    Foreach($Dependency in $ObsBuildDependencies) {
        if($Dependency -is [system.array]) {
            $Command = $Dependency[0]
            $ChocoName = $Dependency[1]
        } else {
            $Command = $Dependency
            $ChocoName = $Dependency
        }

        if(!(Test-CommandExists "${Command}")) {
            Write-Step "Install dependency ${ChocoName}"
            Invoke-Expression "choco install -y ${ChocoName}"
        }
    }

    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
