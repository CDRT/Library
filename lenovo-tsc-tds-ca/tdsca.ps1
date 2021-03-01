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

function Verify-XmlSignature {
    Param (
        [xml]$checkxml
    )

    $signedXml = New-Object System.Security.Cryptography.Xml.SignedXml -ArgumentList $checkxml
    $ns = new-object System.Xml.XmlNamespaceManager $checkxml.NameTable
    $ns.AddNamespace("int", "http://www.intel.com/TDS/Health_Appraisal/Report")
    $ns.AddNamespace("sig", "http://www.w3.org/2000/09/xmldsig#")
    #$XmlNodeList = $checkxml.GetElementsByTagName("Signature")
    #$signedXml.LoadXml([System.Xml.XmlElement] ($XmlNodeList[1]))
    $sigNode = $checkxml.SelectSingleNode("/int:Intel_TDS_Health_Report/sig:Signature", $ns)
    #$signedXml.LoadXml([System.Xml.XmlElement] ($XmlNodeList[2]))
    $signedXml.LoadXml([System.Xml.XmlElement] ($sigNode))
    return $signedXml.CheckSignature()
}

# set working directory for production
$wd = "C:\ProgramData\Intel\TrustedDeviceSetup\"
Set-Location -Path $wd


# Read in TDS file from C:\ProgramData\Intel\TrustedDeviceSetup\Intel_TDS_Health_Report_<timestamp>.xml
# Get most recently modified .xml report file
$report = Get-Childitem -filter "Intel_TDS_Health_Report_*.xml" | Sort-Object LastWriteTime -Descending
$appraisal_path = $wd + $report.Name

[xml]$appraisal = New-Object System.Xml.XmlDocument
$appraisal.PreserveWhitespace = $true
$appraisal.Load($appraisal_path)

<# <State> contains a result of platform's health evaluation. One of:
    * HEALTHY - if *all* of the policies evaluate to a GOOD state or NOT_EVALUATED (in case of optional policies)
    * UNHEALTHY - if *any* policy evaluates to a BAD state
    * SUSPICIOUS - if *any* policy has evaluated to a SUSPICIOUS state and *no* policies have evaluated as BAD-->
#>

# confirm XML signature and then get TDS appraisal result
if (Verify-XmlSignature($appraisal)) {
    $result = $appraisal.Intel_TDS_Health_Report.HealthState.State
    $hash = @{ TrustedDeviceSetup = $result }
}
else {
    $hash = @{ TrustedDeviceSetup = "BAD_REPORT" }
}

# return result as json
return $hash | ConvertTo-Json -Compress
