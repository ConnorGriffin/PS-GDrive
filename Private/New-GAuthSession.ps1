function New-GAuthSession {
    <#
    .SYNOPSIS
        Establish a session with the Google API
    #>

    # TODO: Make parameters mandatory

    [CmdletBinding()]
    Param(
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret
    )

    # Get an access token
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    $accessToken = Get-GAuthToken @gAuthParam

    # Set the API URL and header defaults
    $baseUri = 'https://www.googleapis.com/drive/v3'
    $headers = @{"Authorization" = "Bearer $($accessToken.access_token)"
                  "Content-type" = "application/json"}
    $PSDefaultParameterValues.Remove('Invoke-RestMethod:Headers')
    $PSDefaultParameterValues.Add('Invoke-RestMethod:Headers',$headers)
}
