Function New-GDriveItem {
    <#
    .SYNOPSIS
        Uploads files to Google Drive using the drive API, supports Shared Drives
    .PARAMETER Path
        Specifies the path of the location of the new item.

        You can specify the name of the new item in Name, or include it in Path (Directories only).
    .PARAMETER Name
        Specifies the name of the new item.

        If not specified, the item's filename will be used
    .PARAMETER ItemType
         Specifies the provider-specified type of the new item.

         Options are File and Directory.
    .PARAMETER SourceFile
        Specifies the file to upload to the specified path (File ItemType only).
    .PARAMETER DriveName
        Specifies the Shared Drive to upload the documents to.

        If not included, 'My Drive' is used, rather than a shared drive.
    .PARAMETER UseContentAsIndexableText
        Specifies whether or not the file content should be indexed by Google Drive.
    .PARAMETER RefreshToken
        Google API RefreshToken.
    .PARAMETER ClientID
        Google API ClientID.
    .PARAMETER ClientSecret
        Google API ClientSecret.
    .PARAMETER Proxy
        Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    #>

    # TODO: Add -Value support, setting content of a created file
    # TODO: Better error handling (e.g.: if a Shared Drive doesn't exist, error out)
    # TODO: Check for conflicting options (Directory, SourceFile), error out preemptively
    # TODO: Return better data, path to file, etc.
    # TODO: Make Name and Path interchangeable, like the way New-Item works

    [CmdletBinding()]
    Param(
        [String]$Path,
        [String]$Name,
        [ValidateSet('Directory','File')][String]$ItemType,
        [String]$SourceFile,
        [String]$DriveName,
        [Bool]$UseContentAsIndexableText=$true,
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret,
        [String]$Proxy
    )

    # Split the path into individual folder names
    $pathArray = $Path.Trim('/\').Split('/\',[System.StringSplitOptions]::RemoveEmptyEntries)

    # Determine ItemType if not specified
    if (!$ItemType -and $SourceFile) {
        $ItemType = 'File'
    }
    elseif (!$ItemType) {
        $ItemType = 'Directory'
    }

    # Add the name to the path if the itemtype is Directory
    if ($Name -and $ItemType -eq 'Directory') {
        $pathArray += $Name
        Write-Verbose ($pathArray -join '/')
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

    # Get the shared drive details if a DriveName is specified
    if ($DriveName) {
        # Set for future API calls
        $supportsAllDrives = 'true'

        # Lookup all shared drives, find the specified shared drive by name, select the ID
        $r = Invoke-PaginatedRestMethod -Uri "$baseUri/drives?fields=nextPageToken,drives(id,name)" -Method Get
        $driveId = $r.drives.Where{$_.name -eq $DriveName}.id

        # Set the files.list call parameters
        $params = @(
            'corpora=drive',
            'includeItemsFromAllDrives=true',
            'supportsAllDrives=true'
            "driveId=$driveId"
            'fields=nextPageToken,files(id%2CmimeType%2Cname%2Cparents)'
        )
    }
    else {
        # Set for future API calls
        $supportsAllDrives = 'false'
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
    if ($supportsAllDrives -eq 'true') {$parentId = $driveId}
    else {$parentid = 'root'}

    # Iterate through each part of the path, create the folder if it does not exist
    foreach ($folderName in $pathArray) {
        # List items with parentId from the previous iteration
        $newParams = $params
        $newParams += "q=trashed%3Dfalse and parents+in+'$parentId'"
        $r = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get

        if ($pathArray.IndexOf($folderName) -eq 0 -and $sharedItems) {
            $r.files += $sharedItems.files
        }

        # Find the matching folder
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $folderName
        }[0]

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
            if ($supportsAllDrives) {$body['driveId'] = $driveId}

            # Convert the body to JSON
            $bodyJson = $body | ConvertTo-Json

            # Create the folder, set the parentId, return the object details
            $r = Invoke-RestMethod -Uri "$baseUri/files?supportsAllDrives=$supportsAllDrives" -Method Post -Body $bodyJson
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
        if ($supportsAllDrives) {$uploadMetadata['driveId'] = $driveId}
        if ($Name) {$uploadMetadata['name'] = $Name}
        else {$uploadMetadata['name'] = $sourceItem.Name}

        # Insert the metadata, data, and MIME into the multipart body
        $uploadBody = Get-Content "$moduleRoot\Resources\multipart.txt" -Raw
        $uploadBody = $uploadBody.Replace('$metadata',($uploadMetadata | ConvertTo-Json))
        $uploadBody = $uploadBody.Replace('$mime',$sourceMime).Replace('$data',$sourceBase64)

        # Set the upload headers
        $uploadHeaders = @{
            "Authorization" = $headers.Authorization
            "Content-Type" = 'multipart/related; boundary=boundary'
            "Content-Length" = $uploadBody.Length
        }

        # Upload the file, return the object details
        $r = Invoke-RestMethod -Uri "$uploadUri/files?supportsAllDrives=$supportsAllDrives&uploadType=multipart" -Method Post -Headers $uploadHeaders -Body $uploadBody
        $r
    }
}
