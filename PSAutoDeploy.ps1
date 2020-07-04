<#	
	.NOTES
	===========================================================================
	 Created on:   	7/03/2020
	 Created by:   	Harold Mitts
	 Filename:     	PSAutoDeploy.ps1
	 Version:       2.0
	===========================================================================
#>
#region WMI Queries set to varialbles
$SysManufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$SysModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
$OSArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
#endregion
#region OS Selection
$WinVer = Read-Host "Type (1) for Pro or (2) for Home"
Write-Host ""

    If ($WinVer -eq 1)
        {
            Write-Host -ForegroundColor Green "Loading Windows 10 Pro" 
            $OSIndex = 6
        } 
            ELSE 
        {
        Write-Host -ForegroundColor Green "Loading Windows 10 Home" 
            $OSIndex = 1
        }

Write-Host ""
Write-Output "Deploying Windows image and drivers based on the following device variables"
Write-Output ""
    Write-Host -ForegroundColor Yellow "PC Manufacturer: " -NoNewline; Write-Host -ForegroundColor Red "$SysManufacturer"
    Write-Host -ForegroundColor Yellow "PC Model: " -NoNewline; Write-Host -ForegroundColor Red "$SysModel"
    Write-Host -ForegroundColor Yellow "OS Architecture: " -NoNewline; Write-Host -ForegroundColor Red "$OSArch"
Write-Output ""
#endregion
#region Determine Firmware type and partition disk
Write-Host -ForegroundColor green "Step 1 - Prepare Disk Partitions"
wpeutil UpdateBootInfo
$key = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control"
$value = "PEFirmwaretype"
$FirmwareType = (Get-ItemProperty -Path $key -Name $value).$value

if ($FirmwareType -eq 1)
{
	Write-Host -ForegroundColor Yellow "Detected firmware mode: " -NoNewline; Write-Host -ForegroundColor Red "BIOS"
	
	$CreatePartitionsBIOS = New-TemporaryFile

        Add-Content -Path $CreatePartitionsBIOS -Value 'Select Disk 0'
        Add-Content -Path $CreatePartitionsBIOS -Value 'Clean'
        Add-Content -Path $CreatePartitionsBIOS -Value 'Create Partition Primary Size=100'
        Add-Content -Path $CreatePartitionsBIOS -Value 'format quick fs=ntfs label="System"'
        Add-Content -Path $CreatePartitionsBIOS -Value 'assign letter="S"'
        Add-Content -Path $CreatePartitionsBIOS -Value 'active'
        Add-Content -Path $CreatePartitionsBIOS -Value 'create partition primary'
        Add-Content -Path $CreatePartitionsBIOS -Value 'shrink minimum=750'
        Add-Content -Path $CreatePartitionsBIOS -Value 'format quick fs=ntfs label="Windows"'
        Add-Content -Path $CreatePartitionsBIOS -Value 'assign letter="W"'
        Add-Content -Path $CreatePartitionsBIOS -Value 'create partition primary'
        Add-Content -Path $CreatePartitionsBIOS -Value 'format quick fs=ntfs label="Recovery image"' 
        Add-Content -Path $CreatePartitionsBIOS -Value 'assign letter="R"' 
        Add-Content -Path $CreatePartitionsBIOS -Value 'set id=27'
        Add-Content -Path $CreatePartitionsBIOS -Value 'list volume'
        Add-Content -Path $CreatePartitionsBIOS -Value 'exit'
	
	Invoke-Command -ScriptBlock { diskpart /s $CreatePartitionsBIOS }
}

if ($FirmwareType -eq 2)
{
	Write-Host -ForegroundColor Yellow "Detected firmware mode: " -NoNewline; Write-Host -ForegroundColor Red "UEFI"

	$CreatePartitionsUEFI = New-TemporaryFile

        Add-Content -Path $CreatePartitionsUEFI -Value 'select disk 0'
        Add-Content -Path $CreatePartitionsUEFI -Value 'clean'
        Add-Content -Path $CreatePartitionsUEFI -Value 'convert gpt'
        Add-Content -Path $CreatePartitionsUEFI -Value 'create partition efi size=100'
        Add-Content -Path $CreatePartitionsUEFI -Value 'format quick fs=fat32 label="System"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'assign letter="S"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'create partition msr size=16'
        Add-Content -Path $CreatePartitionsUEFI -Value 'create partition primary'
        Add-Content -Path $CreatePartitionsUEFI -Value 'shrink minimum=900'
        Add-Content -Path $CreatePartitionsUEFI -Value 'format quick fs=ntfs label="Windows"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'assign letter="W"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'create partition primary'
        Add-Content -Path $CreatePartitionsUEFI -Value 'format quick fs=ntfs label="Recovery"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'assign letter="R"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"'
        Add-Content -Path $CreatePartitionsUEFI -Value 'gpt attributes=0x8000000000000001'
        Add-Content -Path $CreatePartitionsUEFI -Value 'list volume'
        Add-Content -Path $CreatePartitionsUEFI -Value 'exit'

	Invoke-Command -ScriptBlock { diskpart /s $CreatePartitionsUEFI }
}
#endregion
#region Apply image
Write-Host -ForegroundColor green "Step 2 - Applying Image"
MKDIR W:\Scratchdir

if ($OSArch -eq "64-bit")
{
    Expand-WindowsImage -imagepath "Z:\Images\x64\Install.wim" -applypath "W:\" -index $OSIndex    
}
Else
{
	Expand-WindowsImage -ImagePath "Z:\Images\x86\Install.wim" -ApplyPath "W:\" -Index $OSIndex
}
Write-Output ""
#endregion
#region Configure System and Recovery Partition 
Write-Host -ForegroundColor green "Step 3 - Configure System Files using BCDBoot"
Invoke-Command -ScriptBlock { W:\Windows\System32\bcdboot W:\Windows /s S: }
Write-Output ""
Write-Host -ForegroundColor green "Step 4 - Configure and Hide Recovery Partition"
MKDIR R:\Recovery\WindowsRE
Invoke-Command -ScriptBlock { XCopy /h W:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE\ }
Invoke-Command -ScriptBlock { W:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WindowsRE /Target W:\Windows }
Invoke-Command -ScriptBlock { W:\Windows\System32\Reagentc /info /Target W:\Windows }
Write-Output ""
# Hide recovery code goes here
#endregion
#region Inject Device Drivers
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
Write-Host -ForegroundColor Green "Step 6 - Finalize Image"
Write-Host -ForegroundColor Yellow "--Boot the device to OOBE one time to complete PnP detection, `n--then power down by holding power button for a few seconds. `n--After power down, it's ready for inventory or end-user."
#endregion