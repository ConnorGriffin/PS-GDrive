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

    Write-Verbose "Split the path into individual folder names"
    $pathArray = $Path.Trim('/').Split('/',[System.StringSplitOptions]::RemoveEmptyEntries)

    Write-Verbose "Create a new API session"
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    $headers = Get-GAuthHeaders @gAuthParam
    $baseUri = 'https://www.googleapis.com/drive/v3'

    if ($TeamDriveName) {
        Write-Verbose "Lookup all team drives, find the specified teamdrive by name, select the ID"
        $r = Invoke-RestMethod -Uri "$baseUri/teamdrives?fields=teamDrives(id,name)" -Method Get -Headers $headers
        $teamDriveId = $r.teamDrives.Where{$_.name -eq $TeamDriveName}.id

        Write-Verbose "Set the files.list parameters"
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

    Write-Verbose "Determine the target folder ID, create the path if it does not exist"
    if ($TeamDriveName) {$parentId = $teamDriveId}
    else {$parentid = 'root'}
    $pathArray.ForEach{
        $folderName = $_

        Write-Verbose "List items with parentId from the previous iteration"
        $newParams = $params
        $newParams += "q=parents+in+'$parentId'"
        $r = Invoke-RestMethod -Uri "$baseUri/files?$($newParams -join '&')" -Method Get -Headers $headers

        Write-Verbose "Find the matching folder"
        $matchingFolder = $r.files.Where{
            $_.mimeType -eq 'application/vnd.google-apps.folder' -and
            $_.name -eq $folderName
        }

        Write-Verbose "Set the parentId, create the folder if it doesn't exist"
        if ($matchingFolder) {
            $parentId = $matchingFolder.Id
        }
        else {
            Write-Verbose "Setup the folder creation request body"
            $body = @{
                name = $folderName
                mimeType = 'application/vnd.google-apps.folder'
                parents = @($parentId)
            }

            Write-Verbose "Add context-specific parameters"
            if ($TeamDriveName) {
                $body.Add('teamDriveId',$teamDriveId)
                $supportsTeamDrives = 'true'
            }
            else {
                $supportsTeamDrives = 'false'
            }

            Write-Verbose "Convert the body to JSON"
            $bodyJson = $body | ConvertTo-Json

            Write-Verbose "Create the folder, set the parentId"
            $r = Invoke-RestMethod -Uri "$baseUri/files?supportsTeamDrives=$supportsTeamDrives" -Method Post -Headers $headers -Body $bodyJson
            $parentId = $r.id
        }
    }

    Write-Verbose "Return the created folder details"
    if ($ItemType -eq 'Directory') {
        Return $r
    }
    #Write-Verbose "Upload the specified file"
    else {
        Write-Verbose "Get the source file contents"
        $sourceItem = Get-Item $sourceFile
        #$sourceBytes = Get-Content $sourceItem.FullName -Raw -ReadCount 0
        #$sourceBytes = [System.IO.File]::ReadAllBytes($sourceItem.FullName)
        $sourceBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourceItem.FullName))
        $sourceMime = [System.Web.MimeMapping]::GetMimeMapping($sourceItem.FullName)

        Write-Verbose "Set the file metadata"
        $uploadMetadata = @{
            originalFilename = $sourceItem.Name
            parents = @($parentId)
            description = $sourceItem.VersionInfo.FileDescription
        }

        # If specified, use $name for the file name in Google
        if ($Name) {$uploadMetadata['name'] = $Name}
        else {$uploadMetadata['name'] = $sourceItem.Name}

        Write-Verbose "Insert the metadata, data, and MIME into the multipart body"
        $uploadBody = Get-Content ~\Git-Repos\SO-Scripts\PSModules\GDrive\GDrive\Resources\multipart.txt -Raw
        $uploadBody = $uploadBody.Replace('$metadata',($uploadMetadata | ConvertTo-Json))
        $uploadBody = $uploadBody.Replace('$mime',$sourceMime).Replace('$data',$sourceBase64)

        $uploadHeaders = @{
            "Authorization" = $headers.Authorization
            "Content-Type" = 'multipart/related; boundary=boundary'
            "Content-Length" = $uploadBody.Length
        }

        Write-Verbose "Upload the file"
        $r = Invoke-RestMethod -Uri "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart" -Method Post -Headers $uploadHeaders -Body ($uploadBody -join "`n")
        Return $r
    }
}
