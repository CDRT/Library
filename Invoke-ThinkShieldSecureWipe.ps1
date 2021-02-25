<#
DISCLAIMER:

These sample scripts are not supported under any Lenovo standard support

program or service. The sample scripts are provided AS IS without warranty

of any kind. Lenovo further disclaims all implied warranties including,

without limitation, any implied warranties of merchantability or of fitness for

a particular purpose. The entire risk arising out of the use or performance of

the sample scripts and documentation remains with you. In no event shall

Lenovo, its authors, or anyone else involved in the creation, production, or

delivery of the scripts be liable for any damages whatsoever (including,

without limitation, damages for loss of business profits, business interruption,

loss of business information, or other pecuniary loss) arising out of the use

of or inability to use the sample scripts or documentation, even if Lenovo

has been advised of the possibility of such damages.
#>

<#
.SYNOPSIS
    Initiate ThinkShield Secure Wipe function to erase all contents stored on drive.

.DESCRIPTION
    This script will execute the ThinkShield Secure Wipe utility embedded in BIOS called by the WMI interface.

.PARAMETER EraseMethod
    Secure Wipe Method
        ATAN: ATA Secure Erase (Recommended)
        ATAC: ATA Cryptographic Key Reset (Recommended)

    Legacy Wipe Method
        DOD: US DoD 5520.22-M
        SPZ: Single Pass Zeros
        USNAF: US Navy & Air Force
        CCI6: CSE Canada ITSG-06
        BHI5: British HMB Infosec Standard 5, Enhanced
        GV: German VSITR
        RGP1: Russian GOST P50739-95 Level 1
        RGP4: Russian GOST P50739-95 Level 4
        RTOII: RCMP TSSIT OPS-II

.PARAMETER PasswordType
    SVP: Supervisor Password
    SMP: System Management Password
    UHDP: User Hard Disk Password
    MHDP: Master Hard Disk Password

.PARAMETER Password
    Specify password of the target system or target drive that corresponds to PasswordType

.NOTES
    Secure Wipe Method
        ATA Secure Erase
            The wipe out is executed by sending the ATA SECURITY ERASE UNIT command with the normal erase mode to the drive.
            This method is supported for SSD only. HDDs are not supported.
            The drive firmware erases all flash devices in the SSD. The completion time varies according to the storage capacity.
        ATA Cryptographic Key Reset
            The wipe out is executed by sending the ATA SECURITY ERASE UNIT command with the enhance erase mode to the drive.
            This method is supported for bot SSD and HDD. The drive firmware regenerates the encryption key inside the drive.
            All data encrypted by previous key cannot be decrypted anymore. It takes less than a second usually.
    Legacy Wipe Method
            The secure wipe method is executed by the software using standard write command.
            According to definition of the erase algorithm, defined data is written to all sectors for defined times.
            Note that this method may not wipe out all data even writing all sectors from LBA 0 to max LBA because some physical sectors may not be mapped to logical sectors due to wear leveling.
            The completion time varies according to the storage capacity and the algorithm.

    FileName: Trigger-ThinkShieldSecureWipe.ps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('ATAN', 'ATAC', 'DOD', 'SPZ', 'USNAF', 'CCI6', 'BHI5', 'GV', 'RGP1', 'RGP4', 'RTOII')]
    [string]$EraseMethod,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('SVP', 'SMP', 'UHDP', 'MHDP')]
    [string]$PasswordType,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Password
)

# For Intune detection method.
if (!(Test-Path -Path "$($env:ProgramData)\Lenovo\ThinkShield")) {
    New-Item -Path "$($env:ProgramData)\Lenovo\ThinkShield" -ItemType Directory
}
Set-Content -Path "$($env:ProgramData)\Lenovo\ThinkShield\SecureWipe.tag" -Value "Secure Wipe Pending"

$PasswordState = (Get-CimInstance -Namespace root/WMI -ClassName Lenovo_BiosPasswordSettings).PasswordState
$CimInstance = Get-CimInstance -Namespace root/WMI -ClassName Lenovo_ExecSecureWipe
$Arguments = @{Parameter = "Drv1,$EraseMethod,$PasswordType,$Password" }

try {
    if ($PasswordState -eq 0) {
        Write-Host "No SVP, SMP, or HDP is installed"
        throw "No password detected"
    }
    $SecureWipe = $CimInstance | Invoke-CimMethod -MethodName ExecSecureWipe -Arguments $Arguments
    if ($SecureWipe.return -eq 'Success') {
        Write-Host 'Reboot system to complete ThinkShield Secure Wipe'
        # Will prompt for a reboot.  Can be changed to 0
        Exit 3010
    }
    else {
        throw "Something unexpected happened"
    }
}
catch {
    Write-Host 'ThinkShield Secure Drive Wipe failed'
    Exit 1
}