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
  Get the latest Lenovo updates for specified machine types
  and store in an Update Retriever style local repository.

  .DESCRIPTION
  For instances where Update Retriever cannot be used to create the local 
  repository or where full automation of the repository creation is desired. 
  This PowerShell script can be customized and executed on a regular basis to 
  get the latest update packages. 

  .PARAMETER MachineTypes
  Mandatory: False
  Data type: String
  Must be a string of machine type ids separated with comma and surrounded
  by single quotes. Although multiple machine types can be specified, it is
  recommended to keep the list small to reduce download times for all updates.
  If no value is specified, the machine type of the device running the script
  will be used.

  .PARAMETER OS
  Mandatory: False
  Data type: String
  Must be a string of '10' or '11'. The default if no value is specified will
  be determined by the OS of the device the script is running on.

  .PARAMETER PackageTypes
  Mandatory: False
  Data type: String
  Must be a string of Package Type integers separated by commas and surrounded 
  by single quotes. The possible values are:
  1: Application
  2: Driver
  3: BIOS
  4: Firmware
  
  The default if no value is specified will be all package types.

  .PARAMETER RebootTypes
  Mandatory: False
  Data type: String
  Must be a string of integers, separated by commas, representing the different
  boot types and surrounded by single quotes:
  0: No reboot required
  1: Forces a reboot (not recommended in a task sequence)
  3: Requires a reboot (but does not initiate it)
  4: Forces a shutdown (not used much anymore)
  5: Delayed forced reboot (used by many firmware updates)
  The default if no value is specified will be all RebootTypes.

  .PARAMETER RepositoryPath
  Mandatory: True
  Data type: string
  Must be a fully qualified path to the folder where the local repository
  will be saved. Must be surrounded by single quotes.

  .PARAMETER LogPath
  Mandatory: False
  Data type: String
  Must be a fully qualified path. If not specified, ti-auto-repo.log will be 
  stored in the repository folder. Must be surrounded by single quotes.

  .PARAMETER RT5toRT3
  Mandatory: False
  Data type: Switch
  Specify this parameter if you want to convert Reboot Type 5 (Delayed Forced 
  Reboot) packages to be Reboot Type 3 (Requires Reboot). Only do this in
  task sequence scenarios where a Restart can be performed after the Thin
  Installer task. Use the -noreboot parameter on the Thin Installer command
  line to suppress reboot to allow the task sequence to control the restart.
  NOTE: This parameter can only be used when Thin Installer will be processing
  the updates in the repository.

  .EXAMPLE
  Get-LnvUpdatesRepo.ps1 -RepositoryPath 'C:\Program Files (x86)\Lenovo\ThinInstaller\Repository' -PackageTypes '1,2' -RebootTypes '0,3'
  
  .EXAMPLE
  Get-LnvUpdatesRepo.ps1 -RepositoryPath 'Z:\21DD' -PackageTypes '1,2,3' -RebootTypes '0,3,5' -RT5toRT3
 
  .INPUTS
  None.

  .OUTPUTS
  System.Int32. 0 - success
  System.Int32. 1 - fail

  .NOTES
  #Version 1.0 - Initial: 2024-01-04
  #Version 2.0 - 2024-11-19
    - Incorporate SCCM TS Module
    - Removed ScanOnly parameter
    - Adjust logic for saving content to local repo.
    - Additional formatting
#>

Param(
  [Parameter(Mandatory = $false)]
  [string]$MachineTypes,

  [Parameter(Mandatory = $false)]
  [string]$OS,

  [Parameter(Mandatory = $false)]
  [string]$PackageTypes,

  [Parameter(Mandatory = $false)]
  [string]$RebootTypes,

  [Parameter(Mandatory = $true)]
  [string]$RepositoryPath,
  
  [Parameter(Mandatory = $false)]
  [string]$LogPath,

  [Parameter(Mandatory = $false)]
  [switch]$RT5toRT3
)

#region Parameters validation
function Confirm-ParameterPattern
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RegEx,
    [Parameter(Mandatory = $false)]
    [string]$Value,
    [Parameter(Mandatory = $true)]
    [bool]$Mandatory,
    [Parameter(Mandatory = $false)]
    [string]$ErrorMessage
  )

  if ($Value)
  {
    $result = $Value -match $RegEx

    if ($result -ne $true)
    {
      Write-Output $ErrorMessage; Exit 1
    }
  }
}
#endregion

#region Messages
function Write-LogError
{
  Param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )
  $logline = "[LNV_ERROR_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message" 
  Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber -Force
  return $logline
}

function Write-LogWarning
{
  Param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )
  $logline = "[LNV_WARNING_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message"
  Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber
  return $logline
}

function Write-LogInformation
{
  Param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )
  $logline = "[LNV_INFORMATION_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message"
  Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber
  return $logline 
}
#endregion

#region helpers
function Get-XmlFile
{
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Url
  )

  $xmlFile = $null

  #Retry policy
  $stop = $false
  $retryCount = 0
 
  do
  {
    try
    {
      [System.XML.XMLDocument]$xmlFile = (New-Object -TypeName System.Net.WebClient).DownloadString($Url)
      $stop = $true
    }
    catch
    {
      if ($retrycount -gt 3)
      {
        $stop = $true
      }
      else
      {
        Start-Sleep -Seconds 5
        $retrycount = $retrycount + 1
      }
    }
  }
  while ($stop -eq $false)

  return $xmlFile
}

function Get-File
{
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Url,
    [Parameter(Mandatory = $True)]
    [string]$DestinationPath,
    [Parameter(Mandatory = $True)]
    [int]$ExpectedFileSize,
    [Parameter(Mandatory = $True)]
    [string]$ExpectedFileCRC
  )

  #Retry policy
  $stop = $false
  $retryCount = 0
 
  do
  {
    try
    {
      (New-Object -TypeName System.Net.WebClient).DownloadFile($Url, $DestinationPath)

      #Check file size and CRC and delete the folder if they are not equal
      $actualFileCRC = $(Get-FileHash -Path $DestinationPath -Algorithm SHA256).Hash
      $actualFileSize = $(Get-Item -Path $DestinationPath).Length

      #Return if the file is .txt
      $extension = [IO.Path]::GetExtension($DestinationPath)
      if ($extension -eq ".txt" -or $extension -eq ".html")
      {
        $stop = $true
        return $true
      }

      if ($actualFileCRC -eq $ExpectedFileCRC -and $ExpectedFileSize -eq $actualFileSize)
      {
        $stop = $true
        return $true
      }
      else
      {
        if ($retrycount -gt 3)
        {
          $stop = $true
        }
        else
        {
          Start-Sleep -Seconds 5
          $retrycount = $retrycount + 1
        }
      } 
    }
    catch
    {
      if ($retrycount -gt 3)
      {
        $stop = $true
      }
      else
      {
        Start-Sleep -Seconds 5
        $retrycount = $retrycount + 1
      }
    }
  }
  while ($stop -eq $false)

  return $false
}

function Confirm-Parameters
{
  Confirm-ParameterPattern -Value $RepositoryPath `
    -Mandatory $true `
    -RegEx "^((?:~?\/)|(?:(?:\\\\\?\\)?[a-zA-Z]+\:))(?:\/?(.*))?$" `
    -ErrorMessage "RepositoryPath parameter must be a properly formatted and fully qualified path to an existing folder where the local repository resides."
  
  Confirm-ParameterPattern -Value $LogPath `
    -Mandatory $false `
    -RegEx "^((?:~?\/)|(?:(?:\\\\\?\\)?[a-zA-Z]+\:))(?:\/?(.*))?$" `
    -ErrorMessage "LogPath parameter must be a properly formatted and fully qualified path to file"
  
  $trimmedMachineTypes = $MachineTypes.Trim()
  if ($trimmedMachineTypes -eq '')
  {
    if ((Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystemProduct).Vendor.ToLower -eq 'lenovo')
    {
      Write-LogError "This script is only supported on Lenovo commercial PC products."; Exit 1
    }
    $trimmedMachineType = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystemProduct).Name.Substring(0, 4).Trim()
    $global:MachineTypesArray = $trimmedMachineType
  }
  else
  {
    $global:MachineTypesArray = $trimmedMachineTypes -split ',' -replace '^\s+|\s+$'
  }
   
  if ($global:MachineTypesArray.Length -eq 0)
  {
    Write-LogError "MachineTypes parameter must contain at least one four character machine type of a Lenovo PC."; Exit 1
  }
}
#endregion

#region globals
#region Database XSD
$dbxsd_text = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
       <xs:element name="Database">
             <xs:complexType>
                  <xs:sequence>
                        <xs:element name="Package" type="PackageType" minOccurs="0" maxOccurs="unbounded"/>
                  </xs:sequence>
                  <xs:attribute name="version" use="required">
                    <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                    </xs:simpleType>
                 </xs:attribute>
                  <xs:attribute name="cloud" type="xs:string" use="optional"/>
             </xs:complexType>
       </xs:element>
       <xs:element name="FileName">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
       <xs:element name="LocalPath">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
       <xs:element name="Mode">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
       <xs:complexType name="PackageType">
             <xs:sequence>
                  <xs:element ref="FileName"/>
                  <xs:element ref="Version"/>
                  <xs:element ref="ReleaseDate"/>
                  <xs:element ref="Size"/>
                  <xs:element ref="URL"/>
                  <xs:element ref="Mode"/>
                  <xs:element ref="Type"/>
                  <xs:element ref="Status"/>
                  <xs:element ref="PreviousStatus"/>
                  <xs:element ref="LocalPath"/>
                  <xs:element ref="Severity"/>
                  <xs:element ref="DisplayLicense"/>
                  <xs:element name="SystemCompatibility" type="SystemCompatibilityType"/>
             </xs:sequence>
             <xs:attribute name="id" use="required">
                  <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                  </xs:simpleType>
             </xs:attribute>
             <xs:attribute name="name" use="required">
                  <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                  </xs:simpleType>
             </xs:attribute>
             <xs:attribute name="description" use="required">
                  <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                  </xs:simpleType>
             </xs:attribute>
       </xs:complexType>
       <xs:element name="PreviousStatus">
             <xs:simpleType>
                  <xs:restriction base="xs:string">
                        <xs:enumeration value="Active"/>
                        <xs:enumeration value="Archived"/>
                        <xs:enumeration value="Test"/>
                        <xs:enumeration value="Draft"/>
                        <xs:enumeration value="Hidden"/>
                        <xs:enumeration value="Default"/>
                        <xs:enumeration value="None"/>
                  </xs:restriction>
             </xs:simpleType>
       </xs:element>
       <xs:element name="ReleaseDate">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
       <xs:element name="Size">
             <xs:simpleType>
                  <xs:restriction base="xs:long"/>
             </xs:simpleType>
       </xs:element>
       <xs:element name="Status">
             <xs:simpleType>
                  <xs:restriction base="xs:string">
                        <xs:enumeration value="Active"/>
                        <xs:enumeration value="Archived"/>
                        <xs:enumeration value="Test"/>
                        <xs:enumeration value="Draft"/>
                        <xs:enumeration value="Hidden"/>
                        <xs:enumeration value="Default"/>
                  </xs:restriction>
             </xs:simpleType>
       </xs:element>
       <xs:element name="Severity">
             <xs:simpleType>
                  <xs:restriction base="xs:string">
                        <xs:enumeration value="Critical"/>
                        <xs:enumeration value="Recommended"/>
                        <xs:enumeration value="Optional"/>
                        <xs:enumeration value="Default"/>
                  </xs:restriction>
             </xs:simpleType>
       </xs:element>
       <xs:element name="DisplayLicense">
             <xs:simpleType>
                  <xs:restriction base="xs:string">
                        <xs:enumeration value="Display"/>
                        <xs:enumeration value="NotDisplay"/>
                        <xs:enumeration value="Default"/>
                  </xs:restriction>
             </xs:simpleType>
       </xs:element>
       <xs:complexType name="SystemType">
             <xs:attribute name="mtm" use="required">
                  <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                  </xs:simpleType>
             </xs:attribute>
             <xs:attribute name="os" use="required">
                  <xs:simpleType>
                        <xs:restriction base="xs:string"/>
                  </xs:simpleType>
             </xs:attribute>
       </xs:complexType>
       <xs:complexType name="SystemCompatibilityType">
             <xs:sequence>
                  <xs:element name="System" type="SystemType" minOccurs="0" maxOccurs="unbounded"/>
             </xs:sequence>
       </xs:complexType>
       <xs:element name="Type">
             <xs:simpleType>
                  <xs:restriction base="xs:string">
                        <xs:enumeration value="Quest"/>
                        <xs:enumeration value="Local"/>
                  </xs:restriction>
             </xs:simpleType>
       </xs:element>
       <xs:element name="URL">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
       <xs:element name="Version">
             <xs:simpleType>
                  <xs:restriction base="xs:string"/>
             </xs:simpleType>
       </xs:element>
  </xs:schema>
"@
#endregion

$global:MachineTypesArray = $null

$global:rt = @()

if ($RebootTypes -ne '')
{
  $global:rt = $RebootTypes.Split(',')
}
else
{
  $global:rt = @('0', '1', '3', '4', '5')
}

$global:pt = @()
if ($PackageTypes -ne '')
{
  $global:pt = $PackageTypes.Split(',')
}
else
{
  $global:pt = @('1', '2', '3', '4')
}

<#
  Get OS - if not specified or not one of 11 or 10, then default to 10
#>
if ($OS -eq '')
{
  $OS = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_OperatingSystem).Version
  if ($OS -match '10.0.1')
  {
    $global:OS = 'Win10'
    $global:OSName = 'Windows 10'  
  }
  elseif ($OS -match '10.0.2')
  {
    $global:OS = 'Win11'
    $global:OSName = 'Windows 11'
  }  
}
elseif ($OS -eq '10')
{
  $global:OS = 'Win10'
  $global:OSName = 'Windows 10'
}
elseif ($OS -eq '11')
{
  $global:OS = 'Win11'
  $global:OSName = 'Windows 11'
}
else
{
  $global:OS = 'Win10'
  $global:OSName = 'Windows 10'
}

if ($LogPath -eq '')
{
  $LogPath = "$RepositoryPath\ti-auto-repo.log"
}
#endregion

#region SCCM-TSEnvironment
#Credit to https://github.com/sombrerosheep/TaskSequenceModule
function Confirm-TSProgressUISetup()
{
  if ($null -eq $Script:TaskSequenceProgressUi)
  {
    try { $Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI }
    catch { throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_" }
  }
}

function Confirm-TSEnvironmentSetup()
{
  if ($null -eq $Script:TaskSequenceEnvironment)
  {
    try { $Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment }
    catch { throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_" }
  }
}

function Show-TSActionProgress()
{
  param(
    [Parameter(Mandatory = $true)]
    [string] $Message,
    [Parameter(Mandatory = $true)]
    [long] $Step,
    [Parameter(Mandatory = $true)]
    [long] $MaxStep
  )

  Confirm-TSProgressUISetup
  Confirm-TSEnvironmentSetup

  $Script:TaskSequenceProgressUi.ShowActionProgress(`
      $Script:TaskSequenceEnvironment.Value("_SMSTSOrgName"), `
      $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), `
      $Script:TaskSequenceEnvironment.Value("_SMSTSCustomProgressDialogMessage"), `
      $Script:TaskSequenceEnvironment.Value("_SMSTSCurrentActionName"), `
      [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSNextInstructionPointer")), `
      [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSInstructionTableSize")), `
      $Message, `
      $Step, `
      $MaxStep)
}
#endregion

Confirm-TSProgressUISetup
Confirm-TSEnvironmentSetup

$ErrorActionPreference = 'SilentlyContinue'

try
{
  Confirm-Parameters
  
  <#
    If the repository folder already exists:
      * Comment or uncomment lines within the 'if' clause below to achieve the desired behavior.
  #>

  $repositoryFolderExists = Test-Path -Path $RepositoryPath
  if ($repositoryFolderExists -eq $true)
  {
    # repopulate each time with latest content
    Remove-Item -Path $RepositoryPath -Recurse

    #exit script and use existing repo
    #Write-LogInformation "Exiting script as repo already exists."
    #Exit
  }

  <#
    1.
      Prepare repository location
  #>
  New-Item -ItemType Directory -Force $RepositoryPath | Out-Null

  $repositoryFolderExists = Test-Path -Path $RepositoryPath
  if ($repositoryFolderExists -eq $false)
  {
    Write-LogError "Failed to create folder at the following path $RepositoryPath"
    return
  }

  <#
    1.1
      Create database.xsd file
  #>
  [System.XML.XMLDocument]$dbxsd = New-Object -TypeName System.Xml.XmlDocument
  $dbxsd.LoadXml($dbxsd_text)
  $databaseXsdPath = Join-Path -Path $RepositoryPath -ChildPath "database.xsd"
  $dbxsd.Save($databaseXsdPath)

  <#
    1.2 
      Create an XML document object to contain database.xml
      Array of severities to translate integer into string
  #>
  $severities = @("None", "Critical", "Recommended", "Optional")

  #Initialize dbxml
  [System.XML.XMLDocument]$dbxml = New-Object -TypeName System.Xml.XmlDocument
  $xmldecl = $dbxml.CreateXmlDeclaration("1.0", "UTF-8", $null)
  [System.XML.XMLElement]$dbxmlRoot = $dbxml.CreateElement("Database")
  $dbxml.InsertBefore($xmldecl, $dbxml.DocumentElement) | Out-Null
  $dbxml.AppendChild($dbxmlRoot) | Out-Null
  $dbxmlRoot.SetAttribute("version", "301") | Out-Null

  <#
    2.
      Download the updates catalog from https://download.lenovo.com/catalog/<mt>_<os>.xml
  #>
  foreach ($mt in $global:MachineTypesArray)
  {
    if ($mt.Length -eq 4)
    {
      $catalogUrl = "https://download.lenovo.com/catalog/$mt`_$global:OS.xml"
      $catalog = Get-XmlFile -Url $catalogUrl
      if (-Not ($catalog))
      {
        Write-LogError "Failed to download the updates catalog from $catalogUrl. Check that $mt is a valid machine type."; Exit 1
        Show-TSActionProgress -Message "Failed to download the updates catalog from $catalogUrl. Check that $mt is a valid machine type." -Step 1 -MaxStep 1
      }

      <#
        2.1.
          Get URLs for package descriptors that match PackageIds
      #>
      $packages = @{}
      $packagesUrls = $catalog.packages.package.location

      foreach ($url in $packagesUrls)
      {
        $filename = $url.Substring($url.LastIndexOf("/") + 1)
        $separatorIndex = $filename.IndexOf('.')
        $packageID = $filename.Substring(0, $separatorIndex - 3)

        $packages.Add($packageId, $url)
      }
      
      $packagesCount = $packages.Count
      Write-LogInformation "Found $packagesCount for the system"
      Show-TSActionProgress -Message "Found $packagesCount updates for the system" -Step 1 -MaxStep 1

      if ($packagesCount -eq 0)
      {
        Write-LogError "No updates found in the updates catalog"
        Show-TSActionProgress -Message "No updates found in the updates catalog" -Step 1 -MaxStep 10
      }

      if ($packagesCount -ne 0)
      {

        #For each package, get package descriptor XML
        foreach ($item in $packages.GetEnumerator())
        {
          $packageId = $item.Key
          $url = $item.Value

          #Download package descriptor XML to this subfolder
          [xml] $pkgXML = Get-XmlFile -Url $url
          if (-Not ($pkgXml))
          {
            Write-LogError "Failed to download the package descriptor from $url"
            Show-TSActionProgress -Message "Failed to download the package descriptor from $url" -Step 1 -MaxStep 1
            Remove-Item -Path $packagePath -Recurse
            continue
          }

          try
          {
            #Get real package ID from XML attribute
            $packageID = $pkgXML.Package.id
          }
          catch
          {
            Write-LogError "Could not find package ID for $url"
            Show-TSActionProgress -Message "Could not find package ID for $url" -Step 1 -MaxStep 1
            continue
          }
          
          #Filter by Package Type and Reboot Type
          if (($global:rt -contains $pkgXML.Package.Reboot.type) -and ($global:pt -contains $pkgXML.Package.PackageType.type))
          {
            #Save package xml
            #Create a subfolder using package ID as the folder name
            $packagePath = Join-Path -Path $RepositoryPath -ChildPath $packageId
            New-Item -ItemType Directory -Force $packagePath | Out-Null

            $packageFolderExists = Test-Path -Path $packagePath
            if ($packageFolderExists -eq $False)
            {
              Write-LogError "Failed to create folder at the following path $RepositoryPath\$packageId"
              Show-TSActionProgress -Message "Failed to create folder at the following path $RepositoryPath\$packageId" -Step 1 -MaxStep 1
              continue
            }

            Write-LogInformation "Getting $packageID..."
            Show-TSActionProgress -Message "Getting $packageID..." -Step 1 -MaxStep 10

            #Gather data needed for dbxml
            $__packageID = $pkgXML.Package.id
            $__name = $pkgXML.Package.name
            $__description = $pkgXML.Package.Title.Desc.InnerText
            $__filename = $url.SubString($url.LastIndexOf('/') + 1)
            $__version = $pkgXML.Package.version
            $__releasedate = $pkgXML.Package.ReleaseDate
            #$__size = $pkgXML.Package.Files.Installer.File.Size
            $__size = 0
            $__url = $url.SubString(0, $url.LastIndexOf('/') + 1)
            $__localRepositoryPath = [IO.Path]::Combine($RepositoryPath, $__packageID, $__filename)
            $__localpath = [IO.Path]::Combine("\", $__packageID, $__filename)
            $__severity = $severities[$pkgXML.Package.Severity.type]
            
            try
            {
              (New-Object -TypeName System.Net.WebClient).DownloadFile($url, $__localRepositoryPath)
                            
              #alter Reboot Type 5 to 3 if RT5toRT3 is specified
              if (($RT5toRT3.IsPresent) -and ($pkgXML.Package.Reboot.type -eq '5'))
              {
                Write-LogInformation "Changing reboot type for $packageID"
                $xml = [xml](Get-Content -Path $__localRepositoryPath)
                $xml.Package.Reboot.type = '3'
                $xml.Save($__localRepositoryPath)
              }
            }
            catch
            {
              Write-LogError "Failed to save xml at the following path $($__localRepositoryPath)"
              Show-TSActionProgress -Message "Failed to save xml at the following path $($__localRepositoryPath)" -Step 1 -MaxStep 1
              continue
            }

            <#  
              Load package descriptor XML and download each of the files referenced under the <Files> tag.
              Note that the files will be located at the same relative path as the package descriptor XML on https://download.lenovo.com/...
            #>
            $fileNameElements = @()
            $installerFile = @()
            $readmeFile = @()
            $externalFiles = @()
            Write-LogInformation "Get files for downloading..."
            Show-TSActionProgress -Message "Get files for downloading..." -Step 4 -MaxStep 10

            $installerFile = $pkgXML.GetElementsByTagName("Files").GetElementsByTagName("Installer").GetElementsByTagName("File")
            try
            {
              $readmeFile = $pkgXML.GetElementsByTagName("Files").GetElementsByTagName("Readme").GetElementsByTagName("File")
            }
            catch
            {
              Write-LogInformation "No readme file specified."
            }
            try
            {
              $externalFiles = $pkgXML.GetElementsByTagName("Files").GetElementsByTagName("External").GetElementsByTagName("File")
            }
            catch
            {
              Write-LogInformation "No external detection files specified."
            }
                
            if ($readmeFile) { $fileNameElements += $readmeFile }
            if ($externalFiles) { $fileNameElements += $externalFiles }
                
            $fileNameElements += $installerFile

            #$fileNameElements = $pkgXML.GetElementsByTagName("Files").GetElementsByTagName("File")
            foreach ($element in $fileNameElements)
            {
              $filename = $element.GetElementsByTagName("Name").InnerText
              $expectedFileSize = $element.GetElementsByTagName("Size").InnerText
              $expectedFileCRC = $element.GetElementsByTagName("CRC").InnerText

              $fileUrl = $__url + "/" + $filename
              $fileDestinationPath = [IO.Path]::Combine($RepositoryPath, $__packageID, $filename)

              try
              {
                $fileDownloadParams = @{
                  Url              = $fileUrl
                  DestinationPath  = $fileDestinationPath
                  ExpectedFileSize = $expectedFileSize
                  ExpectedFileCRC  = $expectedFileCRC
                }

                $fileDownloadResult = Get-File @fileDownloadParams
              }
              catch
              {
                Write-LogError($_)
              }                            
                
              #Delete the package folder if one of the files did not download or the size or CRC is invalid
              if ($fileDownloadResult -eq $false)
              {
                Write-LogWarning "Failed to download the file $__url/$filename. Package $__packageID will be deleted"
                Show-TSActionProgress -Message "Failed to download the file $__url/$filename. Package $__packageID will be deleted" -Step 1 -MaxStep 1
                $packageFolder = [IO.Path]::Combine($RepositoryPath, $__packageID)
                Remove-Item -Path $packageFolder -Recurse

                break
              }
              else
              {
                $__size += $expectedFileSize
                Write-LogInformation "Downloaded $filename"
                Show-TSActionProgress -Message "Downloaded $filename" -Step 8 -MaxStep 10
              }
            }

            #region Build xml elements
            $_package = $dbxml.CreateElement("Package")
            $_package.SetAttribute("id", $__packageID) | Out-Null
            $_package.SetAttribute("name", $__name) | Out-Null
            $_package.SetAttribute("description", $__description) | Out-Null

            $sub1 = $dbxml.CreateElement("FileName")
            $sub1text = $dbxml.CreateTextNode($__filename)
            $sub1.AppendChild($sub1text) | Out-Null

            $sub2 = $dbxml.CreateElement("Version")
            $sub2text = $dbxml.CreateTextNode($__version)
            $sub2.AppendChild($sub2text) | Out-Null

            $sub3 = $dbxml.CreateElement("ReleaseDate")
            $sub3text = $dbxml.CreateTextNode($__releasedate)
            $sub3.AppendChild($sub3text) | Out-Null

            $sub4 = $dbxml.CreateElement("Size")
            $sub4text = $dbxml.CreateTextNode($__size)
            $sub4.AppendChild($sub4text) | Out-Null

            $sub5 = $dbxml.CreateElement("URL")
            $sub5text = $dbxml.CreateTextNode($__url)
            $sub5.AppendChild($sub5text) | Out-Null

            $sub6 = $dbxml.CreateElement("Mode")
            $sub6text = $dbxml.CreateTextNode("")
            $sub6.AppendChild($sub6text) | Out-Null

            $sub7 = $dbxml.CreateElement("Type")
            $sub7text = $dbxml.CreateTextNode("Quest")
            $sub7.AppendChild($sub7text) | Out-Null

            $sub8 = $dbxml.CreateElement("Status")
            $sub8text = $dbxml.CreateTextNode("Active")
            $sub8.AppendChild($sub8text) | Out-Null

            $sub9 = $dbxml.CreateElement("PreviousStatus")
            $sub9text = $dbxml.CreateTextNode("None")
            $sub9.AppendChild($sub9text) | Out-Null

            $sub10 = $dbxml.CreateElement("LocalPath")
            $sub10text = $dbxml.CreateTextNode($__localpath)
            $sub10.AppendChild($sub10text) | Out-Null

            $sub11 = $dbxml.CreateElement("Severity")
            $sub11text = $dbxml.CreateTextNode($__severity)
            $sub11.AppendChild($sub11text) | Out-Null

            $sub12 = $dbxml.CreateElement("DisplayLicense")
            $sub12text = $dbxml.CreateTextNode("NotDisplay")
            $sub12.AppendChild($sub12text) | Out-Null

            $sub13 = $dbxml.CreateElement("SystemCompatibility")
            $sub13sub = $dbxml.CreateElement("System")
            $sub13sub.SetAttribute("mtm", $mt)
            $sub13sub.SetAttribute("os", $global:OSName)
            $sub13.AppendChild($sub13sub) | Out-Null

            #Set details for the update and populate database.xml
            $_package.AppendChild($sub1) | Out-Null
            $_package.AppendChild($sub2) | Out-Null
            $_package.AppendChild($sub3) | Out-Null
            $_package.AppendChild($sub4) | Out-Null
            $_package.AppendChild($sub5) | Out-Null
            $_package.AppendChild($sub6) | Out-Null
            $_package.AppendChild($sub7) | Out-Null
            $_package.AppendChild($sub8) | Out-Null
            $_package.AppendChild($sub9) | Out-Null
            $_package.AppendChild($sub10) | Out-Null
            $_package.AppendChild($sub11) | Out-Null
            $_package.AppendChild($sub12) | Out-Null
            $_package.AppendChild($sub13) | Out-Null

            $dbxml.LastChild.AppendChild($_package) | Out-Null
            #endregion
          }
        }
      }
    }
    else
    {
      Write-LogWarning "Skipping $mt as it is not a valid machine type."
    }
  }
  
  <#
    3.
        Write dbxml file
  #>
  $databaseXmlPath = Join-Path -Path $RepositoryPath -ChildPath "database.xml"
  $dbxml.Save($databaseXmlPath)
    
  Write-LogInformation "Script execution finished."
  Show-TSActionProgress -Message "Packages have been downloaded." -Step 10 -MaxStep 10
}
catch
{
  Write-LogError "Unexpected error occurred:`n $_"; Exit 1
}