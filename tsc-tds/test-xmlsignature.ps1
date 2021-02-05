function Verify-XmlSignature {
    Param (
        [xml]$checkxml
    )
    $verifysignatureonly = $true

    # Grab signing certificate from document
    $rawCertBase64 = $checkxml.DocumentElement.Signature.KeyInfo.X509Data.X509Certificate

    if(-not $rawCertBase64){
        throw 'Unable to locate signing certificate in signed document'
        return
    }

    $rawCert = [convert]::FromBase64String($rawCertBase64)
    $signingCertificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$rawCert)

    [System.Security.Cryptography.Xml.SignedXml]$signedXml = New-Object System.Security.Cryptography.Xml.SignedXml -ArgumentList $checkxml
    $XmlNodeList = $checkxml.GetElementsByTagName("Signature")
    $signedXml.LoadXml([System.Xml.XmlElement] ($XmlNodeList[0]))
    return $signedXml.CheckSignature($signingCertificate, $verifysignatureonly)
}

#read in signed xml file
[xml]$xmltocheck = Get-Content -Path "C:\programdata\lenovo\systemupdate\sessionse\repository\n20pb10w\n20pb10w_2_.xml"

Verify-XmlSignature($xmltocheck)