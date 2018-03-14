function Invoke-PaginatedRestMethod {
    [CmdletBinding()]
    Param(
        $Uri,
        $Method
    )
    do {
       $r = Invoke-RestMethod -Uri "$Uri$nextPage" -Method $Method
       $r
       $nextToken = $r.nextPageToken
       if ($Uri -like '*`?*') {
           $nextPage = "&pageToken=$nextToken"
       }
       else {
           $nextPage = "?pageToken=$nextToken"
       }
   } while ($nextToken)
}
