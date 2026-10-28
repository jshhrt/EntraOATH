# OATH Token Management for Microsoft Entra ID

A PowerShell module for managing hardware OATH tokens in Microsoft Entra ID (formerly Azure AD) through the Microsoft Graph API.

[Manage OATH Tokens in Entra](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-mfa-manage-oath-tokens#scenario-admin-creates-token-that-users-self-assign-and-activate)

## Overview

The module manages OATH-TOTP hardware tokens (such as YubiKeys) in Microsoft Entra ID. You can use the individual cmdlets in scripts, or the interactive menu.

## Features

- **Token lifecycle**
  - Add tokens one at a time or in bulk
  - Assign tokens to users by ID, UPN, or display name
  - Activate tokens with a verification code
  - Unassign tokens from users
  - Remove tokens

- **Inventory**
  - List tokens, filtered by status, serial number, or user
  - Export tokens to CSV or JSON

- **Bulk operations**
  - Import tokens from JSON or CSV
  - Assign tokens to users during import
  - Remove tokens in bulk

- **TOTP**
  - Generate TOTP codes (RFC 6238)
  - Activate a token from its secret without entering a code

- **Secret formats**
  - Base32
  - Hexadecimal
  - Plain text

## Prerequisites

- PowerShell 5.1 or newer (PowerShell 7+ recommended)
- Microsoft Graph PowerShell SDK modules:
  - Microsoft.Graph.Authentication
- Appropriate permissions in Microsoft Entra ID

### Required Microsoft Graph Permissions

- `Policy.ReadWrite.AuthenticationMethod`
- `Directory.Read.All`

## Installation

### Option 1: Install from PowerShell Gallery (Recommended)

```powershell
Install-Module -Name OATHTokens -Scope CurrentUser
```

### Option 2: Manual Installation

1. Clone this repository or download the ZIP file
2. Copy the module folder to one of your PowerShell module directories:

```powershell
# Find your PSModulePath
$env:PSModulePath -split ';'

# Copy the module (replace PATH_TO_MODULE with the actual path)
Copy-Item -Path "PATH_TO_MODULE\OATHTokens" -Destination "$HOME\Documents\PowerShell\Modules\" -Recurse
```

## Quick Start

1. Import the module:
   ```powershell
   Import-Module OATHTokens
   ```

2. Connect to Microsoft Graph:
   ```powershell
   Connect-MgGraph -Scopes "Policy.ReadWrite.AuthenticationMethod","Directory.Read.All"
   ```

3. Start the interactive menu:
   ```powershell
   Show-OATHTokenMenu
   ```

4. Or use individual commands:
   ```powershell
   # List all tokens
   Get-OATHToken
   
   # Add a token
   Add-OATHToken -SerialNumber "12345678" -SecretKey "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
   
   # Assign a token to a user
   Set-OATHTokenUser -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@example.com"
   ```

## Module Structure

- **Public**: Exported cmdlets
  - **Add**, **Get**, **Remove**: Token management
  - **Set**: Assignment and activation
  - **Import**, **Export**: Bulk import and export
  - **UI**: Interactive menu
  - **Utility**: TOTP, Base32 conversion, and serial number generation

- **Private**: Internal helpers
  - Base32 conversion
  - Graph API requests
  - Validation

## Core Commands

| Command | Description |
|---------|-------------|
| `Add-OATHToken` | Adds OATH tokens to Entra ID |
| `Get-OATHToken` | Retrieves OATH tokens with filtering options |
| `Remove-OATHToken` | Removes OATH tokens from Entra ID |
| `Set-OATHTokenUser` | Assigns or unassigns tokens to/from users |
| `Set-OATHTokenActive` | Activates a token using a verification code |
| `Import-OATHToken` | Imports tokens from JSON or CSV files |
| `Export-OATHToken` | Exports tokens to various formats |
| `Show-OATHTokenMenu` | Displays the interactive management menu |
| `Get-TOTP` | Generates TOTP codes from secrets |
| `New-OATHTokenSerial` | Generates unique token serial numbers |

## JSON File Examples

### Token Inventory JSON

```json
{
  "inventory": [
    {
      "serialNumber": "YK-12345",
      "secretKey": "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
      "manufacturer": "Yubico",
      "model": "YubiKey 5"
    },
    {
      "serialNumber": "YK-67890",
      "secretKey": "3a085cfcd4618c61dc235c300d7a70c4",
      "secretFormat": "hex",
      "manufacturer": "Yubico",
      "model": "YubiKey 5 NFC"
    },
    {
      "serialNumber": "YK-ABCDE",
      "secretKey": "MySecretPassword123",
      "secretFormat": "text",
      "displayName": "My Special YubiKey"
    }
  ]
}
```

### Token Assignment JSON

```json
{
  "inventory": [
    {
      "serialNumber": "YK-12345",
      "secretKey": "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
      "assignTo": {
        "id": "user@example.com"
      }
    }
  ],
  "assignments": [
    {
      "tokenId": "00000000-0000-0000-0000-000000000000",
      "userId": "user@example.com"
    },
    {
      "tokenId": "11111111-1111-1111-1111-111111111111",
      "userId": "80d2efac-c489-49d5-b074-df2ed4dde02d"
    }
  ]
}
```

### Mixed Schema Example

```json
{
  "inventory": [
    {
      "serialNumber": "YK-30001",
      "secretKey": "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    },
    {
      "serialNumber": "YK-30002",
      "secretKey": "48656c6c6f20576f726c6422",
      "secretFormat": "hex",
      "assignTo": {
        "id": "user@example.com"
      }
    }
  ],
  "assignments": [
    {
      "tokenId": "00000000-0000-0000-0000-000000000000",
      "userId": "00000000-0000-0000-0000-000000000001"
    }
  ]
}
```

## Common Tasks

### Adding a Token

```powershell
# Add a token with a Base32 secret
Add-OATHToken -SerialNumber "12345678" -SecretKey "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

# Add a token with a hexadecimal secret
Add-OATHToken -SerialNumber "87654321" -SecretKey "3a085cfcd4618c61dc235c300d7a70c4" -SecretFormat Hex

# Add a token with a text secret
Add-OATHToken -SerialNumber "11223344" -SecretKey "MySecretPassword123" -SecretFormat Text

# Add a token and assign to user directly
Add-OATHToken -SerialNumber "12345678" -SecretKey "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" -UserId "user@example.com"
```

### Finding Tokens

```powershell
# Get all tokens
Get-OATHToken

# Get available (unassigned) tokens
Get-OATHToken -AvailableOnly

# Get activated tokens
Get-OATHToken -ActivatedOnly

# Find tokens by serial number (supports wildcards)
Get-OATHToken -SerialNumber "YK*"

# Find tokens by user
Get-OATHToken -UserId "user@example.com"
```

### Assigning Tokens

```powershell
# Assign by token ID
Set-OATHTokenUser -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@example.com"

# Assign by serial number
Set-OATHTokenUser -SerialNumber "12345678" -UserId "user@example.com"

# Unassign a token
Set-OATHTokenUser -TokenId "00000000-0000-0000-0000-000000000000" -Unassign
```

### Activating Tokens

```powershell
# Activate with a verification code
Set-OATHTokenActive -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@example.com" -VerificationCode "123456"

# Activate with a secret key (auto-generates the TOTP code)
Set-OATHTokenActive -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@example.com" -Secret "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
```

### Bulk Operations

```powershell
# Import tokens from JSON
Import-OATHToken -FilePath "tokens.json" -Format JSON

# Import tokens and assign to users
Import-OATHToken -FilePath "tokens_users.json" -Format JSON -SchemaType UserAssignments -AssignToUsers

# Export tokens to CSV
Export-OATHToken -FilePath "tokens.csv"

# Export tokens to JSON
Export-OATHToken -FilePath "tokens.json" -Format JSON
```

### Generating TOTP Codes

```powershell
# Generate a TOTP code from a Base32 secret
Get-TOTP -Secret "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

# Generate a TOTP code from a hexadecimal secret
Get-TOTP -Secret "3a085cfcd4618c61dc235c300d7a70c4" -InputFormat Hex

# Generate a TOTP code from a text secret
Get-TOTP -Secret "MySecretPassword123" -InputFormat Text
```

## Interactive Menu

Run `Show-OATHTokenMenu` to open the menu.

### Main Menu
- **Get OATH**: Lists and exports tokens
- **Add OATH**: Adds, assigns, and activates tokens
- **Remove OATH**: Removes and unassigns tokens

### Get OATH Menu
- List All
- List Available
- List Activated
- Export to CSV
- Find by Serial Number
- Find by User ID/UPN

### Add OATH Menu
- Add OATH Token
- Assign OATH User (by token ID or serial number)
- Activate OATH Token
- Bulk Import OATH Tokens
- Activate with TOTP

### Remove OATH Menu
- Remove OATH
- Bulk Remove OATH
- Unassign OATH token (by token ID or serial number)

## Advanced Scenarios

### Automating Token Setup

This script creates a token, assigns it to a user, and generates the current TOTP code:

```powershell
# Generate a unique serial number
$serialNumber = New-OATHTokenSerial -Prefix "YK-" -Format Alphanumeric -CheckExisting

# Generate a random secret
$secret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$base32Secret = Convert-Base32 -InputString $secret -InputFormat Text

# Add the token
$token = Add-OATHToken -SerialNumber $serialNumber -SecretKey $base32Secret

# Assign to a user
Set-OATHTokenUser -TokenId $token.id -UserId "user@example.com"

# Generate a TOTP code
$totpCode = Get-TOTP -Secret $base32Secret

Write-Host "Token serial: $serialNumber"
Write-Host "Token secret: $base32Secret"
Write-Host "Current TOTP: $totpCode"
```

### User Onboarding

This function issues a token as part of onboarding a new user:

```powershell
function New-UserOnboarding {
    param($UserPrincipalName, $DisplayName)
    
    # Create the user in Entra ID (using separate commands)
    # ...
    
    # Get the user's ID
    $user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'"
    
    # Generate a token
    $serialNumber = New-OATHTokenSerial -CheckExisting
    $secretKey = Convert-Base32 -InputString ([Guid]::NewGuid().ToString()) -InputFormat Text
    
    # Add and assign the token
    $token = Add-OATHToken -SerialNumber $serialNumber -SecretKey $secretKey
    Set-OATHTokenUser -TokenId $token.id -UserId $user.id
    
    # Return the token details for record-keeping
    return @{
        UserPrincipalName = $UserPrincipalName
        TokenId = $token.id
        SerialNumber = $serialNumber
        SecretKey = $secretKey
    }
}
```

## Troubleshooting

### Common Issues

- **Not connected to Microsoft Graph**: run `Connect-MgGraph -Scopes "Policy.ReadWrite.AuthenticationMethod","Directory.Read.All"`
- **Token not found**: check the token ID or serial number with `Get-OATHToken`
- **User not found**: check the user ID or UPN with `Get-MgUser`
- **Token activation failed**: check the verification code is correct and hasn't expired
- **Assignment succeeds but the token still shows as available**: check the user ID, and run the command again with `-Verbose` to see each step

To check your Graph connection and permissions:

```powershell
Get-MgContext
(Get-MgContext).Scopes
```

Add `-Verbose` to any command for more detail:

```powershell
Set-OATHTokenUser -TokenId $id -UserId $user -Verbose
```

## Contributing

Pull requests are welcome.

### Publishing

The module is published to the PowerShell Gallery by a GitHub Actions workflow, configured in `psgallery.json`.

To publish a new version:

1. Update the version and release notes in `psgallery.json` and set `publishThisVersion` to `true`.
2. Push to `main`. The workflow only runs when files under `OATHTokens/` or `psgallery.json` change.
3. The workflow lints the module with PSScriptAnalyzer, imports it, and publishes it. If the manifest version doesn't match `psgallery.json`, it updates the manifest for that run only. The change isn't committed, so keep `OATHTokens.psd1` in sync yourself.
4. Set `publishThisVersion` back to `false` afterwards. The workflow doesn't commit this change either.

See `.github/workflows/README.md` for details.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

- The TOTP implementation is based on RFC 6238
- Credits to: https://gist.github.com/jonfriesen/234c7471c3e3199f97d5#file-totp-ps1

