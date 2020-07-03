# PSAutoDeploy
PSAutoDeploy is a PowerShell script used to build a simple deployment solution for Windows 10. The real benefit of this script is the driver injection process, which occurs after Windows deployment, so that you can use a single generic image and leverage a driver repository, instead of having different images just due to device driver differences. With Windows 10 releasing twice per year, managing many model-specific images may not be the most efficient method of deployment. 

## Requirements
Requires the following WinPE optional components;
* WinPE-WMI
* WinPE-Scripting
* WinPE-NetFx
* WinPE-PowerShell
* WinPE-DismCmdlets

[Example commands to add the above required Optional Components](https://github.com/HaroldMitts/Build-CustomPE).

Save the Windows 10 image to the deployment share. The file should be named install.wim or you will need to 
modify the PowerShell script to match the image name.

Example; `Z:\Share\Images\x64\Install.wim`

The Install.wim must be a single-indexed image. To create a single-indexed image from the base OPK install.wim, use the DISM /Export-Image command. 

32-bit Example; 
````
DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x86\Install.wim"
````

64-bit Example;	
```` 
DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x64\Install.wim"
````

For more details, see this Microsoft guide: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/system-builder-deployment-of-windows-10-for-desktop-editions

Deployment resources from the USB-B download should be saved to a network share with sub-folder named Deployment
Download the [USB-B](https://go.microsoft.com/fwlink/?linkid=872894) content from this Microsoft website and expand to your Deployment Share.

`Z:\Share\Deployment` contains the following files from the USB-B download;
* `ApplyImage.bat` - batch file used to apply image files to hard disk
* `CreatePartitions-BIOS.txt` - Text file used by ApplyImage.bat and Diskpart to setup BIOS disk partitions
* `CreatePartitions-UEFI.txt` - Text file used by ApplyImage.bat and Diskpart to setup UEFI disk partitions
* `HideRecoveryPartitions-BIOS.txt` - Text file used by ApplyImage.bat and Diskpart to hide BIOS recovery partitions
* `HideRecoveryPartitions-UEFI.txt` - Text file used by ApplyImage.bat and Diskpart to hide UEFI recovery partitions
* `Walkthrough-Deploy.bat` - batch file used to detect PC firmware type (UEFI or BIOS) and accept image file name to use for image deployment

### Device Driver Repository
Copy INF device drivers to the distribution share into sub-folders named after the BIOS values as determined by WMIC. The folder should contain a folder for each device driver, separated into sub-folders based on the device names. 

> ** Note**: DISM /Export-drivers command will automatically name the sub-folders for each driver when extracting them, so you only need to create the Manufacturer, Model, and OS architecture folders.

32-bit Driver Example;

* Z:\Share\Drivers\Lenovo\G40\32-bit\
* Z:\Share\Drivers\Lenovo\G40\32-bit\intelaud
* Z:\Share\Drivers\Lenovo\G40\32-bit\igdlh32

etc... for each device in the PC needing drivers you wish to include

64-bit Driver Example;
* Z:\Share\Drivers\Lenovo\G40\64-bit\
* Z:\Share\Drivers\Lenovo\G40\64-bit\intelaud
* Z:\Share\Drivers\Lenovo\G40\64-bit\igdlh64

etc... for each device in the PC needing drivers you wish to include

## Determine WMI Values for each Device
In order to setup driver files in the correct folder names, so that PSAutoDeploy.ps1 or other scripts like the driver injection script can find them, you need to run a few commands to see what the device manufacturer has entered into the BIOS or UEFI tables, for each device. This can be done rather easily using WMIC, from within a running Windows installation by running the following commands;

The following are PowerShell commands you can use to determine the values for manufacturer, model, and OS architecture;

Get the BIOS Value for System Manufacturer using PowerShell
````
$SysManufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer; Write-Host "PC Manufacturer: " -NoNewline; Write-Host "$SysManufacturer"`
````

Get the BIOS Value for System Model using PowerShell
````
$SysModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model; Write-Host "PC Model: " -NoNewline; Write-Host "$SysModel"
````

Get the Value for OS Architecture using PowerShell
````
$OSArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture; Write-Host "OS Architecture: " -NoNewline; Write-Host "$OSArch"
````

> Note: You can also run these same commands from within WinPE, but the WinPE will need to have the optional components added so that it supports running PowerShell and WMI queries. More details and example script can be found here: https://github.com/HaroldMitts/Build-CustomPE

## Production Use Demo
[Video Demo on YouTube](https://youtu.be/PMnPsvOI_jU)
This demo shows a device booting from Windows Deployment Services, installing Windows using WinPE, and the Driver Injection solution described in this repository.

## Related Resources
[Microsoft Manufacturing Guidance](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/index)

[Microsoft Cumulative Updates](http://www.catalog.update.microsoft.com/Search.aspx?q=windows%2010%20cumulative%20update)

[USB-B Sample Scripts](https://go.microsoft.com/fwlink/?linkid=872894)
