# The Script Store #
This page will provide scripts and MOF files related to managing Lenovo PC's.

## The Solutions ##

Solution | Description
---------|------------
MOF | This folder in the library contains MOF files that can be used to extend the hardware inventory of Configuration Manager to collect data from custom WMI classes.<ul><li>Odometer: Represents the metrics collected from supported systems showing data such as CPU Uptime, Accelerometer Shock events, Thermal events, etc. </li><li> Lenovo Updates: Collects the updates history as stored by Lenovo System Update, Thin Installer, or Commercial Vantage</li></ul>
Odometer | This script collects and iterprets the raw Odometer data and stores it in a custom WMI class.  A MOF file for this custom class is provided in the mof folder of the Library.
Secure Wipe | This script leverages a WMI method supported by some Lenovo products that performs a secure wipe of the drive in the system.  Use carefully! See more details on the [Think Deploy Blog](https://thinkdeploy.blogspot.com/2021/02/thinkshield-secure-wipe-using-microsoft.html) 

