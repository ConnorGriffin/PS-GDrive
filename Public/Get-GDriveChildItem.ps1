Function Get-GDriveChildItem {
    <#
    .SYNOPSIS
        List files in Google Drive using the drive API, supports Team Drives
    .PARAMETER Path
        Specifies a path to one or more locations. Wildcards are permitted. The default location is the root directory.
    .PARAMETER TeamDriveName
        Specifies the Team Drive to download the file from.

        If not included, 'My Drive' is used, rather than a team drive.
    .PARAMETER Recurse
        If specified, items in child directories will be listed.
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
        [String]$Path='*',
        [String]$TeamDriveName,
        [Switch]$Recurse,
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret,
        [String]$Proxy
    )

    # Sets path to * if the provided path is one of: (blank),\,/
    if ($Path -match '^\\$|^/$|^$') {
        $Path = '*'
    }

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

    # Split the path into individual folder names
    $pathArray = $Path.Trim('/\').Split('/\',[System.StringSplitOptions]::RemoveEmptyEntries)

    # If the last part of the path contains a wildcard, make that a filter, not a part of the path
    if ($pathArray[$pathArray.Count-1].Contains('*')) {
        if ($pathArray.Count -le 1) {
            $nameFilter = $pathArray[$pathArray.Count-1]
            $pathArray = $null
        }
        else {
            $nameFilter = $pathArray[$pathArray.Count-1]
            $pathArray = $pathArray[0..($pathArray.Count-2)]
        }
    } else {
        $nameFilter = '*'
    }

    # Get the team drive details if a TeamDriveName is specified
    if ($TeamDriveName) {
        # Set for future API calls
        $supportsTeamDrives = 'true'

        # Lookup all team drives, find the specified teamdrive by name, select the ID
        $r = Invoke-PaginatedRestMethod -Uri "$baseUri/teamdrives?fields=nextPageToken,teamDrives(id,name)" -Method Get
        $teamDriveId = $r.teamDrives.Where{$_.name -eq $TeamDriveName}.id

        # Set the files.list call parameters
        $params = @(
            'corpora=teamDrive',
            'includeTeamDriveItems=true',
            'supportsTeamDrives=true'
            "teamDriveId=$teamDriveId"
            'fields=nextPageToken,files(id%2CmimeType%2Cname%2Cparents)'
        )
    }
    else {
        # Set the files.list call parameters
        $supportsTeamDrives = 'false'
        $params = @(
            'corpora=user'
            'fields=nextPageToken,files(id%2CmimeType%2Cname%2Cparents)'
        )

        # Get the "shared with me" items to start
        $newParams = $params
        $newParams += 'q=trashed%3Dfalse and sharedWithMe%3Dtrue'
        $sharedItems = Invoke-PaginatedRestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get
    }

    # Determine the target folder ID, create the path if it does not exist
    if ($supportsTeamDrives -eq 'true') {$parentId = $teamDriveId}
    else {$parentid = 'root'}

    # Iterate through each part of the path, getting the next level until we reach the bottom
    foreach ($pathItem in $pathArray) {
        # List items with parentId from the previous iteration
        $newParams = $params
        $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"
        $r = Invoke-PaginatedRestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get
        
        if ($pathArray.IndexOf($pathItem) -eq 0 -and $sharedItems) {
            $r.files += $sharedItems.files
        }

        # Find the matching folder
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $pathItem
        }

        # Set the parentId for the next loop or part of the script
        if ($matchingFolder) {
            $parentId = $matchingFolder.Id
        }
        else {
            Write-Error "Unable to find $Path"
        }
    }

    # Now that we have a parentId, list the files
    $newParams = $params
    $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"

    # Add the results to a PSObject
    $files = @()
    if ($sharedItems -and !$pathArray) {
        $files += $sharedItems.files
    }
    $files += (Invoke-PaginatedRestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get).files

    # If Recurse is specified, reprocess for each folder in the current path
    if ($Recurse) {
        $folders = [Array]$files.Where{$_.mimeType -eq 'application/vnd.google-apps.folder'}
        $folders.ForEach{
            $recurseParams = $PSBoundParameters
            $recurseParams['Path'] = "$($pathArray -join '\')\$($_.name)"
            $files += Get-GDriveChildItem @recurseParams
        }
    }

    # Output a filtered list of files
    Return $files.Where{$_.name -like $nameFilter}
}
