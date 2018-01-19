Function Initialize-GAuthProfile {
    <#
    .SYNOPSIS
        Reload the GAuthProfile, prompts to create if one does not exist
    #>

    [CmdletBinding()]
    Param()

    # Create the GAuthProfile if it does not exist, then import it
    $gAuthProfileExists = Test-Path "$profilePath\GDriveAuth.xml"
    if (!$gAuthProfileExists) {
        Set-GAuthProfile
    }
    # Scope gAuthParam to script:, which sets it globally within the function
    $script:gAuthParam = Get-GAuthProfile
}
