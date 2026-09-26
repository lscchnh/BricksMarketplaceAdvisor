<#
.SYNOPSIS
    Watches the Bricks.co marketplace and emails you the offers matching your criteria.

.DESCRIPTION
    Signs in to the Bricks.co API, pages through the marketplace deals filtered by price,
    profitability and dividend, keeps the ones whose brick price variation (delta valuation)
    is below -maxPriceVariation, and sends an email. Only offers not already notified are sent.
    Runs forever (one scan every -intervalMinutes) unless -once is given.

    Passwords can be passed as arguments or through the BRICKS_PASSWORD / SMTP_PASSWORD
    environment variables (preferred: they do not end up in your shell history).

.EXAMPLE
    .\bricks-marketplace-advisor.ps1 me@mail.com $null me@mail.com $null smtp.office365.com 50000 8 5 1
#>
param (
    [Parameter(Mandatory = $true)][string]$bricksEmail,
    [string]$bricksPwd = $env:BRICKS_PASSWORD,
    [Parameter(Mandatory = $true)][string]$email,
    [string]$emailPwd = $env:SMTP_PASSWORD,
    [Parameter(Mandatory = $true)][string]$smtpServer,
    [int]$maxPrice = 500000,             # in cents
    [double]$minProfitability = 5,
    [double]$minDividend = 2,
    [double]$maxPriceVariation = 5,
    [bool]$getMinPriceVariation = $false,
    [int]$smtpPort = 587,
    [int]$intervalMinutes = 5,
    [switch]$once,                       # single scan, handy for Task Scheduler
    [switch]$dryRun                      # print results instead of sending an email
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 may default to TLS 1.0, which the API refuses.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$apiUrl = 'https://api.bricks.co'
$appUrl = 'https://app.bricks.co'
$pageSize = 10
$maxConsecutiveErrors = 3
$filters = "priceRange=100&priceRange=$maxPrice&profitabilityRange=$minProfitability&profitabilityRange=20&dividendsRange=$minDividend&dividendsRange=15"
$criteria = "maxPrice=$maxPrice minProfitability=$minProfitability minDividend=$minDividend maxPriceVariation=$maxPriceVariation"

$script:token = $null
$seenDeals = @{}

if (-not $bricksPwd) { throw 'Bricks password missing: pass -bricksPwd or set BRICKS_PASSWORD.' }
if (-not $emailPwd -and -not $dryRun) { throw 'SMTP password missing: pass -emailPwd or set SMTP_PASSWORD.' }

class BlockedException : System.Exception {
    BlockedException([string]$message) : base($message) {}
}

function Get-StatusCode($errorRecord) {
    $response = $errorRecord.Exception.Response
    if ($response) { return [int]$response.StatusCode }
    return $null
}

function Test-CloudflareChallenge($errorRecord) {
    $response = $errorRecord.Exception.Response
    return $response -and $response.Headers -and $response.Headers['cf-mitigated'] -eq 'challenge'
}

function Invoke-BricksApi {
    param([string]$path, [string]$method = 'GET', $headers = @{}, [string]$body)

    $allHeaders = @{}
    $headers.Keys | ForEach-Object { $allHeaders[$_] = $headers[$_] }
    if ($script:token) { $allHeaders['Authorization'] = "Bearer $($script:token)" }

    $params = @{ Uri = "$apiUrl$path"; Method = $method; Headers = $allHeaders; ContentType = 'application/json' }
    if ($body) { $params.Body = $body }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        if (Test-CloudflareChallenge $_) {
            throw [BlockedException]::new("Bricks API is protected by a Cloudflare bot challenge ($path): scripted access is currently blocked.")
        }
        throw
    }
}

function Connect-Bricks {
    $script:token = $null
    $body = @{ email = $bricksEmail } | ConvertTo-Json
    $response = Invoke-BricksApi '/customers/email/sign-in' -method 'POST' -headers @{ 'X-Password' = $bricksPwd } -body $body
    if (-not $response.token) { throw 'Sign-in succeeded but no token was returned.' }
    $script:token = $response.token
    Write-Host 'Signed in to Bricks.'
}

function Get-DealsPage([int]$cursor) {
    try {
        return Invoke-BricksApi "/marketplace/deals?$filters&cursor=$cursor"
    }
    catch [BlockedException] { throw }
    catch {
        if ((Get-StatusCode $_) -eq 401) {
            Write-Host 'Token expired, signing in again.'
            Connect-Bricks | Out-Null
            return Invoke-BricksApi "/marketplace/deals?$filters&cursor=$cursor"
        }
        throw
    }
}

function Get-AllDeals {
    $deals = @()
    $cursor = 0
    $total = 1
    $errors = 0
    while ($cursor -lt $total) {
        try {
            $response = Get-DealsPage $cursor
            $errors = 0
            $total = [int]$response.total.offers
            if ($response.data) { $deals += $response.data }
            $cursor += $pageSize
            if ($total -gt 0) {
                $processed = [Math]::Min($cursor, $total)
                Write-Host "$processed offers processed over $total ($([Math]::Truncate($processed * 100 / $total))%)"
            }
        }
        catch [BlockedException] { throw }
        catch {
            $errors++
            Write-Warning "Error while reading offers at cursor $cursor ($errors/$maxConsecutiveErrors): $($_.Exception.Message)"
            if ($errors -ge $maxConsecutiveErrors) { throw "Too many consecutive errors, scan aborted." }
            Start-Sleep -Seconds (5 * $errors)
            continue
        }
        Start-Sleep -Seconds 1   # throttling
    }
    return , $deals
}

function Get-DealUrl($deal) {
    $name = [uri]::EscapeDataString([string]$deal.property.name)
    return "$appUrl/marketplace?$filters&sort=profitability_desc&searchField=$name"
}

function Get-DealKey($deal) {
    if ($deal.id) { return [string]$deal.id }
    return "$($deal.property.name)|$($deal.brickPriceVariation)"
}

function Send-Notification([string]$subject, [string[]]$lines) {
    $body = $lines -join "`r`n"
    if ($dryRun) {
        Write-Host "[dry-run] $subject`n$body"
        return
    }
    $credential = New-Object System.Management.Automation.PSCredential ($email, (ConvertTo-SecureString $emailPwd -AsPlainText -Force))
    Send-MailMessage -To $email -From $email -Subject $subject -Body $body -UseSsl -Credential $credential -SmtpServer $smtpServer -Port $smtpPort -Encoding UTF8
    Write-Host "Email sent to $email."
}

function Invoke-Scan {
    $deals = Get-AllDeals
    $matching = @($deals | Where-Object { $null -ne $_.brickPriceVariation -and [double]$_.brickPriceVariation -lt $maxPriceVariation })
    Write-Host "$($matching.Count) offer(s) matching out of $($deals.Count)."

    if ($getMinPriceVariation) {
        $matching = @($matching | Sort-Object { [double]$_.brickPriceVariation } | Select-Object -First 1)
    }
    $new = @($matching | Where-Object { -not $seenDeals.ContainsKey((Get-DealKey $_)) })
    if ($new.Count -eq 0) {
        Write-Host 'No new offers found...'
        return
    }

    $lines = $new | ForEach-Object { "$($_.property.name) - price variation $($_.brickPriceVariation)% - $(Get-DealUrl $_)" }
    $prefix = if ($getMinPriceVariation) { '[BEST DELTA VALUATION] ' } else { '' }
    Send-Notification "$($prefix)New bricks in marketplace ($criteria)" $lines
    $new | ForEach-Object { $seenDeals[(Get-DealKey $_)] = $true }
}

try {
    Connect-Bricks
    while ($true) {
        try {
            Invoke-Scan
        }
        catch [BlockedException] { throw }
        catch {
            Write-Warning "Scan failed: $($_.Exception.Message)"
        }
        if ($once) { break }
        Write-Host "Waiting $intervalMinutes minutes."
        Start-Sleep -Seconds ($intervalMinutes * 60)
    }
}
catch [BlockedException] {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 2
}
catch {
    Write-Error "Fatal: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
