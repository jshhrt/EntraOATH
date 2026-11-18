<#
.SYNOPSIS
    Activates an OATH hardware token for a user
.DESCRIPTION
    Activates an OATH hardware token for a user in Microsoft Entra ID via the Microsoft Graph API.
    Activation requires a verification code that matches the expected TOTP code for the token.
.PARAMETER TokenId
    The ID of the token to activate
.PARAMETER SerialNumber
    The serial number of the token to activate. Must match exactly one token.
.PARAMETER UserId
    The ID or UPN of the user who owns the token
.PARAMETER VerificationCode
    The TOTP code from the token to verify during activation
.PARAMETER Secret
    The token's secret key for automatic TOTP generation (if VerificationCode is not provided)
.PARAMETER SecretFormat
    The format of the provided Secret (Base32, Hex, or Text). Defaults to Base32.
.PARAMETER ApiVersion
    The Microsoft Graph API version to use. Defaults to 'beta'.
.EXAMPLE
    Set-OATHTokenActive -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@contoso.com" -VerificationCode "123456"
    
    Activates the specified token for the user with the given verification code
.EXAMPLE
    Set-OATHTokenActive -TokenId "00000000-0000-0000-0000-000000000000" -UserId "user@contoso.com" -Secret "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    
    Activates the specified token by automatically generating a TOTP code from the provided secret
.EXAMPLE
    Set-OATHTokenActive -SerialNumber "12345678" -UserId "user@contoso.com" -VerificationCode "123456"
    
    Activates the token with the given serial number for the user
.NOTES
    Requires Microsoft.Graph.Authentication module and appropriate permissions:
    - Policy.ReadWrite.AuthenticationMethod
    - Directory.Read.All
#>

function Set-OATHTokenActive {
    [CmdletBinding(DefaultParameterSetName = 'ManualCode', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ManualCode', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'AutoCode', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$TokenId,
        
        [Parameter(ParameterSetName = 'ManualCodeBySerial', Mandatory = $true)]
        [Parameter(ParameterSetName = 'AutoCodeBySerial', Mandatory = $true)]
        [string]$SerialNumber,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$UserId,
        
        [Parameter(ParameterSetName = 'ManualCode', Mandatory = $true, Position = 2)]
        [Parameter(ParameterSetName = 'ManualCodeBySerial', Mandatory = $true, Position = 2)]
        [string]$VerificationCode,
        
        [Parameter(ParameterSetName = 'AutoCode', Mandatory = $true)]
        [Parameter(ParameterSetName = 'AutoCodeBySerial', Mandatory = $true)]
        [string]$Secret,
        
        [Parameter(ParameterSetName = 'AutoCode')]
        [Parameter(ParameterSetName = 'AutoCodeBySerial')]
        [ValidateSet('Base32', 'Hex', 'Text')]
        [string]$SecretFormat = 'Base32',
        
        [Parameter()]
        [string]$ApiVersion = 'beta'
    )
    
    begin {
        # Initialize the skip processing flag at the start of each function call
        $script:skipProcessing = $false
        
        # Ensure we're connected to Graph
        if (-not (Test-MgConnection)) {
            $script:skipProcessing = $true
            # Return here only exits the begin block, not the function
            return
        }
        
        # Convert the verification code
        if ($PSCmdlet.ParameterSetName -like 'AutoCode*') {
            # Try to resolve the user first to make sure they exist
            $resolvedUser = Get-MgUserByIdentifier -Identifier $UserId
            if (-not $resolvedUser) {
                throw "User not found with identifier: $UserId"
            }
            
            $UserId = $resolvedUser.id
            
            # Generate TOTP code using the provided secret
            try {
                Write-Verbose "Generating TOTP code from secret..."
                
                # Convert secret to Base32 if needed
                $base32Secret = $Secret
                if ($SecretFormat -ne 'Base32') {
                    $base32Secret = ConvertTo-Base32 -InputString $Secret -InputFormat $SecretFormat
                    if (-not $base32Secret) {
                        throw "Failed to convert secret to Base32 format"
                    }
                    Write-Verbose "Converted secret from $SecretFormat to Base32: $base32Secret"
                }
                
                # Generate TOTP code - fix the parameter names to match the function in TOTP.ps1
                $totpParams = @{
                    Secret = $base32Secret
                    UnixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() # Use this instead
                    Digits = 6
                    TimeStep = 30
                    Algorithm = 'SHA1'
                }
                
                # Try generating TOTP code using our external implementation from TOTP.ps1
                $generatedCode = Get-TOTP @totpParams # Note: Also changed from Get-Totp to Get-TOTP for consistency
                if (-not $generatedCode -or -not [regex]::IsMatch($generatedCode, '^\d{6}$')) {
                    throw "Failed to generate a valid 6-digit TOTP code"
                }
                
                Write-Verbose "Generated verification code: $generatedCode"
                $VerificationCode = $generatedCode
            }
            catch {
                throw "Error generating TOTP code: $_"
            }
        }
        else {
            # Validate verification code format
            if (-not (Test-OATHVerificationCode -VerificationCode $VerificationCode)) {
                throw "Invalid verification code format. Must be a 6-digit number."
            }
            
            # Try to resolve the user if needed
            $resolvedUser = Get-MgUserByIdentifier -Identifier $UserId
            if (-not $resolvedUser) {
                throw "User not found with identifier: $UserId"
            }
            
            $UserId = $resolvedUser.id
        }
    }
    
    process {
        # Skip all processing if the connection check failed
        if ($script:skipProcessing) {
            return [PSCustomObject]@{
                Success = $false
                Reason = "Not connected to Microsoft Graph"
                TokenId = $TokenId
                UserId = $UserId
            }
        }

        try {
            if ($PSCmdlet.ParameterSetName -like '*BySerial') {
                # Get-OATHToken treats * and ? as wildcards, so re-filter for an exact match
                $matchingTokens = @(Get-OATHToken -SerialNumber $SerialNumber -ErrorAction Stop | Where-Object { $_.SerialNumber -eq $SerialNumber })
                if ($matchingTokens.Count -eq 0) {
                    throw "No token found with serial number: $SerialNumber"
                }
                if ($matchingTokens.Count -gt 1) {
                    throw "Multiple tokens found with serial number $SerialNumber. Use -TokenId instead."
                }
                $TokenId = $matchingTokens[0].Id
            }
            
            # Validate token ID format
            if (-not (Test-OATHTokenId -TokenId $TokenId)) {
                throw "Invalid token ID format: $TokenId"
            }
            
            # Check if the token exists and is assigned to the specified user
            $token = Get-OATHToken -TokenId $TokenId -ErrorAction Stop
            if (-not $token) {
                throw "Token not found with ID: $TokenId"
            }
            
            # Verify the token is assigned to the correct user
            if (-not $token.AssignedToId -or $token.AssignedToId -ne $UserId) {
                throw "Token is not assigned to the specified user. Please assign it first."
            }
            
            # Check if token is already activated
            if ($token.Status -eq 'activated') {
                $serialDisplay = if ($token.SerialNumber) { " (S/N: $($token.SerialNumber))" } else { "" }
                $userName = if ($token.AssignedToName) { $token.AssignedToName } else { $UserId }
                Write-Host "Token $($token.Id)$serialDisplay is already activated for user $userName." -ForegroundColor Yellow
                Write-Host "To reactivate the token, you must first unassign it using Set-OATHTokenUser -TokenId $($token.Id) -Unassign" -ForegroundColor Yellow
                
                # Return a result object instead of boolean
                return [PSCustomObject]@{
                    Success = $true
                    AlreadyActivated = $true
                    TokenId = $TokenId
                    SerialNumber = $token.SerialNumber
                    UserId = $UserId
                    UserName = $userName
                    Status = $token.Status
                }
            }
            
            # Set up activation request
            $endpoint = "https://graph.microsoft.com/$ApiVersion/users/$UserId/authentication/hardwareOathMethods/$TokenId/activate"
            $body = @{
                verificationCode = $VerificationCode
            } | ConvertTo-Json
            
            # Display info for confirmation
            $displayName = if ($token.DisplayName) { $token.DisplayName } else { $token.Id }
            $serialDisplay = if ($token.SerialNumber) { " (S/N: $($token.SerialNumber))" } else { "" }
            $userName = if ($token.AssignedToName) { $token.AssignedToName } else { $UserId }
            
            # Confirm activation
            if ($PSCmdlet.ShouldProcess("Token $displayName$serialDisplay for user $userName", "Activate")) {
                Write-Verbose "Activating token with verification code: $VerificationCode"
                $response = Invoke-MgGraphWithErrorHandling -Method POST -Uri $endpoint -Body $body -ContentType "application/json" -ErrorAction Stop
                
                Write-Host "Successfully activated token $displayName$serialDisplay for user $userName" -ForegroundColor Green
                
                # Return a result object instead of boolean
                return [PSCustomObject]@{
                    Success = $true
                    AlreadyActivated = $false
                    TokenId = $TokenId
                    SerialNumber = $token.SerialNumber
                    UserId = $UserId
                    UserName = $userName
                    Status = 'activated'
                }
            }
            else {
                Write-Warning "Activation canceled by user."
                return [PSCustomObject]@{
                    Success = $false
                    Reason = "Canceled by user"
                    TokenId = $TokenId
                    SerialNumber = $token.SerialNumber
                    UserId = $UserId
                    UserName = $userName
                    Status = $token.Status
                }
            }
        }
        catch {
            Write-Error "Failed to activate token: $_"
            return [PSCustomObject]@{
                Success = $false
                Reason = $_.ToString()
                TokenId = $TokenId
                SerialNumber = $token.SerialNumber
                UserId = $UserId
                Status = $token.Status
            }
        }
    }
}

# Add alias for backward compatibility - only if it doesn't already exist
if (-not (Get-Alias -Name 'Activate-HardwareOathToken' -ErrorAction SilentlyContinue)) {
    New-Alias -Name 'Activate-HardwareOathToken' -Value 'Set-OATHTokenActive'
}
