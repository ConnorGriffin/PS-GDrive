Function Initialize-GAuthProfile {
    <#
    .SYNOPSIS
        Reload the GAuthProfile, prompts to create if one does not exist.
    #>

    [CmdletBinding()]
    Param()

    # Create the GAuthProfile if it does not exist, then import it
    $gAuth = Get-GAuthProfile -ErrorAction SilentlyContinue
    if (!$gAuth) {
        Set-GAuthProfile
    }

    # Set default parameters for the rest of the script functions
    $Global:PSDefaultParameterValues['*GDrive*:RefreshToken'] = $gAuth.RefreshToken
    $Global:PSDefaultParameterValues['*GDrive*:ClientID'] = $gAuth.ClientID
    $Global:PSDefaultParameterValues['*GDrive*:ClientSecret'] = $gAuth.ClientSecret
}
