# Introduction

The script is useful if you want to be notified by mail of offers in the [Bricks.co](https://www.bricks.co) marketplace. You can use filters to get informed of offers corresponding to your desired criterias. You can choose to be notified of the best offer or a list of offers matching your criterias.

Each email lists the matching properties with their price variation and a direct marketplace link. An offer is only notified once per run, so you are not spammed every cycle with the same offers.

> **Known limitation (September 2026):** `api.bricks.co` is now protected by a Cloudflare bot challenge, which blocks scripted requests. When this happens the script stops with the message `Bricks API is protected by a Cloudflare bot challenge` and exit code `2`.

# Getting started

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- A bricks.co account
- An SMTP account to send the notification (e.g. Outlook: `smtp.office365.com`)

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `bricksEmail` | *required* | Bricks.co account email |
| `bricksPwd` | `$env:BRICKS_PASSWORD` | Bricks.co password |
| `email` | *required* | Email used to send and receive the notification |
| `emailPwd` | `$env:SMTP_PASSWORD` | SMTP password |
| `smtpServer` | *required* | SMTP server |
| `maxPrice` | `500000` | Maximum price, **in cents** |
| `minProfitability` | `5` | Minimum profitability (%) |
| `minDividend` | `2` | Minimum dividend (%) |
| `maxPriceVariation` | `5` | Only keep offers whose brick price variation (delta valuation) is below this value (%) |
| `getMinPriceVariation` | `$false` | Only notify the offer with the lowest price variation |
| `smtpPort` | `587` | SMTP port (TLS) |
| `intervalMinutes` | `5` | Delay between two scans |
| `-once` | | Run a single scan then exit (useful with the Windows Task Scheduler) |
| `-dryRun` | | Print the results instead of sending an email |

Exit codes: `0` success, `1` fatal error (e.g. wrong credentials), `2` blocked by the Bricks anti-bot protection.

## Example

The following command looks for offers of maximum 500€ with 8% of minimum profitability, 5% of minimum dividend and 1% of delta valuation. Passwords are read from environment variables so they do not end up in your shell history.

```ps
$env:BRICKS_PASSWORD = Read-Host 'Bricks password'
$env:SMTP_PASSWORD = Read-Host 'SMTP password'
.\bricks-marketplace-advisor.ps1 mybricksemail@email.com -email mypersonalemail -smtpServer smtp.office365.com -maxPrice 50000 -minProfitability 8 -minDividend 5 -maxPriceVariation 1
```

The historical positional syntax still works:

```ps
.\bricks-marketplace-advisor.ps1 mybricksemail@email.com mybrickspassword mypersonalemail mypersonalemailpassword smtp.office365.com 50000 8 5 1
```
