function Export-GSheet {
    <#
    .SYNOPSIS
        Exports a PSObject to Google Sheets
    .DESCRIPTION
        Long description
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
    [CmdletBinding()]
    param (
        [PSCustomObject]$Data
    )
    
    begin {
    }
    
    process {
        # Get the headers of the input data
        $headerArray = $data[0].PSObject.Properties.Name

        # Create data for the header rows
        $valueData = @(
            @{
                values = $headerArray.ForEach{
                    @{
                        userEnteredValue = @{
                            stringValue = $_
                        }
                    }
                }
            }
        )

        # Iterate through the actual data, adding to the array of values for each row
        $valueData += foreach ($row in $data) {
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

            # Return the array of values
            @{
                values = $values
            }
        }

        # Build the body object
        $body = @{
            sheets = @(
                @{
                    properties = @{
                        title = "BillingData"
                    }
                    data = @{
                        rowData = $valueData
                    }
                }
            )
        } | ConvertTo-Json -Depth 20 -Compress

        # Set the upload headers
        $uploadHeaders = @{
            "Authorization" = $headers.Authorization
            "Content-Type" = 'application/json; charset=UTF-8'
            "Content-Length" = $body.Length
        }

        # Splat the invoke-restmethod parameters for easy reading
        $restParams = @{
            Uri = 'https://sheets.googleapis.com/v4/spreadsheets/'
            Method = 'POST'
            Body = $body
            Headers = $uploadHeaders 
            TimeoutSec = 60
        }

        Invoke-RestMethod @restParams
    }
    
    end {
    }
}