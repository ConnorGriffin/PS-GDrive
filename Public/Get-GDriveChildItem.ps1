Function Get-GDriveChildItem {
    <#
    .SYNOPSIS
        List files in Google Drive using the drive API, supports Team Drives
    .PARAMETER Path
        Specifies the path of the location of the item to list.
    .PARAMETER TeamDriveName
        Specifies the Team Drive to download the file from.

        If not included, 'My Drive' is used, rather than a team drive.
    .PARAMETER RefreshToken
        Google API RefreshToken.
    .PARAMETER ClientID
        Google API ClientID.
    .PARAMETER ClientSecret
        Google API ClientSecret.
    .PARAMETER Proxy
        Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    #>

    [CmdletBinding()]
    Param(
        [String]$Path,
        [String]$TeamDriveName,
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

    # Set the google drive base URI
    $baseUri = 'https://www.googleapis.com/drive/v3'

    # Split the path into individual folder names
    $pathArray = $Path.Trim('/\').Split('/\',[System.StringSplitOptions]::RemoveEmptyEntries)

    # Get the team drive details if a TeamDriveName is specified
    if ($TeamDriveName) {
        # Set for future API calls
        $supportsTeamDrives = 'true'

        # Lookup all team drives, find the specified teamdrive by name, select the ID
        $r = Invoke-RestMethod -Uri "$baseUri/teamdrives?fields=teamDrives(id,name)" -Method Get
        $teamDriveId = $r.teamDrives.Where{$_.name -eq $TeamDriveName}.id

        # Set the files.list call parameters
        $params = @(
            'corpora=teamDrive',
            'includeTeamDriveItems=true',
            'supportsTeamDrives=true'
            "teamDriveId=$teamDriveId"
            'fields=files(id%2CmimeType%2Cname%2Cparents)'
        )
    }
    else {
        # Set for future API calls
        $supportsTeamDrives = 'false'
        $params = @(
            'corpora=user'
            'fields=files(id%2CmimeType%2Cname%2Cparents)'
        )
    }

    # Determine the target folder ID, create the path if it does not exist
    if ($supportsTeamDrives -eq 'true') {$parentId = $teamDriveId}
    else {$parentid = 'root'}

    # Iterate through each part of the path, getting the next level until we reach the bottom
    foreach ($folderName in $pathArray) {
        # List items with parentId from the previous iteration
        $newParams = $params
        $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"
        $r = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get

        # Find the matching folder
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $folderName
        }

        # Set the parentId for the next loop or part of the script
        if ($matchingFolder) {
            $parentId = $matchingFolder.Id
        }
    }

    # Now that we have a parentId, list the files
    $newParams = $params
    $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"
    $files = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get
    Return $files.files
}
