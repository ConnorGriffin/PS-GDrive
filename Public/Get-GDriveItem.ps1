Function Get-GDriveItem {
    <#
    .SYNOPSIS
        Get files from Google Drive using the drive API, supports Team Drives
    .PARAMETER Path
        Specifies the path of the location of the item to download.

        You can specify the name of the download item in Name, or include it in Path.
    .PARAMETER Name
        Specifies the name of the item to download.

        You can specify the name of the download item in Name, or include it in Path.
    .PARAMETER TeamDriveName
        Specifies the Team Drive to download the file from.

        If not included, 'My Drive' is used, rather than a team drive.
    .PARAMETER Recurse
        If specified, items in child directories will be downloaded.
    .PARAMETER DestinationPath
        Specifies where the downloaded files will be placed. Path only, the files name in Drive will be used.
    .PARAMETER RefreshToken
        Google API RefreshToken.
    .PARAMETER ClientID
        Google API ClientID.
    .PARAMETER ClientSecret
        Google API ClientSecret.
    .PARAMETER Proxy
        Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    #>

    # TODO: Add FileID support (download by specifying a file ID)
    # TODO: Add recurse support, download entire directory including children

    [CmdletBinding(DefaultParameterSetName='ByPath')]
    Param(
        [String]$TeamDriveName,

        [Parameter(Mandatory=$true,ParameterSetName='ByPath')]
        [String]$Path,

        [Parameter(Mandatory=$true,ParameterSetName='ByName')]
        [String]$Name,

        [Parameter(ParameterSetName='ByName')]
        [Parameter(ParameterSetName='ByPath')]
        [Switch]$Recurse,

        #[Parameter(Mandatory=$true,ParameterSetName='ById')]
        #[String[]]$FileId,

        [String]$DestinationPath='.',

        [String]$RefreshToken,

        [String]$ClientID,

        [String]$ClientSecret,

        [String]$Proxy
    )

    # Create a new API session, set session defaults
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    if ($Proxy) {
        $gAuthParam['Proxy'] = $Proxy
        $PSDefaultParameterValues['Invoke-RestMethod:Proxy'] = $Proxy
    }
    $headers = Get-GAuthHeaders @gAuthParam
    $PSDefaultParameterValues['Invoke-RestMethod:Headers'] = $headers

    # Set optional parameters for the Get-GDriveChildItem function call
    $childItemParams = @{}
    if ($Recurse) {$childItemParams['Recurse'] = $true}
    if ($TeamDriveName) {
        $supportsTeamDrives = 'true'
        $childItemParams['TeamDriveName'] = $TeamDriveName
    }
    else {$supportsTeamDrives = 'false'}

    [Array]$filesToDownload = Get-GDriveChildItem -Path "$Path\$Name" @childItemParams @gAuthParam

    # Download/export each file
    $filesToDownload.Where{$_.mimetype -ne 'application/vnd.google-apps.folder'}.ForEach{
        # Export google app files
        if ($_.mimetype -like 'application/vnd.google-apps.*') {
            # Determine which mimeType to use when exporting the files
            switch ($_.mimetype) {
                'application/vnd.google-apps.document' {$exportMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'}
                'application/vnd.google-apps.presentation' {$exportMime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'}
                'application/vnd.google-apps.spreadsheet' {$exportMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}
                'application/vnd.google-apps.drawings' {$exportMime = 'image/png'}
                'application/vnd.google-apps.script' {$exportMime = 'application/vnd.google-apps.script+json'}
            }
            $params = "supportsTeamDrives=$supportsTeamDrives&mimeType=$exportMime"
            Invoke-RestMethod -Uri "$baseUri/files/$($_.id)/export?$params" -Method Get -OutFile "$DestinationPath\$($_.name)"
        }
        # Download binary files
        else {
            Invoke-RestMethod -Uri "$baseUri/files/$($_.id)?supportsTeamDrives=$supportsTeamDrives&alt=media" -Method Get -OutFile "$DestinationPath\$($_.name)"
        }

        # Return the exported file
        Get-Item "$DestinationPath\$($_.name)"
    }
}
