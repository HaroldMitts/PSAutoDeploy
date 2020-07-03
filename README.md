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

32-bit Example; `DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x86\Install.wim"`

64-bit Example;	`DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x64\Install.wim"`

For more details, see this Microsoft guide: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/system-builder-deployment-of-windows-10-for-desktop-editions

Deployment resources from the USB-B download should be saved to a network share with sub-folder named Deployment
Download the USB-B content from this Microsoft website and expand to your Deployment Share: http://aka.ms/usb-b

`Z:\Share\Deployment` contains the following files from the http://aka.ms/usb-b download;
* `ApplyImage.bat` - batch file used to apply image files to hard disk
* `CreatePartitions-BIOS.txt` - Text file used by ApplyImage.bat and Diskpart to setup BIOS disk partitions
* `CreatePartitions-UEFI.txt` - Text file used by ApplyImage.bat and Diskpart to setup UEFI disk partitions
* `HideRecoveryPartitions-BIOS.txt` - Text file used by ApplyImage.bat and Diskpart to hide BIOS recovery partitions
* `HideRecoveryPartitions-UEFI.txt` - Text file used by ApplyImage.bat and Diskpart to hide UEFI recovery partitions
* `Walkthrough-Deploy.bat` - batch file used to detect PC firmware type (UEFI or BIOS) and accept image file name to use for image deployment

### Device Driver Repository
Copy INF device drivers to the distribution share into sub-folders named after the BIOS values as determined by WMIC. The folder should contain a folder for each device driver, separated into sub-folders based on the device name. To determine the required folder names where you will save the drivers, see this page for details and examples; https://github.com/HaroldMitts/PSAutoDeploy/wiki/Get-WMI-values

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

##Demo
[Video Demo on YouTube](https://youtu.be/PMnPsvOI_jU)
