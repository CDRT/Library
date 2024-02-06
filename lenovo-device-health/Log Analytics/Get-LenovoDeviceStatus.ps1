<#
.SYNOPSIS
    Collect Lenovo specific data and upload to Log Analytics Workspace

.DESCRIPTION
    Script should be deployed as a Remediation in Intune. It's recommended to install Lenovo Commercial Vantage on the endpoints with the following policies enabled:
        - Configure System Update
        - Write warranty information to WMI table
        - Write battery information to WMI table

.EXAMPLE
    Get-LenovoDeviceStatus.ps1

.NOTES
    Author: Philip Jorgensen
    Created: 2022-09-26
    Updated: 2024-02-06

    Version history:
    1.0.0 - (2022-09-26) Script created
    1.0.1 - (2024-02-06) Script redesign to include LDMM (Lenovo Device Management Module) for gathering additional data.
#>

# Replace with your Log Analytics Workspace ID
$customerId = ""  

# Replace with your Primary Key
$sharedKey = ""

# Specify the name of the record type that you'll be creating
$logTypeDeviceHealth = "Lenovo_Device_Health"
$logTypeDeviceProperties = "Lenovo_Device_Properties"

<#  Create the functions to create the authorization signature
    https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api
#>
$TimeStampField = ""

#region functions
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
    return $authorization
}

# Create the function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization"        = $signature;
        "Log-Type"             = $logType;
        "x-ms-date"            = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}
#endregion functions

##############

$ErrorActionPreference = 'SilentlyContinue'

$ComputerSystem = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem
if ($ComputerSystem.Manufacturer -ne "LENOVO")
{
    Write-Output "Not a Lenovo system..."; Exit 0
}

#region IMPORT LDMM
# Download/Import LDMM
if (Get-Module -ListAvailable -Name LnvDeviceManagement)
{
    Write-Output "LDMM Already Installed"
}
else
{
    try
    {
        # URL to zip
        $ModuleSource = "https://download.lenovo.com/cdrt/tools/ldmm_1.0.0.zip"
        # PS module location
        $ModulePath = [System.IO.Path]::Combine($env:ProgramFiles, "WindowsPowerShell", "Modules")

        # Path to save zip
        $ModuleTemp = [System.IO.Path]::Combine($env:ProgramData, "Lenovo")

        # Check if the ZIP file already exists
        if (-not (Test-Path -Path (Join-Path -Path $ModuleTemp -ChildPath ldmm_1.0.0.zip)))
        {
            # Download/Extract to PS modules directory
            Invoke-WebRequest -Uri $ModuleSource -OutFile (Join-Path -Path $ModuleTemp -ChildPath ldmm_1.0.0.zip) -UseBasicParsing
            Expand-Archive -Path (Join-Path -Path $ModuleTemp -ChildPath ldmm_1.0.0.zip) -DestinationPath $ModulePath -Force
        }
        else
        {
            Write-Output "LDMM ZIP file already exists. Skipping download."
        }

        # Check if the module was imported successfully
        if (Get-Module -ListAvailable -Name LnvDeviceManagement)
        {
            Write-Output "LDMM Installed Successfully"
        }
        else
        {
            Write-Error "Failed to import LnvDeviceManagement module."
        }
    }
    catch
    {
        Write-Error -Message $_.Exception.Message
    }
}

#endregion LDMM

#region WMICHECKS
$CommercialVantage = (Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq "E046963F.LenovoSettingsforEnterprise" })
if ($null -eq $CommercialVantage)
{
    Write-Output "Commercial Vantage not installed"
}

$LenovoUpdates = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_Updates
if ($null -eq $LenovoUpdates)
{
    Write-Output "Lenovo Updates WMI class not present. Run Commercial Vantage and initiate a check for updates"
}

if ($ComputerSystem.SystemFamily -match "ThinkPad")
{
    $Battery = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_Battery
    if ($null -eq $Battery)
    {
        $Battery = "Battery Data Unavailable"
        Write-Output "Lenovo Battery WMI class not present. Enable the Commercial Vantage policy to write battery info to WMI"
    }
    else
    {
        $Battery = $Battery.BatteryHealth
    }
}

$Warranty = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_WarrantyInformation
if ($null -eq $Warranty -or $Warranty.EndDate.Equals("null"))
{
    $Warranty = "Warranty Data Unavailable"
    Write-Output "Lenovo Warranty WMI class not present. Enable the Commercial Vantage policy to write warranty information to WMI"
}
else
{
    # Format warranty date for Azure Monitor Workbook
    $s_Array = $Warranty.EndDate.Split("/")
    if ($s_Array[0].Length -eq 1) { $s_Array[0] = "0" + $s_Array[0] }
    if ($s_Array[1].Length -eq 1) { $s_Array[1] = "0" + $s_Array[1] }
    $s_Array[2] = $s_Array[2].Substring(0, 4)
    $Warranty = "{0}-{1}-{2}" -f $s_Array[2], $s_Array[0], $s_Array[1]
}
#endregion WMICHECKS

#region INVENTORY
$updateResults = foreach ($Update in $LenovoUpdates)
{
    [PSCustomObject]@{
        Hostname  = $env:COMPUTERNAME
        PackageID = $Update.PackageID
        Severity  = $Update.Severity
        Status    = $Update.Status
        Title     = $Update.Title
        Version   = $Update.Version
    }
}

$updateResultsJson = $updateResults | ConvertTo-Json

# Device Updates param splat
$deviceUpdateParams = @{
    CustomerId = $customerId
    SharedKey  = $sharedKey
    Body       = ([System.Text.Encoding]::UTF8.GetBytes($updateResultsJson))
    LogType    = $logTypeDeviceHealth
}

$deviceProperties = [PSCustomObject]@{
    Hostname             = $env:COMPUTERNAME
    MTM                  = $ComputerSystem.Model.Substring(0, 4).Trim()
    Product              = $ComputerSystem.SystemFamily
    Serial               = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_BIOS).SerialNumber
    BatteryHealth        = $Battery
    WarrantyEnd          = $Warranty
    InstalledBiosVersion = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_BIOS).SMBIOSBIOSVersion
    CVE                  = Get-LnvCVE | Sort-Object
    AvailableBiosVersion = Get-LnvAvailableBiosVersion
}

$devicePropertiesJson = $deviceProperties | ConvertTo-Json

# Device Properties param splat
$devicePropertyParams = @{
    CustomerId = $customerId
    SharedKey  = $sharedKey
    Body       = ([System.Text.Encoding]::UTF8.GetBytes($devicePropertiesJson))
    LogType    = $logTypeDeviceProperties
}
#endregion INVENTORY

# Sending data to API
$deviceHealthlogResponse = Post-LogAnalyticsData @deviceUpdateParams
$devicePropertieslogResponse = Post-LogAnalyticsData @devicePropertyParams

if ($deviceHealthlogResponse -and $devicePropertieslogResponse -match "200")
{
    Write-Output "Data sent to Log Analytics"
}
else
{
    Write-Error "Failed to send data to Log Analytics. Health Response: $deviceHealthlogResponse, Properties Response: $devicePropertieslogResponse"
}

Exit 0