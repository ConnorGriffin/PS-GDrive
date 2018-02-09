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

# Set module variables
$moduleRoot = $PSScriptRoot
$baseUri = 'https://www.googleapis.com/drive/v3'
$uploadUri = 'https://www.googleapis.com/upload/drive/v3'

# Create Profiles path if it does not exist
$profilePath = "$ENV:APPDATA\PSModules\GDrive"
if (!(Test-Path $profilePath)) {
    New-Item -Path $profilePath -Type Directory | Out-Null
}

# Import the config, if one has been set
if (Test-Path "$profilePath\GDriveAuth.xml") {
    $gAuth = Import-Clixml "$profilePath\GDriveAuth.xml"

    # Set default parameters for the rest of the script functions
    $global:PSDefaultParameterValues['*GDrive*:RefreshToken'] = $gAuth.RefreshToken
    $global:PSDefaultParameterValues['*GAuth*:RefreshToken'] = $gAuth.RefreshToken

    $global:PSDefaultParameterValues['*GDrive*:ClientID'] = $gAuth.ClientID
    $global:PSDefaultParameterValues['*GAuth*:ClientID'] = $gAuth.ClientID

    $global:PSDefaultParameterValues['*GDrive*:ClientSecret'] = $gAuth.ClientSecret
    $global:PSDefaultParameterValues['*GAuth*:ClientSecret'] = $gAuth.ClientSecret

    if($gAuth.Proxy) {
        $global:PSDefaultParameterValues['*GDrive*:Proxy'] = $gAuth.Proxy
        $global:PSDefaultParameterValues['*GAuth*:Proxy'] = $gAuth.Proxy
    }
}
