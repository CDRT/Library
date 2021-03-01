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

#Lenovo Trusted Supply Chain tamper check
$tscdir = "C:\ProgramData\Lenovo\TSC"
$tscvt = "C:\ProgramData\Lenovo\TSC\TSCVerifyTool.exe"
cd $tscdir

&C:\ProgramData\Lenovo\TSC\TSCVerifyTool.exe SCANREADCOMP -in scan.xml | Out-Null
$secure = $?
$hash = @{ TrustedDevice = $secure }   
return $hash | ConvertTo-Json -Compress
