# crypto-helpers.ps1
# Cryptography helper functions using .NET Framework (no admin rights required)
# Provides PBKDF2 password hashing and AES-256 encryption for patient names

# ===== PBKDF2 PASSWORD HASHING =====

<#
.SYNOPSIS
    Creates a PBKDF2 hash of a password with a random salt
.PARAMETER password
    The plaintext password to hash
.PARAMETER iterations
    Number of PBKDF2 iterations (default: 10000)
.RETURNS
    Hashtable with Base64-encoded Hash and Salt
#>
function New-PasswordHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$false)]
        [int]$iterations = 10000
    )

    try {
        # Generate random 16-byte salt
        $salt = New-Object byte[] 16
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($salt)

        # Create PBKDF2 hash (256-bit / 32 bytes)
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, $iterations)
        $hash = $pbkdf2.GetBytes(32)

        # Clean up
        $pbkdf2.Dispose()
        $rng.Dispose()

        # Return Base64-encoded hash and salt
        return @{
            Hash = [Convert]::ToBase64String($hash)
            Salt = [Convert]::ToBase64String($salt)
        }
    }
    catch {
        throw "Failed to create password hash: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Verifies a password against a stored PBKDF2 hash and salt
.PARAMETER password
    The plaintext password to verify
.PARAMETER storedHash
    The Base64-encoded stored hash
.PARAMETER storedSalt
    The Base64-encoded stored salt
.PARAMETER iterations
    Number of PBKDF2 iterations (default: 10000)
.RETURNS
    $true if password matches, $false otherwise
#>
function Test-Password {
    param(
        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$storedHash,

        [Parameter(Mandatory=$true)]
        [string]$storedSalt,

        [Parameter(Mandatory=$false)]
        [int]$iterations = 10000
    )

    try {
        # Decode the stored salt
        $salt = [Convert]::FromBase64String($storedSalt)

        # Hash the provided password with the same salt
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, $iterations)
        $computedHash = $pbkdf2.GetBytes(32)

        # Clean up
        $pbkdf2.Dispose()

        # Decode the stored hash
        $originalHash = [Convert]::FromBase64String($storedHash)

        # Constant-time comparison to prevent timing attacks
        $isMatch = $true
        if ($computedHash.Length -ne $originalHash.Length) {
            $isMatch = $false
        }
        else {
            for ($i = 0; $i -lt $computedHash.Length; $i++) {
                if ($computedHash[$i] -ne $originalHash[$i]) {
                    $isMatch = $false
                }
            }
        }

        return $isMatch
    }
    catch {
        throw "Failed to verify password: $($_.Exception.Message)"
    }
}

# ===== AES-256 ENCRYPTION =====

<#
.SYNOPSIS
    Generates a random 256-bit AES encryption key (KEK)
.RETURNS
    Base64-encoded 256-bit key
#>
function New-EncryptionKey {
    try {
        # Generate random 256-bit (32-byte) key
        $key = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($key)
        $rng.Dispose()

        return [Convert]::ToBase64String($key)
    }
    catch {
        throw "Failed to generate encryption key: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Derives a 256-bit KEK (Key Encryption Key) from a user password using PBKDF2
.PARAMETER password
    The password to derive the KEK from
.PARAMETER iterations
    Number of PBKDF2 iterations (default: 100000 for KEK - higher than password hashing)
.RETURNS
    Hashtable with Base64-encoded KEK and Salt
#>
function New-KekFromPassword {
    param(
        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$false)]
        [int]$iterations = 100000
    )

    try {
        # Generate random 32-byte salt (larger salt for KEK)
        $salt = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($salt)

        # Derive 256-bit (32-byte) KEK using PBKDF2
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, $iterations)
        $kek = $pbkdf2.GetBytes(32)

        # Clean up
        $pbkdf2.Dispose()
        $rng.Dispose()

        # Return Base64-encoded KEK and salt
        return @{
            KEK = [Convert]::ToBase64String($kek)
            Salt = [Convert]::ToBase64String($salt)
        }
    }
    catch {
        throw "Failed to derive KEK from password: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Derives KEK from password AND creates verification hash (double PBKDF2)
.PARAMETER password
    The password to derive the KEK from
.PARAMETER iterations
    Number of PBKDF2 iterations (default: 100000)
.RETURNS
    Hashtable with Base64-encoded DerivedKEK, KEKHash, and Salt
.NOTES
    Uses double PBKDF2 pattern for security:
    1. Derive KEK from password (first PBKDF2)
    2. Hash the derived KEK (second PBKDF2)
    3. Store ONLY the hash in database (never store derived KEK)
    This ensures database breach requires hash cracking to obtain KEK
#>
function New-KekWithHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$false)]
        [int]$iterations = 100000
    )

    try {
        # Generate random 32-byte salt
        $salt = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($salt)

        # STEP 1: Derive KEK from password (first PBKDF2)
        $pbkdf2_1 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, $iterations)
        $derivedKek = $pbkdf2_1.GetBytes(32)

        # STEP 2: Hash the derived KEK (second PBKDF2)
        # Use same salt and iterations for consistency
        $pbkdf2_2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($derivedKek, $salt, $iterations)
        $kekHash = $pbkdf2_2.GetBytes(32)

        # Clean up
        $pbkdf2_1.Dispose()
        $pbkdf2_2.Dispose()
        $rng.Dispose()

        # Return all three values
        return @{
            DerivedKEK = [Convert]::ToBase64String($derivedKek)  # For session storage only
            KEKHash = [Convert]::ToBase64String($kekHash)        # For database storage
            Salt = [Convert]::ToBase64String($salt)
        }
    }
    catch {
        throw "Failed to derive KEK with hash: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Validates a KEK password against stored hash
.PARAMETER password
    The password to validate
.PARAMETER storedHash
    The Base64-encoded stored KEK hash
.PARAMETER storedSalt
    The Base64-encoded stored salt
.PARAMETER iterations
    Number of PBKDF2 iterations (default: 100000)
.RETURNS
    Hashtable with IsValid (bool) and DerivedKEK (if valid)
.NOTES
    If valid, returns the derived KEK for session storage
#>
function Test-KekPassword {
    param(
        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$storedHash,

        [Parameter(Mandatory=$true)]
        [string]$storedSalt,

        [Parameter(Mandatory=$false)]
        [int]$iterations = 100000
    )

    try {
        # Decode salt
        $salt = [Convert]::FromBase64String($storedSalt)

        # STEP 1: Derive KEK from password (first PBKDF2)
        $pbkdf2_1 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, $iterations)
        $derivedKek = $pbkdf2_1.GetBytes(32)

        # STEP 2: Hash the derived KEK (second PBKDF2)
        $pbkdf2_2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($derivedKek, $salt, $iterations)
        $computedHash = $pbkdf2_2.GetBytes(32)

        # Clean up PBKDF2 objects
        $pbkdf2_1.Dispose()
        $pbkdf2_2.Dispose()

        # Decode stored hash
        $originalHash = [Convert]::FromBase64String($storedHash)

        # Constant-time comparison to prevent timing attacks
        $isMatch = $true
        if ($computedHash.Length -ne $originalHash.Length) {
            $isMatch = $false
        }
        else {
            for ($i = 0; $i -lt $computedHash.Length; $i++) {
                if ($computedHash[$i] -ne $originalHash[$i]) {
                    $isMatch = $false
                }
            }
        }

        if ($isMatch) {
            # Valid - return derived KEK for session storage
            return @{
                IsValid = $true
                DerivedKEK = [Convert]::ToBase64String($derivedKek)
            }
        }
        else {
            return @{
                IsValid = $false
                DerivedKEK = $null
            }
        }
    }
    catch {
        throw "Failed to validate KEK password: $($_.Exception.Message)"
    }
}

# ===== AES-256 ENCRYPTION =====

<#
.SYNOPSIS
    Encrypts text using AES-256-CBC
.PARAMETER plainText
    The text to encrypt
.PARAMETER keyBase64
    Base64-encoded 256-bit encryption key
.RETURNS
    Hashtable with Base64-encoded EncryptedData and IV
#>
function Protect-Text {
    param(
        [Parameter(Mandatory=$true)]
        [string]$plainText,

        [Parameter(Mandatory=$true)]
        [string]$keyBase64
    )

    try {
        # Decode the key
        $key = [Convert]::FromBase64String($keyBase64)

        # Create AES encryptor
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Key = $key
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.GenerateIV()

        # Encrypt the text
        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)
        $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

        # Store IV for decryption
        $iv = $aes.IV

        # Clean up
        $encryptor.Dispose()
        $aes.Dispose()

        # Return Base64-encoded encrypted data and IV
        return @{
            EncryptedData = [Convert]::ToBase64String($encryptedBytes)
            IV = [Convert]::ToBase64String($iv)
        }
    }
    catch {
        throw "Failed to encrypt text: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Decrypts AES-256-CBC encrypted text
.PARAMETER encryptedDataBase64
    Base64-encoded encrypted data
.PARAMETER ivBase64
    Base64-encoded initialization vector
.PARAMETER keyBase64
    Base64-encoded 256-bit encryption key
.RETURNS
    Decrypted plaintext string
#>
function Unprotect-Text {
    param(
        [Parameter(Mandatory=$true)]
        [string]$encryptedDataBase64,

        [Parameter(Mandatory=$true)]
        [string]$ivBase64,

        [Parameter(Mandatory=$true)]
        [string]$keyBase64
    )

    try {
        # Decode the key, IV, and encrypted data
        $key = [Convert]::FromBase64String($keyBase64)
        $iv = [Convert]::FromBase64String($ivBase64)
        $encryptedBytes = [Convert]::FromBase64String($encryptedDataBase64)

        # Create AES decryptor
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC

        # Decrypt the data
        $decryptor = $aes.CreateDecryptor()
        $plainBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        $plainText = [System.Text.Encoding]::UTF8.GetString($plainBytes)

        # Clean up
        $decryptor.Dispose()
        $aes.Dispose()

        return $plainText
    }
    catch {
        throw "Failed to decrypt text: $($_.Exception.Message)"
    }
}

# Functions exported via dot-sourcing
