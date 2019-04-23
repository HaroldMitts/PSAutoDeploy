<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.160
	 Created on:   	4/22/2019 2:31 PM
	 Created by:   	Harold Mitts
	 Organization: 	
	 Filename:     	
	===========================================================================
	.DESCRIPTION
	Requires the following WinPE optional components;
		WinPE-WMI
		WinPE-Scripting
		WinPE-NetFx
		WinPE-PowerShell
	Example commands to add the above required Optional Components
	https://github.com/HaroldMitts/Offline-DI/blob/master/Add%20Optional%20Components%20to%20WinPE%20-%20Example.txt

	Save the Windows 10 image to the deployment share. The file should be named install.wim or you will need to 
	modify this script to match the image name.
	Example;
		Z:\Share\Images\x64\Install.wim

	The Install.wim must be a single-indexed image. To create a single-indexed image from the base OPK install.wim, use the DISM /Export-Image command. 
	32-bit Example;
		DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x86\Install.wim"
	64-bit Example;	
		DISM /Export-Image /SourceImageFile:"C:\TMP\install.wim" /SourceIndex:6 /DestinationImageFile:"Z:\Share\Images\x64\Install.wim"
	For more details, see this Microsoft guide: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/system-builder-deployment-of-windows-10-for-desktop-editions

	Requires deployment resources to be saved to a network share named as USB-B with subfolder named Deployment
	Download the USB-B content from this Microsoft website and expand to your Deployment Share: http://aka.ms/usb-b
	Z:\Share\Deployment contains the following files;
	    ApplyImage.bat - batch file used to apply image files to hard disk
	    CreatePartitions-BIOS.txt - Text file used by ApplyImage.bat to setup BIOS disk partitions
	    CreatePartitions-UEFI.txt - Text file used by ApplyImage.bat to setup UEFI disk partitions
	    HideRecoveryPartitions-BIOS.txt - Text file used by ApplyImage.bat to hide BIOS recovery partitions
	    HideRecoveryPartitions-UEFI.txt - Text file used by ApplyImage.bat to hide UEFI recovery partitions
	    Walkthrough-Deploy.bat - batch file used to detect PC firmware type (UEFI or BIOS) and accept image file name to use for image deployment

	Copy INF device drivers to the distribution share into sub folders named after the BIOS values as determined by WMIC. The folder should contain a folder for each device driver, 
	separated into subfolders based on the device name. 
	32-bit Driver Example;
		Z:\Share\Drivers\Lenovo\G40\32-bit\
			Z:\Share\Drivers\Lenovo\G40\32-bit\intelaud
			Z:\Share\Drivers\Lenovo\G40\32-bit\igdlh64
		etc... for each device in the PC needing drivers you wish to include

	64-bit Driver Example;
		Z:\Share\Drivers\Lenovo\G40\64-bit\
			Z:\Share\Drivers\Lenovo\G40\64-bit\intelaud
			Z:\Share\Drivers\Lenovo\G40\64-bit\igdlh64
		etc... for each device in the PC needing drivers you wish to include
#>
#region WMI Queries set to varialbles
$SysManufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$SysModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
$OSArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture

Write-Output "Deploying Windows image and drivers based on the following device variables"
Write-Output ""
Write-Host -ForegroundColor Yellow "PC Manufacturer: " -NoNewline; Write-Host -ForegroundColor Red "$SysManufacturer"
Write-Host -ForegroundColor Yellow "PC Model: " -NoNewline; Write-Host -ForegroundColor Red "$SysModel"
Write-Host -ForegroundColor Yellow "OS Architecture: " -NoNewline; Write-Host -ForegroundColor Red "$OSArch"
Write-Output ""
Write-Output "Note: This script does not support Compact OS. If you need to support Compact OS, run a different script"
#endregion
#region Determine Firmware type and partition disk
Write-Host -ForegroundColor green "************************************************************************************************"
Write-Host -ForegroundColor green "Step 1 - Prepare Disk Partitions"
wpeutil UpdateBootInfo
$key = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control"
$value = "PEFirmwaretype"
$FirmwareType = (Get-ItemProperty -Path $key -Name $value).$value

if ($FirmwareType -eq 1)
{
	Write-Host -ForegroundColor Yellow "Detected firmware mode: " -NoNewline; Write-Host -ForegroundColor Red "BIOS"
	diskpart /s Z:\Deployment\CreatePartitions-BIOS.txt
}

if ($FirmwareType -eq 2)
{
	Write-Host -ForegroundColor Yellow "Detected firmware mode: " -NoNewline; Write-Host -ForegroundColor Red "UEFI"
	diskpart /s Z:\Deployment\CreatePartitions-UEFI.txt
}
#endregion
#region Apply image
Write-Host -ForegroundColor green "************************************************************************************************"
Write-Host -ForegroundColor green "Step 2 - Apply Image"
MKDIR W:\Scratchdir

if ($OSArch -eq "64-bit")
{
	$sysman = (get-wmiobject -Class:win32_computersystem).manufacturer; $sysmod = (Get-WmiObject -Class:win32_computersystem).model; $osarc = (Get-WmiObject win32_operatingsystem).osarchitecture; Expand-WindowsImage -imagepath Z:\Images\x64\Install.wim -applypath "W:\" -index 1
}
Else
{
	Expand-WindowsImage -ImagePath "Z:\Images\x86\Install.wim" -ApplyPath "W:\" -Index 1
}
Write-Output ""
#endregion
#region Configure System and Recovery Partition 
Write-Host -ForegroundColor green "************************************************************************************************"
Write-Host -ForegroundColor green "Step 3 - Configure System Files using BCDBoot"
Invoke-Command -ScriptBlock { W:\Windows\System32\bcdboot W:\Windows /s S: }
Write-Output ""
Write-Host -ForegroundColor green "************************************************************************************************"
Write-Host -ForegroundColor green "Step 4 - Configure and Hide Recovery Partition"
MKDIR R:\Recovery\WindowsRE
Invoke-Command -ScriptBlock { XCopy /h W:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE\ }
Invoke-Command -ScriptBlock { W:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WindowsRE /Target W:\Windows }
Invoke-Command -ScriptBlock { W:\Windows\System32\Reagentc /info /Target W:\Windows }
Write-Output ""
#endregion
#region Inject Device Drivers
Write-Host -ForegroundColor green "************************************************************************************************"
Write-Host -ForegroundColor green "Step 5 - Inject Device Drivers"
if (Test-Path Z:\Drivers\$sysmanufacturer -PathType Container)
{
	if (Test-Path Z:\Drivers\$SysManufacturer\$SysModel -PathType Container)
	{
		if (Test-Path Z:\Drivers\$SysManufacturer\$SysModel\$OSArch)
		{
			Dism.exe /Image:W:\ /Add-Driver /Driver:"Z:\Drivers\$SysManufacturer\$SysModel\$OSArch" /Recurse
		}
	}
}
Else { Write-Host -fore red -back green "Path Does Not Exist - Check that drivers exist in a subfolder at Z:\Drivers\$SysManufacturer\$SysModel\$OSArch" }
#endregion
#region Complete
Write-Output ""
Write-Host -ForegroundColor Green "************************************************************************************************"
Write-Host -ForegroundColor Green "Step 6 - Finalize Image"
Write-Host -ForegroundColor Yellow "--Boot the device to OOBE one time to complete PnP detection, `n--then power down by holding power button for a few seconds. `n--After power down, it's ready for inventory or end-user."
#endregion