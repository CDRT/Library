# set working directory for testing
$wd = "C:\git\cdrt\library\tsc-tds\"
Set-Location -Path $wd
# Read in TDS file from C:\ProgramData\Intel\TrustedDeviceSetup\Intel_TDS_Health_Report_<timestamp>.xml
# Get most recently modified .xml report file
$report = Get-Childitem -filter "Intel_TDS_Health_Report*.xml" | Sort-Object LastWriteTime -Descending | Select-Object Name
$appraisal_path = $wd + $report.Name

[xml]$appraisal = Get-Content -Path $appraisal_path
$result = $appraisal.Intel_TDS_Health_Report.HealthState.State
$hash = @{ TrustedDeviceSetup = $result }   
return $hash | ConvertTo-Json -Compress