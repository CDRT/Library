#Version 1.0 - Initial
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
  Get the latest Lenovo Dock Firmware Updates for specified dock machine types
  and store in an Update Retriever style local repository.

  .DESCRIPTION
  For instances where Update Retriever cannot be used to create the local 
  repository of dock firmware updates to be used by Dock Manager, this
  PowerShell script can be customized and executed on a regular basis to get
  the latest firmware update packages. This script will remove the local 
  repository folder each time it runs and recreate it with the latest content.
  This keeps the repository folder from growing and should not be a big 
  network impact since dock firmware updates are small. Be aware that if a
  machine type is not specified in a subsequent run, its firmware updates will
  no longer be included in the repository.

  .PARAMETER MachineTypes
  Mandatory: True
  Data type: String
  Must be a string of machine type ids separated with comma and surrounded
  by double-quotes.

  .PARAMETER RepositoryPath
  Mandatory: True
  Data type: string
  Must be a fully qualified path to the folder where the local repository
  will be saved. Must be surrounded by double-quotes.

  .PARAMETER LogPath
  Mandatory: False
  Data type: String
  Must be a fully qualified path. If not specified, dock.log will be stored in
  the repository folder. Must be surrounded by double-quotes.

  .INPUTS
  None.

  .OUTPUTS
  System.Int32. 0 - success
  System.Int32. 1 - fail
#>

Param(
  [Parameter(Mandatory = $True)]
  [string]$MachineTypes,

  [Parameter(Mandatory = $True)]
  [string]$RepositoryPath,
  
  [Parameter(Mandatory = $False)]
  [string]$LogPath
)

#region Main script block
#region Parameters validation
function Confirm-ParameterPattern {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $True)]
    [string]$RegEx,
    [Parameter(Mandatory = $False)]
    [string]$Value,
    [Parameter(Mandatory = $True)]
    [bool]$Mandatory,
    [Parameter(Mandatory = $False)]
    [string]$ErrorMessage
  )

  if ($Value) {
    $result = $Value -match $RegEx

    if ($result -ne $True) {
      Write-Output($ErrorMessage)

      exit 1
    }
  }
}
#endregion

#region Messages
function Write-LogError {
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Message
  )
    $logline = "[LNV_ERROR_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message" 
    Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber
  return $logline
}

function Write-LogWarning {
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Message
  )
    $logline = "[LNV_WARNING_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message"
    Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber
  return $logline
}

function Write-LogInformation {
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Message
  )
    $logline = "[LNV_INFORMATION_$((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"))]: $Message"
    Out-File -FilePath "$LogPath" -InputObject $logline -Append -NoClobber
  return $logline 
}
#endregion

#region XSD
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


function Get-XmlFile {
  Param(
    [Parameter(Mandatory = $True)]
    [string]$Url
  )

  $xmlFile = $null

  #Retry policy
  $stop = $false
  $retryCount = 0
 
  do {
    try {
      [System.XML.XMLDocument]$xmlFile = (New-Object System.Net.WebClient).DownloadString($Url)
      $stop = $true
    }
    catch {
      if ($retrycount -gt 3) {
        $stop = $true
      }
      else {
        Start-Sleep -Seconds 5
        $retrycount = $retrycount + 1
      }
    }
  }
  While ($stop -eq $false)

  return $xmlFile
}

function Get-File {
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
 
  do {
    try {
        (New-Object System.Net.WebClient).DownloadFile($Url, $DestinationPath)

      #Check file size and CRC and delete the folder if they are not equal
      $actualFileCRC = $(Get-FileHash -Path $DestinationPath -Algorithm  SHA256).Hash
      $actualFileSize = $(Get-Item -Path $DestinationPath).Length

      #Return if the file is .txt
      $extension = [IO.Path]::GetExtension($DestinationPath)
      if ($extension -eq ".txt" ) {
        $stop = $true
        return $true
      }

      if ($actualFileCRC -eq $ExpectedFileCRC -and $ExpectedFileSize -eq $actualFileSize) {
        $stop = $true
        return $true
      }
      else {
        if ($retrycount -gt 3) {
          $stop = $true
        }
        else {
          Start-Sleep -Seconds 5
          $retrycount = $retrycount + 1
        }
      } 
    }
    catch {
      if ($retrycount -gt 3) {
        $stop = $true
      }
      else {
        Start-Sleep -Seconds 5
        $retrycount = $retrycount + 1
      }
    }
  }
  While ($stop -eq $false)

  return $false
}

$global:MachineTypesArray = $null
$global:OS = "Win10"
$global:OSName = "Windows 10"

if ($LogPath -eq "") {
  $LogPath = "$RepositoryPath\dock.log"
}

function Confirm-Parameters {
  Confirm-ParameterPattern -Value $RepositoryPath `
    -Mandatory $True `
    -RegEx "^((?:~?\/)|(?:(?:\\\\\?\\)?[a-zA-Z]+\:))(?:\/?(.*))?$" `
    -ErrorMessage "RepositoryPath parameter must be a properly formatted and fully qualified path to an existing folder where the local repository resides."

  Confirm-ParameterPattern -Value $LogPath `
    -Mandatory $False `
    -RegEx "^((?:~?\/)|(?:(?:\\\\\?\\)?[a-zA-Z]+\:))(?:\/?(.*))?$" `
    -ErrorMessage "LogPath parameter must be a properly formatted and fully qualified path to file"

  $trimmedMachineTypes = $MachineTypes.Trim()
  $global:MachineTypesArray = $trimmedMachineTypes -split ',' -replace '^\s+|\s+$'
  if ($global:MachineTypesArray.Length -eq 0) {
    Write-LogError "MachineTypes parameter must contain at least one four character machine type of a Lenovo Dock."
  }
}

Write-LogInformation "Script execution started."
try {
  
  Confirm-Parameters
  
#Delete repository folder - repopulate each time with latest content
$repositoryFolderExists = Test-Path -Path $RepositoryPath
if ($repositoryFolderExists -eq $True) {
  Remove-Item $RepositoryPath -Recurse
}

#1 Prepare repository location
New-Item -ItemType "directory" -Force $RepositoryPath | Out-Null

$repositoryFolderExists = Test-Path -Path $RepositoryPath
if ($repositoryFolderExists -eq $False) {
Write-LogError("Failed to create folder at the following path $RepositoryPath")

exit 1
}

#1.1 Create database.xsd file
[System.XML.XMLDocument]$dbxsd = New-Object System.Xml.XmlDocument
$dbxsd.LoadXml($dbxsd_text)
$databaseXsdPath = Join-Path -Path $RepositoryPath -ChildPath "database.xsd"
$dbxsd.Save($databaseXsdPath)

#1.2 Create an XML document object to contain database.xml
#Array of severities to translate integer into string
$severities = @("None", "Critical", "Recommended", "Optional")

#Initialize dbxml
[System.XML.XMLDocument]$dbxml = New-Object System.Xml.XmlDocument
$xmldecl = $dbxml.CreateXmlDeclaration("1.0", "UTF-8", $null)
[System.XML.XMLElement]$dbxmlRoot = $dbxml.CreateElement("Database")
$dbxml.InsertBefore($xmldecl, $dbxml.DocumentElement) | Out-Null
$dbxml.AppendChild($dbxmlRoot) | Out-Null
$dbxmlRoot.SetAttribute("version", "301") | Out-Null

#2. Download the updates catalog from https://download.lenovo.com/catalog/<mt>_<os>.xml
foreach ($mt in $global:MachineTypesArray) {
  if (($mt -like "4*") -and ($mt.Length -eq 4)  ) {
      $catalogUrl = "https://download.lenovo.com/catalog/$mt`_$global:OS.xml"
      $catalog = Get-XmlFile -Url $catalogUrl
      if (!$catalog) {
          Write-LogError "Failed to download the updates catalog from $catalogUrl"

          exit 1
      }

      #2.1. Get of URLs for package descriptors that match PackageIds
      $packages = @{}
      $packagesUrls = $catalog.packages.package.location

      foreach ($url in $packagesUrls) {
          $filename = $url.Substring($url.LastIndexOf("/") + 1)
          $separatorIndex = $filename.IndexOf('.')
          $packageID = $filename.Substring(0, $separatorIndex - 3)

          $packages.Add($packageId, $url)
      }
      
      $packagesCount = $packages.Count
      Write-LogInformation "Found packages for the system: $packagesCount"

      if ($packagesCount -eq 0) {
          Write-LogError "No updates found in the updates catalog"
      }

      if ($packagesCount -ne 0) {
        #For each package, get package descriptor XML
        foreach ($item in $packages.GetEnumerator()) {
            $packageId = $item.Key
            $url = $item.Value

            #Download package descriptor XML to this subfolder
            [xml] $pkgXML = Get-XmlFile -Url $url
            if (!$pkgXml) {
                Write-LogError "Failed to download the package descriptor from $url"
                Remove-Item $packagePath -Recurse

                break
            }
            #Only process Firmware packages (type 4)
            if ($pkgXML.Package.PackageType.type -eq 4) {
                #Save package xml
                #Create a subfolder using package ID as the folder name
                $packagePath = Join-Path -Path $RepositoryPath -ChildPath $packageId
                New-Item -ItemType "directory" -Force $packagePath | Out-Null

                $packageFolderExists = Test-Path -Path $packagePath
                if ($packageFolderExists -eq $False) {
                    Write-LogError("Failed to create folder at the following path $RepositoryPath\$packageId")

                    exit 1
                }
                Write-LogInformation("Getting $packageID...")
                #Gather data needed for dbxml
                $__packageID = $pkgXML.Package.id
                $__name = $pkgXML.Package.name
                $__description = $pkgXML.Package.Title.Desc.InnerText
                $__filename = $url.SubString($url.LastIndexOf('/') + 1)
                $__version = $pkgXML.Package.version
                $__releasedate = $pkgXML.Package.ReleaseDate
                $__size = $pkgXML.Package.Files.Installer.File.Size
                $__url = $url.SubString(0, $url.LastIndexOf('/') + 1)
                $__localRepositoryPath = [IO.Path]::Combine($RepositoryPath, $__packageID, $__filename)
                $__localpath = [IO.Path]::Combine("\", $__packageID, $__filename)
                $__severity = $severities[$pkgXML.Package.Severity.type]

                $pkgXML.Save($__localRepositoryPath)

                #Load package descriptor XML and download each of the files referenced under the <Files> tag.
                #Note that the files will be located at the same relative path as the package descriptor XML on https://download.lenovo.com/...
                $fileNameElements = $pkgXML.GetElementsByTagName("Files").GetElementsByTagName("File")
                foreach ($element in $fileNameElements) {
                    $filename = $element.GetElementsByTagName("Name").InnerText
                    $expectedFileSize = $element.GetElementsByTagName("Size").InnerText
                    $expectedFileCRC = $element.GetElementsByTagName("CRC").InnerText

                    $fileUrl = $__url + "/" + $filename
                    $fileDestinationPath = [IO.Path]::Combine($RepositoryPath, $__packageID, $filename)
                    $fileDownloadResult = Get-File -Url $fileUrl `
                    -DestinationPath $fileDestinationPath `
                    -ExpectedFileSize $expectedFileSize `
                    -ExpectedFileCRC $expectedFileCRC
                
                    #Delete the package folder if one of the files did not download or the size or CRC is invalid
                    if ($fileDownloadResult -eq $false) {
                        Write-LogWarning("Failed to download the file $__url/$filename. Package $__packageID will be deleted")
                        $packageFolder = [IO.Path]::Combine($RepositoryPath, $__packageID)
                        Remove-Item $packageFolder -Recurse

                        break
                    } else {
                        Write-LogInformation("Downloaded $filename")
                    }
                }

                #Build xml elements for dbxml
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
            }
          }
      }
      } else {
        Write-LogWarning "Skipping $mt as it is not a Lenovo Dock."
      }
  
}
  
#3. Write dbxml file
$databaseXmlPath = Join-Path -Path $RepositoryPath -ChildPath "database.xml"
$dbxml.Save($databaseXmlPath)
    
Write-LogInformation "Script execution finished."

}
catch {
  Write-LogError "Unexpected error occurred:`n $_"

  exit 1
}
#endregion
