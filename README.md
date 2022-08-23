# Introduction

The script is useful if you want to be notified by mail of offers in the [Bricks.co](https://www.bricks.co) marketplace. You can use filters to get informed of offers corresponding to your desired criterias.

# Getting started

## Prerequisites

- Powershell
- A bricks.co account

## How to use

Download the latest release and run the powershell script with the beyond arguments. It will start to look for offers matching your criterias and send you an email if offers were found.

```ps
    [Parameter(Mandatory=$true)][string]$bricksEmail,
    [Parameter(Mandatory=$true)][string]$bricksPassword,
    [Parameter(Mandatory=$true)][string]$email,
    [Parameter(Mandatory=$true)][string]$emailPassword,
    [Parameter(Mandatory=$true)][string]$smtpServer,
    [Parameter(Mandatory=$true)][string]$maxPrice,
    [Parameter(Mandatory=$true)][string]$minProfitability,
    [Parameter(Mandatory=$true)][string]$minDividend,
    [Parameter(Mandatory=$true)][string]$maxDeltaValuation
```

**/!\ maxPrice is in cents.**

Example : 

The following command will look for offers of maximum 500€ with 8% of minimum profitability, 5% of minimum dividend and 1% of delta valuation.

```sh
.\bricks-marketplace-advisor.ps1 mybricksemail@email.com mybrickspassword mypersonalemail mypersonalemailpassword smtp.office365.com 50000 8 5 1
```
