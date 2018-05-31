function Export-GSheet {
    <#
    .SYNOPSIS
        Exports a PSObject to Google Sheets
    .DESCRIPTION
        Long description
    .PARAMETER InputData
        Object to be converted to spreadsheet data.
    .PARAMETER SheetArray
        Array of Spreadsheet objects to be created as multiple sheets in a single workbook.
        Spreadsheet objects are created by passing the -ReturnSheet parameter with -InputData.
    .PARAMETER SpreadsheetName 
        Spreadsheet file name in Google Drive.
    .PARAMETER SheetName
        Sheet (tab) name.
    .PARAMETER NoHeader
        Do not output the header data to the sheet.
    .PARAMETER ExcludeProperty
        Exclude certain properties. Does not support wildcards.
    .PARAMETER ReturnSheet 
        Output the sheet object rather than uploading to Google Drive. 
        Output from this command can be used in the $Sheet variable to create a multi-sheet spreadsheet.
    .PARAMETER RefreshToken
        Google API RefreshToken.
    .PARAMETER ClientID
        Google API ClientID.
    .PARAMETER ClientSecret
        Google API ClientSecret.
    .PARAMETER Proxy
        Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding(DefaultParameterSetName='SingleSheet',
                   PositionalBinding=$false)]
    param (
        [Parameter(ParameterSetName='SingleSheet',
                   ValueFromPipeline=$true,
                   Mandatory=$true)]
        [Parameter(ParameterSetName='ReturnSheet',
                   ValueFromPipeline=$true,
                   Mandatory=$true)]
        [PSObject]
        $InputData,

        [Parameter(ParameterSetName='MultiSheet',
                   ValueFromPipeline=$true,
                   Mandatory=$true)]
        [PSObject[]]
        $SheetArray,

        [Parameter(Position=1,
                   ParameterSetName='SingleSheet')]
        [Parameter(Position=1,
                   ParameterSetName='ReturnSheet')]
        [String]
        $SheetName = 'Sheet1',

        [Parameter(Position=2,
                   ParameterSetName='SingleSheet')]
        [Parameter(Position=2,
                   ParameterSetName='MultiSheet')]
        [String]
        $SpreadsheetName,

        [Switch]
        $NoHeader,

        [String[]]
        $ExcludeProperty,

        [Parameter(ParameterSetName='ReturnSheet',
                   Mandatory=$true)]
        [Switch]
        $ReturnSheet,

        [Parameter(Mandatory=$true)]
        [String]
        $RefreshToken,
        
        [Parameter(Mandatory=$true)]
        [String]
        $ClientID,
        
        [Parameter(Mandatory=$true)]
        [String]
        $ClientSecret,
        
        [String]
        $Proxy
    )

    begin {
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

        # Init variables
        $valueData = @()
        $sheetArray = @()
        $firstRun = $true
    }
    
    process {
        # Iterate through the actual data, adding to the array of values for each row
        foreach ($row in $InputData) {
            # On first iteration get the headers and add the header row (unless run with -NoHeader) 
            if ($firstRun) {
                $firstRun = $false

                # Get the headers of the input data
                $headerArray = $row.PSObject.Properties.Name | Where-Object {$_ -notin $ExcludeProperty}
                
                if (!$NoHeader) {
                    # Add the row data for the header rows
                    $valueData += @{
                        values = $headerArray.ForEach{
                            @{
                                userEnteredValue = @{
                                    stringValue = $_
                                }
                            }
                        }
                    }
                }
            }
            
            # Get an array of each value in the row
            $values = $headerArray.ForEach{
                
                # Get the current value, if null change to an empty string
                $currentValue = $row.$_
                if (!$currentValue) {
                    $currentValue = ""
                }

                # Try to find the value type, default to string
                try {$valueType = $currentValue.GetType().Name}
                catch {$valueType = 'String'}

                # Set the valueDataType for the Google api call based on the data type
                if ($valueType -eq 'String') {
                    $valueDataType = 'stringValue'
                } elseif ($valueType -eq 'Boolean') {
                    $valueDataType = 'boolValue'
                } else {
                    $valueDataType = 'numberValue'
                }

                # Return the value 
                @{
                    userEnteredValue = @{
                        $valueDataType = $currentValue
                    }
                }
            }

            # Add the object to the valueData array
            $valueData += @{
                values = $values
            }
        }
    }
    
    end {
        if ($PSCmdlet.ParameterSetName -in @('SingleSheet','ReturnSheet')) {
            # Build the spreadsheet object if the parameter set is SingleSheet or ReturnSheet
            # Format the spreadsheet object
            $sheetObject = @{
                properties = @{
                    title = $SheetName
                }
                data = @{
                    rowData = $valueData
                }
            }

            # if -ReturnSheet, return the formatted sheet object only, no upload, etc. 
            if ($ReturnSheet) {
                return $sheetObject
            }
        } elseif ($PSCmdlet.ParameterSetName -in @('MultiSheet')) {
            $sheetObject = $sheetArray
        }

        # Build the body object
        $body = @{
            properties = @{}
            sheets = @($sheetObject)
        } 
        
        # Set the sheet title if specified
        if ($SpreadsheetName) {
            $body.properties.title = $SpreadsheetName
        }
        
        $jsonBody = $body | ConvertTo-Json -Depth 20 -Compress

        # Splat the invoke-restmethod parameters for easy reading
        $restParams = @{
            Uri = 'https://sheets.googleapis.com/v4/spreadsheets/'
            Method = 'POST'
            Body = $jsonBody
            TimeoutSec = 60
        }

        Invoke-RestMethod @restParams
    }
}