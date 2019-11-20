function Get-GAuthToken {
    <#
    .SYNOPSIS
        Return an access_token for the Google API
    #>

    # TODO: Make parameters mandatory

    [CmdletBinding()]
    Param(
        [String]$RefreshToken,
        [String]$ClientID,
        [String]$ClientSecret,
        [String]$Proxy
    )

    $params = @{
        Uri = 'https://accounts.google.com/o/oauth2/token'
        Body = @(
            "refresh_token=$RefreshToken",
            "client_id=$ClientID",
            "client_secret=$ClientSecret",
            "grant_type=refresh_token"
        ) -join '&'
        Method = 'Post'
        ContentType = 'application/x-www-form-urlencoded'
    }
    if ($Proxy) {
        $params['Proxy'] = $Proxy
    }

    Invoke-RestMethod @params
}
