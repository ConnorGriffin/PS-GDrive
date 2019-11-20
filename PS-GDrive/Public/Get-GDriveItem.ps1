Function Get-GDriveItem {
    <#
    .SYNOPSIS
        Get files from Google Drive using the drive API, supports Shared Drives
    .PARAMETER Path
        Specifies the path of the location of the item to download.

        You can specify the name of the download item in Name, or include it in Path.
    .PARAMETER Name
        Specifies the name of the item to download.

        You can specify the name of the download item in Name, or include it in Path.
    .PARAMETER DriveName
        Specifies the Shared Drive to download the file from.

        If not included, 'My Drive' is used, rather than a shared drive.
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
        [String]$DriveName,

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
    if ($DriveName) {
        $supportsAllDrives = 'true'
        $childItemParams['DriveName'] = $DriveName
    }
    else {$supportsAllDrives = 'false'}

    [Array]$filesToDownload = Get-GDriveChildItem -Path "$Path\$Name" @childItemParams @gAuthParam

    # If Name is specified, filter for that name
    if ($Name) {
        [Array]$filesToDownload = $filesToDownload.Where{$_.Name -like $Name}
    }

    <# If the last part of the path matches the name of a file, assume that's what we intend to download
       This is needed because gsuite native formts (gsheet, gdoc, etc.) don't have extensions in the name
       As a result, the Get-GDriveChildItem function thinks they're folders, and returns odd results #>
    $pathArray = $Path.Trim('/\').Split('/\',[System.StringSplitOptions]::RemoveEmptyEntries)
    $lastPath = $pathArray[$pathArray.Count-1]
    [Array]$itemMatchesLastPath = $filesToDownload.Where{$_.Name -like $lastPath}
    if ($itemMatchesLastPath) {
        [Array]$filesToDownload = $filesToDownload.Where{$_.Name -like $lastPath}
    }

    # Download/export each file
    $filesToDownload.Where{$_.mimetype -ne 'application/vnd.google-apps.folder'}.ForEach{
        # Export google app files
        if ($_.mimetype -like 'application/vnd.google-apps.*') {
            # Determine which mimeType to use when exporting the files
            switch ($_.mimetype) {
                'application/vnd.google-apps.document' {
                    $exportMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                    $exportExt = '.docx'
                }
                'application/vnd.google-apps.presentation' {
                    $exportMime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
                    $exportExt = '.pptx'
                }
                'application/vnd.google-apps.spreadsheet' {
                    $exportMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                    $exportExt = '.xlsx'
                }
                'application/vnd.google-apps.drawings' {
                    $exportMime = 'image/png'
                    $exportExt = '.png'
                }
                'application/vnd.google-apps.script' {
                    $exportMime = 'application/vnd.google-apps.script+json'
                    $exportExt = '.json'
                }
            }
            $params = "supportsAllDrives=$supportsAllDrives&mimeType=$exportMime"
            $exportFileName = "$DestinationPath\$($_.name)$exportExt"
            Invoke-RestMethod -Uri "$baseUri/files/$($_.id)/export?$params" -Method Get -OutFile $exportFileName

        }
        # Download binary files
        else {
            $exportFileName = "$DestinationPath\$($_.name)"
            Invoke-RestMethod -Uri "$baseUri/files/$($_.id)?supportsAllDrives=$supportsAllDrives&alt=media" -Method Get -OutFile $exportFileName
        }

        # Return the exported file
        Get-Item $exportFileName
    }
}
