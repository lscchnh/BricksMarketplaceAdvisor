$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept-Language", "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7")
$headers.Add("access-Control-Request-Headers", "authorization")
$headers.Add("access-Control-Request-Method", "GET")
$headers.Add("origin", "https://app.bricks.co")
$headers.Add("referer", "https://app.bricks.co/")
$headers.Add("sec-fetch-dest", "empty")
$headers.Add("sec-fetch-mode", "cors")
$headers.Add("sec-fetch-site", "same-site")
$headers.Add("sec-ch-ua", "`" Not A;Brand`";v=`"99`", `"Chromium`";v=`"99`", `"Google Chrome`";v=`"99`"")
$headers.Add("sec-ch-ua-mobile", "?0")
$headers.Add("sec-ch-ua-platform", "`"Windows`"")
$headers.Add("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36")
$headers.Add("authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6Ijg5OTlkZDM2LWVkMjMtNGY0My1hN2MyLWM4ZGU3OTVkNmUyYyIsImV4cGlyYXRpb24iOiIyMDIyLTAzLTIzVDA3OjQ3OjU3Ljk5OFoiLCJ0b2tlblR5cGUiOiJjdXN0b21lciIsImlhdCI6MTY0NzQxNjg3NywiZXhwIjoxNjQ4MDIxNjc3fQ.BMJWnjHiouay4alTmVkwuWBC4h90T5IoJtvJ7DxlxF4")
$response=""

function process_error {
    param (
        $Exception
    )

    #Send-MailMessage -To "louis.cochinho@hotmail.fr" -From ""  -Subject "Bricks marketplace alert" -Body 'Bricks polling Status code : $Exception.Response.StatusCode.value__' -Credential (Get-Credential) -SmtpServer "smtp server" -Port 587
}

function process_success {
    param (
        $response
    )

    $responseData = @($response | Select-Object -Property "data")

    if($responseData.length -gt 1) 
    {
        Write-Output $responseData
    }
    #Send-MailMessage -To "louis.cochinho@hotmail.fr" -From ""  -Subject "New bricks in marketplace" -Body 'https://app.bricks.co/marketplace' -Credential (Get-Credential) -SmtpServer "smtp server" -Port 587
}

while(1)
{
    try
    {
        $response = Invoke-RestMethod 'https://api.bricks.co/marketplace/deals?priceRange=100&priceRange=500000&profitabilityRange=5&profitabilityRange=20&dividendsRange=2&dividendsRange=15&sort=createdat_desc&take=10' -Method 'GET' -Headers $headers
    }
    catch
    {
        process_error($_.Exception)
    }

    process_success($response | ConvertTo-Json)
    start-sleep -seconds 2
}

