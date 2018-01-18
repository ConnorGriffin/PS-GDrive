Function Get-GAuthProfile {
    <#
    .SYNOPSIS
        Retrieve your Google API OAuth2 info from an encrypted .xml file
    #>

    [CmdletBinding()]
    Param()

    Import-Clixml "$profilePath\GDriveAuth.xml"
}
