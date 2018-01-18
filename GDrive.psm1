# Create Profiles path if it does not exist
$profilePath = "$ENV:APPDATA\PSModules\GDrive"
if (!(Test-Path $profilePath)) {
    New-Item -Path $profilePath -Type Directory | Out-Null
}

$gAuthProfileExists = Test-Path "$profilePath\GDriveAuth.xml"
if (!$gAuthProfileExists) {
    Set-GAuthProfile
}
$gAuthParam = Get-GAuthProfile
