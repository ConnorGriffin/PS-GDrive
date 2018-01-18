Function New-GDriveItem {
    <#
    .SYNOPSIS
        Uploads files to Google Drive using the drive API, supports Team Drives
    #>

    # TODO: Add -Value support, setting content of a created file
    # TODO: Better error handling (e.g.: if a Teamdrive doesn't exist, error out)
    # TODO: Check for conflicting options (Directory, SourceFile), error out preemptively
    # TODO: Return better data, path to file, etc.

    [CmdletBinding()]
    Param(
        [String]$Path,
        [String]$Name,
        [ValidateSet('Directory','File')][String]$ItemType,
        [String]$SourceFile,
        [String]$TeamDriveName,
        [Bool]$UseContentAsIndexableText=$true,
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret
    )

    # Split the path into individual folder names
    $pathArray = $Path.Trim('/\').Split('/\',[System.StringSplitOptions]::RemoveEmptyEntries)

    # Determine ItemType if not specified
    if (!$ItemType -and $SourceFile) {$ItemType = 'File'}
    else {$ItemType = 'Directory'}

    if ($Name -and $ItemType -eq 'Directory') {
        $pathArray += $Name
        Write-Verbose ($pathArray -join '/')
    }

    # Create a new API session
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    $headers = Get-GAuthHeaders @gAuthParam
    $baseUri = 'https://www.googleapis.com/drive/v3'
    $uploadUri = 'https://www.googleapis.com/upload/drive/v3'

    # Get the team drive details if a TeamDriveName is specified
    if ($TeamDriveName) {
        # Set for future API calls
        $supportsTeamDrives = 'true'

        # Lookup all team drives, find the specified teamdrive by name, select the ID
        $r = Invoke-RestMethod -Uri "$baseUri/teamdrives?fields=teamDrives(id,name)" -Method Get -Headers $headers
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

    # Iterate through each part of the path, create the folder if it does not exist
    foreach ($folderName in $pathArray) {
        # List items with parentId from the previous iteration
        $newParams = $params
        $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"
        $r = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get -Headers $headers

        # Find the matching folder
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $folderName
        }

        # Set the parentId, create the folder if it doesn't exist
        if ($matchingFolder) {
            $parentId = $matchingFolder.Id
        }
        else {
            # Setup the folder creation request body
            $body = @{
                name = $folderName
                mimeType = 'application/vnd.google-apps.folder'
                parents = @($parentId)
            }

            # Add context-specific parameters
            if ($supportsTeamDrives) {$body['teamDriveId'] = $teamDriveId}

            # Convert the body to JSON
            $bodyJson = $body | ConvertTo-Json

            # Create the folder, set the parentId, return the object details
            $r = Invoke-RestMethod -Uri "$baseUri/files?supportsTeamDrives=$supportsTeamDrives" -Method Post -Headers $headers -Body $bodyJson
            $parentId = $r.id
            $r
        }
    }

    # If a file is specified, upload it
    if ($ItemType -eq 'File' -and $SourceFile) {
        # Get the source file contents
        $sourceItem = Get-Item $sourceFile
        $sourceBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourceItem.FullName))
        $sourceMime = [System.Web.MimeMapping]::GetMimeMapping($sourceItem.FullName)

        # Set the file metadata
        $uploadMetadata = @{
            originalFilename = $sourceItem.Name
            parents = @($parentId)
            description = $sourceItem.VersionInfo.FileDescription
            useContentAsIndexableText = $UseContentAsIndexableText
        }

        # Add context-specific parameters
        if ($supportsTeamDrives) {$uploadMetadata['teamDriveId'] = $teamDriveId}
        if ($Name) {$uploadMetadata['name'] = $Name}
        else {$uploadMetadata['name'] = $sourceItem.Name}

        # Insert the metadata, data, and MIME into the multipart body
        $uploadBody = Get-Content ~\Git-Repos\SO-Scripts\PSModules\GDrive\GDrive\Resources\multipart.txt -Raw
        $uploadBody = $uploadBody.Replace('$metadata',($uploadMetadata | ConvertTo-Json))
        $uploadBody = $uploadBody.Replace('$mime',$sourceMime).Replace('$data',$sourceBase64)

        # Set the upload headers
        $uploadHeaders = @{
            "Authorization" = $headers.Authorization
            "Content-Type" = 'multipart/related; boundary=boundary'
            "Content-Length" = $uploadBody.Length
        }

        # Upload the file, return the object details
        $r = Invoke-RestMethod -Uri "$uploadUri/files?supportsTeamDrives=$supportsTeamDrives&uploadType=multipart" -Method Post -Headers $uploadHeaders -Body $uploadBody
        $r
    }
}
