param (
    [Parameter(Mandatory=$true)][string]$email,
    [Parameter(Mandatory=$true)][string]$password,
    [Parameter(Mandatory=$true)][string]$maxPrice,
    [Parameter(Mandatory=$true)][string]$minProfitability,
    [Parameter(Mandatory=$true)][string]$minDividend,
    [Parameter(Mandatory=$true)][string]$maxDeltaValuation
 )

 function process_error {
    param (
        $Exception
    )

    Write-Output $Exception
}

function get_login_token {
    param($email, $password)
    try
    {
        $body = "{`"email`":`"$email`",`"password`":`"$password`"}"
        $response = Invoke-RestMethod 'https://api.bricks.co/customers/email/sign-in' -Method 'POST' -Headers $headers -Body $body
        $response | ConvertTo-Json    
        $token = $response."token"
        $headers.Add("Authorization", "Bearer $token")
    }
    catch
    {
        process_error($_.Exception)
    }
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
get_login_token $email $password
$cursor=0
$totalOffers=1
while($cursor -le 50)
{
    try
    {
        $url = "https://api.bricks.co/marketplace/deals?priceRange=10&priceRange=$maxPrice&profitabilityRange=$minProfitability&profitabilityRange=20&dividendsRange=$minDividend&dividendsRange=15&cursor=$cursor"
        $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers
        $response | ConvertTo-Json -Depth 5

        $responseData = $response."data"
        $totalOffers = $response."total"."offers"
        Write-Output $responseData.length
        if($responseData.length -ge 1) 
        {
            Foreach($i in $responseData)
            {
                $deltaValuation = $i."performance"."deltaValuation"
                Write-Output "deltaValuation = $deltaValuation"
                if($deltaValuation -lt $maxDeltaValuation)
                {
                    $arr += @($i."property"."id")
                }
            }
        }

        $cursor+=10
    }
    catch
    {
        process_error($_.Exception)
    }

    #Send-MailMessage -To "louis.cochinho@hotmail.fr" -From ""  -Subject "New bricks in marketplace" -Body 'https://app.bricks.co/marketplace' -Credential (Get-Credential) -SmtpServer "smtp server" -Port 587
    
    start-sleep -seconds 2
}

Write-Output "arr=$arr"