Function New-GDriveItem {
    <#
    .SYNOPSIS
        Uploads files to Google Drive using the drive API, supports Team Drives
    #>

    [CmdletBinding()]
    Param(
        [String]$Path,
        [String]$Name,
        [String]$SourceFile,
        [ValidateSet('Directory','File')][String]$ItemType,
        [String]$TeamDriveName,
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret
    )

    # Split the path into individual folder names
    $pathArray = $Path.Trim('/').Split('/',[System.StringSplitOptions]::RemoveEmptyEntries)

    # Create a new API session
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    $headers = Get-GAuthHeaders @gAuthParam
    $baseUri = 'https://www.googleapis.com/drive/v3'
    $uploadUri = 'https://www.googleapis.com/upload/drive/v3'

    if ($TeamDriveName) {
        # Lookup all team drives, find the specified teamdrive by name, select the ID
        $r = Invoke-RestMethod -Uri "$baseUri/teamdrives?fields=teamDrives(id,name)" -Method Get -Headers $headers
        $teamDriveId = $r.teamDrives.Where{$_.name -eq $TeamDriveName}.id

        # Set the files.list parameters
        $params = @(
            'corpora=teamDrive',
            'includeTeamDriveItems=true',
            'supportsTeamDrives=true'
            "teamDriveId=$teamDriveId"
            'fields=files(id%2CmimeType%2Cname%2Cparents)'
        )
    }
    else {
        $params = @(
            'corpora=user'
            'fields=files(id%2CmimeType%2Cname%2Cparents)'
        )
    }

    # Determine the target folder ID, create the path if it does not exist
    if ($TeamDriveName) {$parentId = $teamDriveId}
    else {$parentid = 'root'}
    $pathArray.ForEach{
        $name = $_

        # List items with parentId from the previous iteration
        $newParams = $params
        $newParams += "q=parents+in+'$parentId'"
        $r = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get -Headers $headers

        # Find the matching folder
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $name
        }

        # Set the parentId, create the folder if it doesn't exist
        if ($matchingFolder) {
            $parentId = $matchingFolder.Id
        }
        else {
            # Setup the folder creation request body
            $body = @{
                name = $name
                mimeType = 'application/vnd.google-apps.folder'
                parents = @($parentId)
            }

            # Add context-specific parameters
            if ($TeamDriveName) {
                $body.Add('teamDriveId',$teamDriveId)
                $supportsTeamDrives = 'true'
            }
            else {
                $supportsTeamDrives = 'false'
            }

            # Convert the body to JSON
            $bodyJson = $body | ConvertTo-Json

            # Create the folder, set the parentId
            $r = Invoke-RestMethod -Uri "$baseUri/files?supportsTeamDrives=$supportsTeamDrives" -Method Post -Headers $headers -Body $bodyJson
            $parentId = $r.id
        }
    }

    # Return the created folder details
    if ($ItemType -eq 'Directory') {
        Return $r
    }
    # Upload the specified file
    else {
        # Get the source file contents
        $sourceItem = Get-Item $sourceFile
        $sourceBytes = [System.IO.File]::ReadAllBytes($SourceItem.FullName)
        $sourceMime = [System.Web.MimeMapping]::GetMimeMapping([System.IO.FileInfo]$SourceItem.FullName)

#
$uploadBody= @"
--BOUNDARY
Content-Type: application/json; charset=UTF-8

{
  "name": "Test",
  "parents": [{
    "id":"$parentId"
    }],
  "description": "Test"
}
--BOUNDARY
Content-Type: $sourceMime

$source
--BOUNDARY--

"@

        $uploadHeaders = @{
            "Authorization" = $headers.Authorization
            "Content-type" = 'multipart/related; boundary="BOUNDARY"'
            "Content-Length" = $uploadBody.Length}

        # Upload the file
        $r = Invoke-RestMethod -Uri "$uploadUri/files?uploadType=multipart" -Method Post -Headers $uploadHeaders -Body $uploadBody
        Return $r
    }
}
