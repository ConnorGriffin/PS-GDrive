Function Set-GAuthProfile {
    <#
    .SYNOPSIS
        Saves your Google API OAuth2 info to an encrypted .xml file
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$RefreshToken,
        [Parameter(Mandatory=$true)][String]$ClientID,
        [Parameter(Mandatory=$true)][String]$ClientSecret,
        [String]$Proxy
    )

    $authData = [PSCustomObject]@{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    if ($Proxy) {
        $authData['Proxy'] = $Proxy
    }
    
    $authData | Export-Clixml "$profilePath\GDriveAuth.xml"
}
