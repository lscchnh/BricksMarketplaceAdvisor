param (
    [Parameter(Mandatory = $true)][string]$bricksEmail,
    [Parameter(Mandatory = $true)][string]$bricksPwd,
    [Parameter(Mandatory = $true)][string]$email,
    [Parameter(Mandatory = $true)][string]$emailPwd,
    [Parameter(Mandatory = $true)][string]$smtpServer,
    [Parameter(Mandatory = $false)][string]$maxPrice = "500000",
    [Parameter(Mandatory = $false)][string]$minProfitability = "5",
    [Parameter(Mandatory = $false)][string]$minDividend = "2",
    [Parameter(Mandatory = $false)][string]$maxPriceVariation = "5",
    [Parameter(Mandatory = $false)][bool]$getMinPriceVariation = $false
)

function Initialize-Variables {
    $script:cursor = 10
    $script:totalOffers = 1
    $script:currentMinPriceVariation = 100
    $script:currentMinPriceVariationUrl = $null
    $script:currentMinPriceVariationPropertyName = $null
}

function Process_Error {
    param (
        $Exception
    )

    Write-Output $Exception
}

function Get-Token {
    param($bricksEmail, $bricksPwd)
    try {
        $body = "{`"email`":`"$bricksEmail`",`"password`":`"$bricksPwd`"}"
        $response = Invoke-RestMethod 'https://api.bricks.co/customers/email/sign-in' -Method 'POST' -Headers $headers -Body $body 
        $token = $response."token"
        $headers.Add("Authorization", "Bearer $token")
    }
    catch {
        Process_Error $_.Exception
    }
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

Get-Token $bricksEmail $bricksPwd
Initialize-Variables

while ($true) {
    try {
        $filters = "priceRange=100&priceRange=$maxPrice&profitabilityRange=$minProfitability&profitabilityRange=20&dividendsRange=$minDividend&dividendsRange=15&cursor=$cursor"
        $url = "https://api.bricks.co/marketplace/deals?$filters"
        $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers
        $responseData = $response."data"
        $totalOffers = $response."total"."offers"
        $processing = [Math]::Truncate($cursor * 100 / $totalOffers)
        if ($responseData.length -ge 1) {                      
            Foreach ($i in $responseData) {
                $brickPriceVariation = $i."brickPriceVariation"
                $propertyName = $i."property"."name".Replace(" ", "%20")       
                if ($brickPriceVariation -lt $maxPriceVariation) {                   
                    if ($getMinPriceVariation) {
                        if ($brickPriceVariation -lt $currentMinPriceVariation) {
                            $currentMinPriceVariation = $brickPriceVariation
                            $currentMinPriceVariationUrl = @("https://app.bricks.co/marketplace?priceRange=100&priceRange=$maxPrice&profitabilityRange=$minProfitability&profitabilityRange=20&dividendsRange=$minDividend&dividendsRange=15&sort=profitability_desc&searchField=$propertyName")
                        }
                    }
                    else {
                        Write-Output "Found !!!"
                        $arr += @("https://app.bricks.co/marketplace?$filters&sort=profitability_desc")   
                    }
                }
            }
        }

        Write-Output "$cursor offers processed over $totalOffers ($processing%)"
        
        $cursor += 10
        start-sleep -seconds 1
    }
    catch {
        Process_Error $_.Exception
    }
    
    if ($cursor -ge $totalOffers) {
        [securestring]$secStringPassword = ConvertTo-SecureString $emailPwd -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($email, $secStringPassword)

        if ($arr.length -gt 0) {
            Send-MailMessage -To "$email" -From "$email"  -Subject "New bricks in marketplace (maxPrice=$maxPrice minProfitability=$minProfitability minDividend=$minDividend maxPriceVariation=$maxPriceVariation)" -Body "$arr" -UseSsl -Credential $credential -SmtpServer "$smtpServer" -Port 587
            
            Write-Output "Email sent to $email."         
        }
        elseif ($getMinPriceVariation -and -not ($null -eq $currentMinPriceVariationUrl)) {
            Send-MailMessage -To "$email" -From "$email"  -Subject "[BEST DELTA VALUATION] New bricks in marketplace (maxPrice=$maxPrice minProfitability=$minProfitability minDividend=$minDividend maxPriceVariation=$maxPriceVariation)" -Body "$currentMinPriceVariationUrl" -UseSsl -Credential $credential -SmtpServer "$smtpServer" -Port 587

            Write-Output "Email sent to $email."  
        }
        else {
            Write-Output "No offers found..."
        }

        Write-Output "Waiting 5 minutes."       
        start-sleep -seconds 300
        Initialize-Variables
    }
}