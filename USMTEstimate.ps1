<#  
.SYNOPSIS  
    Estimates size of USMT backup on machine.   
.DESCRIPTION  
    This script uses already installed USMT files to run a USMT scan state estimate.  Parse the XML output and write the vaule into WMI for SCCM Hardware inventory pickup. 
.NOTES  
    File Name  : GatherUSMTEstimate.ps1  
    Author     : Tyler Berends tyler.berends@outlook.com  
    Requires   : PowerShell V5  
.LINK  
#>

#OS Arch
$OSArch = Get-WmiObject Win32_OperatingSystem | Select-Object OSArchitecture -ExpandProperty OSArchitecture

#Check log location where XML will be saved.
$FolderExists = Test-Path -Path C:\Windows\IT
If($FolderExists -eq $False){
New-Item -ItemType Directory -Force -Path C:\Windows\IT
}

#Remove previous XML Files
Remove-Item "C:\Windows\IT\USMT-Estimation.xml" -Force -ErrorAction SilentlyContinue

#RunScanState Gather Estitmation
If($OSArch -eq "64-bit"){
Set-Location "${env:ProgramFiles(x86)}\USMT5\amd64"
Start-Process scanstate.exe -ArgumentList "C:\store /uel:30 /ue:%ComputerName%\* /i:MigCLA.xml /p:C:\Windows\IT\USMT-Estimation.xml" -Wait -WindowStyle Hidden
}
If($OSArch -eq "32-bit"){
Set-Location "${env:ProgramFiles}\USMT5\amd64"
Start-Process scanstate.exe -ArgumentList "C:\store /uel:30 /ue:%ComputerName%\* /i:MigCLA.xml /p:C:\Windows\IT\USMT-Estimation.xml" -Wait -WindowStyle Hidden
}

#Get Value From XML
$xml = [xml](Get-Content C:\Windows\IT\USMT-Estimation.xml)
$SizeRaw = $xml.PreMigration.storeSize.size.'#text'
$Size = ([math]::truncate($SizeRaw / 1mb))

#Set Vars for WMI Info
$Namespace = 'ITLocal'
$Class = 'USMT_Estimate'

#Check NS
$NSfilter = "Name = '$Namespace'"
$NSExist = Get-WmiObject -Namespace root -Class __namespace -Filter $NSfilter
If($NSExist -eq $null){
    #Create NS
   	$rootNamespace = [wmiclass]'root:__namespace'
    $NewNamespace = $rootNamespace.CreateInstance()
	$NewNamespace.Name = $Namespace
	$NewNamespace.Put()
    }

#Check Class
$ClassExist = Get-CimClass -Namespace root/$Namespace -ClassName $Class -ErrorAction SilentlyContinue
If($ClassExist -eq $null){
    #Create Class
    $NewClass = New-Object System.Management.ManagementClass("root\$namespace", [string]::Empty, $null)
	$NewClass.name = $Class
    $NewClass.Qualifiers.Add("Static",$true)
    $NewClass.Qualifiers.Add("Description","USMT_Estimate is a custom WMI class used to store data about ScanState results.")
    $NewClass.Properties.Add("ComputerName",[System.Management.CimType]::String, $false)
    $NewClass.Properties.Add("Size",[System.Management.CimType]::String, $false)
    $NewClass.Properties["ComputerName"].Qualifiers.Add("Key",$true)
    $NewClass.Put()
    }

#Create Instance
$wmipath = 'root\'+$Namespace+':'+$class
$WMIInstance = ([wmiclass]$wmipath).CreateInstance()
$WMIInstance.ComputerName = $env:COMPUTERNAME
$WMIInstance.Size = "$Size"
$WMIInstance.Put()
