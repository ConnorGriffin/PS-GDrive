# Install required modules
$psd1 = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName (Get-ChildItem -Path $PSScriptRoot\*.psd1).Name
$requiredModules = $psd1.PrivateData.PSData.ExternalModuleDependencies
foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable $module
    if (!$installed) {
        Install-Module $module -Scope CurrentUser -Force
    }
}

# Get public and private function definition files.
$functions  = Get-ChildItem -Path $PSScriptRoot\*\*.ps1 -ErrorAction SilentlyContinue

# Dot source the files
$functions.ForEach{
    try {. $_.FullName}
    catch {Write-Error -Message "Failed to import function $($_.FullName)"}
}

$moduleRoot = $PSScriptRoot

# Create Profiles path if it does not exist
$profilePath = "$ENV:APPDATA\PSModules\GDrive"
if (!(Test-Path $profilePath)) {
    New-Item -Path $profilePath -Type Directory | Out-Null
}

# Load/reload the GAuthProfile
Initialize-GAuthProfile
