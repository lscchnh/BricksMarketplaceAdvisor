param (
    [Parameter(Mandatory=$true)][string]$bricksEmail,
    [Parameter(Mandatory=$true)][string]$bricksPassword,
    [Parameter(Mandatory=$true)][string]$email,
    [Parameter(Mandatory=$true)][string]$emailPassword,
    [Parameter(Mandatory=$true)][string]$smtpServer,
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
    param($bricksEmail, $bricksPassword)
    try
    {
        $body = "{`"email`":`"$bricksEmail`",`"password`":`"$bricksPassword`"}"
        $response = Invoke-RestMethod 'https://api.bricks.co/customers/email/sign-in' -Method 'POST' -Headers $headers -Body $body 
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

get_login_token $bricksEmail $bricksPassword

$cursor = 0
$totalOffers = 1
[bool]$found = $false

while(!$found)
{
    try
    {
        $filters="priceRange=1000&priceRange=$maxPrice&profitabilityRange=$minProfitability&profitabilityRange=20&dividendsRange=$minDividend&dividendsRange=15&cursor=$cursor"
        $url = "https://api.bricks.co/marketplace/deals?$filters"
        $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers
        $responseData = $response."data"
        $totalOffers = $response."total"."offers"
        if($responseData.length -ge 1) 
        {
            $processing = [Math]::Truncate($cursor*100/$totalOffers)
            Write-Output "$cursor offers processed over $totalOffers ($processing%)"
            Foreach($i in $responseData)
            {
                $deltaValuation = $i."performance"."deltaValuation"
                if($deltaValuation -lt $maxDeltaValuation)
                {
                    Write-Output "Found !!!"
                    $arr += @("https://app.bricks.co/marketplace?$filters")
                }
            }
        }

        $cursor+=10
    }
    catch
    {
        process_error($_.Exception)
    }
    
    start-sleep -seconds 1

    if($cursor -ge $totalOffers)
    {
        if($arr.length -gt 0)
        {
            $found=$true
        }
        else
        {
            Write-Output "No offers found..."
            $cursor = 10
        } 
    }
}

Write-Output "arr=$arr"
[securestring]$secStringPassword = ConvertTo-SecureString $emailPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($email, $secStringPassword)
Send-MailMessage -To "$email" -From "$email"  -Subject "New bricks in marketplace" -Body "$arr" -UseSsl -Credential $credential -SmtpServer "$smtpServer" -Port 587