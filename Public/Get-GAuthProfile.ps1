Function Get-GAuthProfile {
    <#
    .SYNOPSIS
        Retrieve your Google API OAuth2 info from an encrypted .xml file, adds to PSDefaultParameterValues.
    #>

    [CmdletBinding()]
    Param()

    $gAuth = Import-Clixml "$profilePath\GDriveAuth.xml"

    # Set default parameters for the rest of the script functions
    $global:PSDefaultParameterValues['*:RefreshToken'] = $gAuth.RefreshToken
    $global:PSDefaultParameterValues['*:ClientID'] = $gAuth.ClientID
    $global:PSDefaultParameterValues['*:ClientSecret'] = $gAuth.ClientSecret

    if($gAuth.Proxy) {
        $global:PSDefaultParameterValues['*GDrive*:Proxy'] = $gAuth.Proxy
        $global:PSDefaultParameterValues['*GAuth*:Proxy'] = $gAuth.Proxy
    }
}
