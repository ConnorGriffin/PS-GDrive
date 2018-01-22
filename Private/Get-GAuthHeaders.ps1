function Get-GAuthHeaders {
    <#
    .SYNOPSIS
        Return headers for authenticating to Google's API
    #>

    # TODO: Make parameters mandatory

    [CmdletBinding()]
    Param(
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret,
        [String]$Proxy
    )

    # Get an access token
    $gAuthParam = @{
        RefreshToken = $RefreshToken
        ClientID = $ClientID
        ClientSecret = $ClientSecret
    }
    $accessToken = Get-GAuthToken @gAuthParam

    Return @{
        "Authorization" = "Bearer $($accessToken.access_token)"
        "Content-type" = "application/json"
    }
}
