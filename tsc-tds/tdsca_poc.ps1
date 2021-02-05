function Confirm-XmlSignature {
    Param (
        [xml]$checkxml
    )

    $signedXml = New-Object System.Security.Cryptography.Xml.SignedXml -ArgumentList $checkxml
    $XmlNodeList = $checkxml.GetElementsByTagName("Signature")
    $signedXml.LoadXml([System.Xml.XmlElement] ($XmlNodeList[1]))
    #$signedXml.LoadXml([System.Xml.XmlElement] ($XmlNodeList[0]))
    return $signedXml.CheckSignature()
}

# set working directory for testing
$wd = "C:\git\cdrt\library\tsc-tds\"

# set working directory for production
# $wd = "C:\ProgramData\Intel\TrustedDeviceSetup\"
Set-Location -Path $wd

# Read in TDS file from C:\ProgramData\Intel\TrustedDeviceSetup\Intel_TDS_Health_Report_<timestamp>.xml
# Get most recently modified .xml report file
$report = Get-Childitem -filter "Intel_TDS_Health_Report*.xml" | Sort-Object LastWriteTime -Descending | Select-Object Name
$appraisal_path = $wd + $report.Name

[xml]$appraisal = New-Object System.Xml.XmlDocument
$appraisal.PreserveWhitespace = $true
$appraisal.Load($appraisal_path)
#$appraisal.Load("C:\programdata\lenovo\systemupdate\sessionse\repository\n20pb10w\n20pb10w_2_-Copy.xml")


if (Verify-XmlSignature($appraisal)) {
    $result = $appraisal.Intel_TDS_Health_Report.HealthState.State
    $hash = @{ TrustedDeviceSetup = $result }   
} else {
    $hash = @{ TrustedDeviceSetup = "BAD_REPORT"}
}

return $hash | ConvertTo-Json -Compress