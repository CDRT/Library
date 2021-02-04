#Lenovo Trusted Supply Chain tamper check

$secure = $false
$hash = @{ TrustedDevice = $secure }   
return $hash | ConvertTo-Json -Compress
