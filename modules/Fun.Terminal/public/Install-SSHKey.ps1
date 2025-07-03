$shellScript = @'
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat ~/tmp.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
rm ~/tmp.pub
'@

<#
.SYNOPSIS
Installs an SSH public key on a remote host by generating a new key pair (if needed), copying the public key, and appending it to the remote's authorized_keys file.

.DESCRIPTION
The `Install-SSHKey` function automates the setup of SSH key-based authentication by:
1. Generating a new SSH key pair (RSA, ED25519, or ECDSA) if the private key does not exist.
2. Copying the public key to a temporary file on the remote host using `scp`.
3. Appending the public key to the remote user's `~/.ssh/authorized_keys` via `ssh`.
4. Testing the connection to confirm passwordless access.

Only one key type switch (`-RSA`, `-ED25519`, or `-ECDSA`) should be used per invocation. If none is specified, RSA is used by default.

.PARAMETER RemoteHost
The address of the remote host (e.g. `user@host.com`) where the SSH key should be installed.

.PARAMETER KeyName
The base file name for the SSH key pair. This will be placed in the user's `~/.ssh` directory. A `.pub` extension is automatically added to the public key.

.PARAMETER RSA
Switch to generate an RSA key (default). This creates a 4096-bit RSA key pair.

.PARAMETER ED25519
Switch to generate an ED25519 key instead of RSA.

.PARAMETER ECDSA
Switch to generate an ECDSA key instead of RSA.

.EXAMPLE
Install-SSHKey -RemoteHost "user@192.168.1.10" -KeyName "id_mykey" -ED25519

Generates an ED25519 key (if it doesn't exist), copies it to the remote host, and appends it to `authorized_keys`.

.EXAMPLE
Install-SSHKey -RemoteHost "user@server.com" -KeyName "id_custom" -RSA -Verbose

Generates a 4096-bit RSA key named `id_custom`, installs it on the remote server, and tests the connection.

.NOTES
This function depends on the presence of `ssh-keygen`, `scp`, and `ssh` being available in the system path.
Make sure the remote host allows SSH access and does not block key-based authentication.

#>
function Install-SSHKey {
    [CmdletBinding(DefaultParameterSetName = 'RSA', SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RemoteHost,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $KeyName,

        [Parameter(ParameterSetName = 'RSA')]
        [switch] $RSA,

        [Parameter(ParameterSetName = 'ED25519')]
        [switch] $ED25519,

        [Parameter(ParameterSetName = 'ECDSA')]
        [switch] $ECDSA
    )

    $sshDir = Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath '.ssh'
    $keyPath = Join-Path -Path $sshDir -ChildPath $KeyName
    $pubKeyPath = "$keyPath.pub"
    $keyType = Get-KeyType

    if (-not (Test-Path $keyPath)) {
        Write-Verbose "No existing key found at $keyPath. Generating new $keyType key..."
        New-SSHKey -Type $keyType -Path $keyPath
    } else {
        Write-Warning "Key already exists at $keyPath. Skipping generation."
    }

    Copy-PublicKey -PublicKeyPath $pubKeyPath -RemoteHost $RemoteHost
    Initialize-AuthorizedKeys -RemoteHost $RemoteHost
    Test-SSHConnection -RemoteHost $RemoteHost
}

function Get-KeyType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('RSA', 'ED25519', 'ECDSA')]
        [string] $ParameterSetName
    )

    switch ($ParameterSetName) {
        'ED25519' { return 'ed25519' }
        'ECDSA'   { return 'ecdsa' }
        'RSA'     { return 'rsa' }
        default   { throw "Unsupported parameter set name: $ParameterSetName" }
    }
}

function New-SSHKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('rsa', 'ed25519', 'ecdsa')]
        [string] $Type,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $arguments = @('-t', $Type, '-f', $Path)

    if ($Type -eq 'rsa') {
        $arguments += @('-b', '4096')
    }

    Write-Verbose "Generating SSH key with: ssh-keygen $($arguments -join ' ')"

    $result = & ssh-keygen.exe @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "SSH key generation failed with exit code $LASTEXITCODE"
    }

    return $result
}

function Copy-PublicKey {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PublicKeyPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RemoteHost
    )

    if (-not (Test-Path $PublicKeyPath)) {
        throw "Public key file not found at: $PublicKeyPath"
    }

    if ($PSCmdlet.ShouldProcess($RemoteHost, "Copy public key to remote")) {
        $remotePath = "${RemoteHost}:~/tmp.pub"
        Write-Verbose "Copying $PublicKeyPath to $remotePath"
        scp $PublicKeyPath $remotePath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy public key to $remotePath"
        }
    }
}

function Initialize-AuthorizedKeys {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RemoteHost
    )
    if ($PSCmdlet.ShouldProcess($RemoteHost, "Configure authorized_keys")) {
        Write-Verbose "Initializing authorized_keys on $RemoteHost"
        ssh $RemoteHost $shellScript
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize authorized_keys on $RemoteHost"
        }
    }
}
