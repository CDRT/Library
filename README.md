# Lenovo Library for Admins

This repository will contain scripts and files shared for administrators to use in the management and configuration of their Lenovo commercial PC products.

_These sample scripts are not supported under any Lenovo standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Lenovo further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Lenovo, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Lenovo has been advised of the possibility of such damages._

## The Solutions

Solution | Description
---------|------------
MOF | This folder in the library contains MOF files that can be used to extend the hardware inventory of Configuration Manager to collect data from custom WMI classes.<ul><li>Odometer: Represents the metrics collected from supported systems showing data such as CPU Uptime, Accelerometer Shock events, Thermal events, etc. The addition of this information in WMI is enabled by Commercial Vantage.</li><li> Lenovo Updates: Collects the updates history as stored by Lenovo System Update, Thin Installer, or Commercial Vantage</li><li>Battery: Collects the details stored in WMI by Commercial Vantage when enabled by group policy.</li><li>Warranty: Collects warranty information stored in WMI by Commercial Vantage when enabled by group policy</li></ul>
Odometer | This script collects and iterprets the raw Odometer data and stores it in a custom WMI class. This same data can be gathered by enabling the feature through group policy of Commercial Vantage. A MOF file for this custom class is provided in the mof folder of the Library.
Secure Wipe | This script leverages a WMI method supported by some Lenovo products that performs a secure wipe of the drive in the system.  Use carefully! See more details on the [Think Deploy Blog](https://blog.lenovocdrt.com/#/2021/thinkshield_secure_wipe).
Lenovo Device Health | A script and .json file provided for use with Log Analytics to define a Workbook which collects client information into a dashboard view within Intune. See more details on the [Think Deploy Blog](https://blog.lenovocdrt.com/#/2022/log_analytics_device_health).
Get-LnvDockFirmware | A script which can be used to create an "Update-Retriever-like" local repository of dock firmware updates to be used with Dock Manager in cases where Update Retriever cannot be used or a more automated method is required.
Get-LnvUpdatesRepo | This script automates the process of creating a local repository in the style of Update Retriever which can be used with Thin Installer or System Update.
