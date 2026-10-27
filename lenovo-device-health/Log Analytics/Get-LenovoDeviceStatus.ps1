<#
.SYNOPSIS
    Collect Lenovo specific data and upload to Log Analytics Workspace

.DESCRIPTION
    Script should be deployed as a Remediation in Intune. It's recommended to install Lenovo Commercial Vantage on the endpoints with the following policies enabled:
        - Configure System Update
        - Write warranty information to WMI table
        - Write battery information to WMI table

    Data is sent to the Azure Monitor Logs Ingestion API through a Data Collection Endpoint and Data Collection Rule.
    The app registration needs the Monitoring Metrics Publisher role on the Data Collection Rule.

.EXAMPLE
    Get-LenovoDeviceStatus.ps1

.NOTES
    Author: Philip Jorgensen
    Created: 2022-09-26
    Updated: 2026-10-22

    Version history:
    1.0.0 - (2022-09-26) Script created
    1.0.1 - (2024-02-06) Script redesign to include LDMM (Lenovo Device Management Module) for gathering additional data.
    2.0.0 - (2026-10-22) Send data with the Logs Ingestion API in place of the deprecated HTTP Data Collector API.
                         Replace LDMM with the Lenovo Client Scripting Module from the PowerShell Gallery.
#>

# Replace with the Directory (tenant) ID of the app registration
$TenantId = ''

# Replace with the Application (client) ID of the app registration
$ClientId = ''

# Replace with the client secret value of the app registration
$ClientSecret = ''

# Replace with the logs ingestion endpoint of the Data Collection Endpoint
$DceEndpoint = ''

# Replace with the immutable ID of the Data Collection Rule
$DcrImmutableId = ''

# Stream names declared in the Data Collection Rule
$StreamDeviceHealth = 'Custom-LenovoDeviceHealth'
$StreamDeviceProperties = 'Custom-LenovoDeviceProperties'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

#region functions
function Get-LogsIngestionToken
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret
    )

    $tokenParams = @{
        Uri             = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        Method          = 'Post'
        ContentType     = 'application/x-www-form-urlencoded'
        Body            = @{
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = 'https://monitor.azure.com//.default'
            grant_type    = 'client_credentials'
        }
        UseBasicParsing = $true
    }

    (Invoke-RestMethod @tokenParams).access_token
}

function Send-LogsIngestionData
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [string]$DcrImmutableId,

        [Parameter(Mandatory)]
        [string]$StreamName,

        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [object[]]$Record
    )

    # The Logs Ingestion API expects a JSON array, even for a single record
    $body = ConvertTo-Json -InputObject @($Record) -Depth 3

    $sendParams = @{
        Uri             = '{0}/dataCollectionRules/{1}/streams/{2}?api-version=2023-01-01' -f $Endpoint.TrimEnd('/'), $DcrImmutableId, $StreamName
        Method          = 'Post'
        ContentType     = 'application/json'
        Headers         = @{ Authorization = "Bearer $AccessToken" }
        Body            = [System.Text.Encoding]::UTF8.GetBytes($body)
        UseBasicParsing = $true
    }

    # Returns 204 on success, non-success status codes throw
    $null = Invoke-WebRequest @sendParams
}
#endregion functions

##############

if ([string]::IsNullOrWhiteSpace($TenantId) -or [string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret) -or
    [string]::IsNullOrWhiteSpace($DceEndpoint) -or [string]::IsNullOrWhiteSpace($DcrImmutableId))
{
    Write-Output 'Logs Ingestion API variables are not set. Update the script with the app registration, DCE, and DCR values.'
    exit 1
}

$ComputerSystem = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem
if ($ComputerSystem.Manufacturer -ne 'LENOVO')
{
    Write-Output 'Not a Lenovo system...'
    exit 0
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

#region LCSM
# Install the Lenovo Client Scripting Module for the CVE and available BIOS data
$modules = @(
    #'Lenovo.Client.Update'
    'Lenovo.Client.Scripting'
)

# The gallery requires TLS 1.2, which Windows PowerShell 5.1 does not negotiate by default.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$moduleRoot = "$env:ProgramFiles\WindowsPowerShell\Modules"
Write-Output "Modules will be installed to $moduleRoot"

# Ensure the target root is on PSModulePath for this session.
if (-not ($env:PSModulePath -split ';' -contains $moduleRoot))
{
    $env:PSModulePath = $env:PSModulePath + ";$moduleRoot"
    Write-Output "Added $moduleRoot to PSModulePath"
}

foreach ($module in $modules)
{
    $params = @{
        Uri  = 'https://www.powershellgallery.com/api/v2/FindPackagesById()'
        Body = @{
            '$filter' = 'IsLatestVersion eq true'
            id        = "'$module'" # Extra quotes are required.
        }
    }
    $searchResult = Invoke-RestMethod @params
    if (-not $searchResult)
    {
        Write-Warning "$module was not found in the gallery. Skipping."
        continue
    }

    $installedVersion = Get-Module -Name $module -ListAvailable |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1 -ExpandProperty Version

    if ($installedVersion -and [version]$installedVersion -ge [version]$searchResult.properties.version)
    {
        Write-Output "$module $installedVersion is already installed. Skipping."
        continue
    }

    # Download the module archive
    Invoke-RestMethod -Uri $searchResult.content.src -OutFile module.zip

    # Expand the archive to a versioned folder under the module root.
    $params = @{
        Path        = 'module.zip'
        Destination = $moduleRoot |
            Join-Path -ChildPath $module |
            Join-Path -ChildPath $searchResult.properties.version
        Force       = $true
    }
    Expand-Archive @params

    # Clean up redundant package files.
    Get-ChildItem -Path $params.Destination |
        Where-Object Name -In @(
            '_rels'
            'package'
            '[Content_Types].xml'
            "$module.nuspec"
        ) |
        Remove-Item -Recurse
    Write-Output "Installed $module $($searchResult.properties.version) to $($params.Destination)"

    # Remove downloaded archive
    Remove-Item -Path module.zip
}


$CVE = @()
$AvailableBiosVersion = 'BIOS Data Unavailable'
try
{
    Import-Module -Name $ModuleName
    $CVE = @(Get-LnvCVE | Sort-Object)
    $AvailableBiosVersion = (Get-LnvAvailableBiosVersion) -join '; '
}
catch
{
    Write-Output "Failed to retrieve CVE and available BIOS data: $($_.Exception.Message)"
}
#endregion LCSM

#region WMICHECKS
$CommercialVantage = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq 'E046963F.LenovoSettingsforEnterprise' }
if ($null -eq $CommercialVantage)
{
    Write-Output 'Commercial Vantage not installed'
}

$LenovoUpdates = @(Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_Updates -ErrorAction SilentlyContinue)
if ($LenovoUpdates.Count -eq 0)
{
    Write-Output 'Lenovo Updates WMI class not present. Run Commercial Vantage and initiate a check for updates'
}

$Battery = $null
if ($ComputerSystem.SystemFamily -match 'ThinkPad')
{
    $BatteryInstance = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_Battery -ErrorAction SilentlyContinue
    if ($null -eq $BatteryInstance)
    {
        $Battery = 'Battery Data Unavailable'
        Write-Output 'Lenovo Battery WMI class not present. Enable the Commercial Vantage policy to write battery info to WMI'
    }
    else
    {
        $Battery = $BatteryInstance.BatteryHealth
    }
}

$WarrantyInstance = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_WarrantyInformation -ErrorAction SilentlyContinue
if ($null -eq $WarrantyInstance -or $WarrantyInstance.EndDate.Equals('null'))
{
    $Warranty = 'Warranty Data Unavailable'
    Write-Output 'Lenovo Warranty WMI class not present. Enable the Commercial Vantage policy to write warranty information to WMI'
}
else
{
    # Format warranty date for Azure Monitor Workbook
    $DateParts = $WarrantyInstance.EndDate.Split('/')
    if ($DateParts[0].Length -eq 1) { $DateParts[0] = '0' + $DateParts[0] }
    if ($DateParts[1].Length -eq 1) { $DateParts[1] = '0' + $DateParts[1] }
    $DateParts[2] = $DateParts[2].Substring(0, 4)
    $Warranty = '{0}-{1}-{2}' -f $DateParts[2], $DateParts[0], $DateParts[1]
}
#endregion WMICHECKS

#region INVENTORY
# Both tables share the same TimeGenerated so the workbook can join them
$TimeGenerated = [DateTime]::UtcNow.ToString('o')
$Bios = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_BIOS

$UpdateRecords = @(foreach ($Update in $LenovoUpdates)
    {
        [PSCustomObject]@{
            TimeGenerated = $TimeGenerated
            Hostname      = $env:COMPUTERNAME
            PackageID     = [string]$Update.PackageID
            Severity      = [string]$Update.Severity
            Status        = [string]$Update.Status
            Title         = [string]$Update.Title
            Version       = [string]$Update.Version
        }
    })

$DeviceProperties = [PSCustomObject]@{
    TimeGenerated        = $TimeGenerated
    Hostname             = $env:COMPUTERNAME
    MTM                  = $ComputerSystem.Model.Substring(0, 4).Trim()
    Product              = $ComputerSystem.SystemFamily
    Serial               = $Bios.SerialNumber
    BatteryHealth        = $Battery
    WarrantyEnd          = $Warranty
    InstalledBiosVersion = $Bios.SMBIOSBIOSVersion
    CVE                  = $CVE
    AvailableBiosVersion = $AvailableBiosVersion
}
#endregion INVENTORY

# Sending data to API
try
{
    $AccessToken = Get-LogsIngestionToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    $sendParams = @{
        Endpoint       = $DceEndpoint
        DcrImmutableId = $DcrImmutableId
        AccessToken    = $AccessToken
    }

    if ($UpdateRecords.Count -gt 0)
    {
        Send-LogsIngestionData @sendParams -StreamName $StreamDeviceHealth -Record $UpdateRecords
    }
    Send-LogsIngestionData @sendParams -StreamName $StreamDeviceProperties -Record $DeviceProperties

    Write-Output 'Data sent to Log Analytics'
}
catch
{
    $ErrorMessage = $_.Exception.Message
    if ($_.ErrorDetails)
    {
        $ErrorMessage = '{0} {1}' -f $ErrorMessage, $_.ErrorDetails.Message
    }
    Write-Output "Failed to send data to Log Analytics: $ErrorMessage"
    exit 1
}

exit 0
