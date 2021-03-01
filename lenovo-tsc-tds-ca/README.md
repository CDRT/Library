# lenovo-tsc-tds-ca
The following content is provided to show how the value of Trusted Supply Chain/Trusted Device Setup can be leveraged with Conditional Access within Microsoft Endpoint Manager.

tdsca.ps1 : PowerShell script that reports back the Health State value from a verified TDS appraisal XML file.
tds.json  : JSON file that defines the return value for the Custom Compliance item related to TDS with title and description that can by modified to suit your purposes.

tscca.ps1 : PowerShell script that reports back the result from the TSC Verify Tool.
tsc.json  : JSON file that defines the return value for the Custom Compliance item related to TSC with title and description that can by modified to suit your purposes. 

NOTE: Do not change the other values in the JSON files as they are tied directly to the output from the PowerShell scripts.
