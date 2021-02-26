# Lenovo Library for Admins

This repository will contain scripts and files shared for administrators to use in the management and configuration of their Lenovo commercial PC products. 

~~These sample scripts are not supported under any Lenovo standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Lenovo further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Lenovo, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Lenovo has been advised of the possibility of such damages.  ~~

## The Solutions ##
Solution | Description
---------|------------
MOF | This folder in the library contains MOF files that can be used to extend the hardware inventory of Configuration Manager to collect data from custom WMI classes.<ul><li>Odometer: Represents the metrics collected from supported systems showing data such as CPU Uptime, Accelerometer Shock events, Thermal events, etc. </li><li> Lenovo Updates: Collects the updates history as stored by Lenovo System Update, Thin Installer, or Commercial Vantage</li></ul>
Odometer | This script collects and itnerprets the raw Odometer data and stores it in a custom WMI class.  A MOF file for this custom class is provided in the mof folder of the Library.
Secure Wipe | This script can be leveraged from Configuration Manager or Intune to initiate a ThinkShield secure wipe from BIOS on supported systems. Upon reboot after this script executes on a device, a secure wipe will be performed by BIOS based on the criteria specified from the script which can be customized to fit your needs.

