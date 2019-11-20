Function Get-GAuthProfile {
    <#
    .SYNOPSIS
        Retrieve your Google API OAuth2 info from an encrypted .xml file, adds to PSDefaultParameterValues.
    #>

    [CmdletBinding()]
    Param()

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
