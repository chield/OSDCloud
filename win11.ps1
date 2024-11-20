$ScriptName = 'Interstellar Windows 11'
$ScriptVersion = '24.7.4.4'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

<# Offline Driver Details
If you extract Driver Packs to your Flash Drive, you can DISM them in while in WinPE and it will make the process much faster, plus ensure driver support for first Boot
Extract to: OSDCLoudUSB:\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct
Use OSD Module to determine Vars
$ComputerProduct = (Get-MyComputerProduct)
$ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
#>



#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'


#=======================================================================
#   OSDCLOUD VARS
#=======================================================================
$Global:MyOSDCloud = [ordered]@{
    Restart               = [bool]$false
    RecoveryPartition     = [bool]$true
    OEMActivation         = [bool]$true 
    WindowsUpdate         = [bool]$false #temporarily disabled same thing almost 10 minutes
    MSCatalogFirmware     = [bool]$false #temporarily disabled no impact
    WindowsUpdateDrivers  = [bool]$false #temporarily disabled this is causing long delays on the getting ready screen before the oobe (almost 10 minutes)
    WindowsDefenderUpdate = [bool]$false #temporarily disabled same thing almost 10 minutes
    SetTimeZone           = [bool]$true
    SkipClearDisk         = [bool]$false
    ClearDiskConfirm      = [bool]$false
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB  = [bool]$true
    CheckSHA1             = [bool]$true
}

#Testing Custom Images - Use this if you want to automate using your own WIM / ESD file
#Region Custom Image
$WIMName = 'W11 - Nov 2024.wim'
$ImageFileItem = Find-OSDCloudFile -Name $WIMName  -Path '\OSDCloud\OS\'
if ($ImageFileItem){
    $ImageFileItem = $ImageFileItem | Where-Object {$_.FullName -notlike "C*"} | Where-Object {$_.FullName -notlike "X*"} | Select-Object -First 1
    if ($ImageFileItem){
        $ImageFileName = Split-Path -Path $ImageFileItem.FullName -Leaf
        $ImageFileFullName = $ImageFileItem.FullName
        
        $Global:MyOSDCloud.ImageFileItem = $ImageFileItem
        $Global:MyOSDCloud.ImageFileName = $ImageFileName
        $Global:MyOSDCloud.ImageFileFullName = $ImageFileFullName
        $Global:MyOSDCloud.OSImageIndex = 6
    }
}
#endregion Custom Image

#Testing MS Update Catalog Driver Sync
#$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#***********************************
# Updating Surface Driver Catalog
#***********************************
Write-Host "Updating Surface Driver Catalog..."
Invoke-RestMethod "https://raw.githubusercontent.com/chield/OSDCloud/refs/heads/main/Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1" | Invoke-Expression
Update-OSDCloudSurfaceDriverCatalogJustInTime -UpdateDriverPackJson

#Enable HPIA | Update HP BIOS | Update HP TPM

$UseHPIA = $true #temporarily disabled
if ($Manufacturer -match "HP" -and $UseHPIA -eq $true) {
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    { $Global:MyOSDCloud.HPIAALL = [bool]$true }
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true

if ($Manufacturer -match "HP"){
    install-module -Name HPCMSL -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
}

#write variables to console
Write-Output $Global:MyOSDCloud

#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
import-module "$ModulePath\OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

write-host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Green

#Restart
restart-computer
