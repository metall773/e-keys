#windows 2012 or higher needed

#Declare our named parameters here...
param(
  $share_host,
  $share_name,
  $share_login,
  $share_pass,
  $share_disk_host,
  $share_disk_name,
  $share_disk_login,
  $share_disk_pass,
  $choco_list
)

$logFile = 'c:\init-log.txt'

Function LogWrite
{
  Param ([string]$log1, [string]$log2, [string]$log3, [string]$log4,  [string]$log5)
  $stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
  $line = "$stamp $log1 $log2 $log3 $log4 $log5"
  Write-host $line
  Add-content $logFile -value $Line
}

LogWrite "------------------------------------------------"
LogWrite "Script start"
LogWrite "Runtime parameters:"
LogWrite "share_host:" $share_host
LogWrite "share_name:" $share_name
LogWrite "share_login:" $share_login
LogWrite "share_pass:" $share_pass
LogWrite "share_disk_host:" $share_disk_host
LogWrite "share_disk_name:" $share_disk_name
LogWrite "share_disk_login:" $share_disk_login
LogWrite "share_disk_pass:" $share_disk_pass
LogWrite "choco_list:" $choco_list
LogWrite "------------------------------------------------"
LogWrite "Format RAW disks"

#format RAW disks
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | `
  Select-Object -First 1 | `
    Set-WmiInstance -Arguments @{DriveLetter='Z:'}

$disks = Get-Disk | `
  Where-Object partitionstyle -eq 'raw' | `
    Sort-Object number

$letters = 69..89 | ForEach-Object { [char]$_ }
$count = 0
$label = 'datadisk'

foreach ($disk in $disks) {
  $driveLetter = $letters[$count].ToString()
  $diskLabel = -join ($label,'.', $count)
  LogWrite " Format disk " $driveLetter $diskLabel
  $disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
      New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $diskLabel -Confirm:$false -Force
  $count++
}

LogWrite "Format RAW disks, done"
LogWrite "------------------------------------------------"
LogWrite "Create mount_share file"

#create c:\mount_share.cmd
$share_file = @"
cmdkey /add:"$share_host" /user:"Azure\$share_login" /pass:"$share_pass" ;
net use y: /delete /y ;
net use y: \\$share_host\$share_name ; 

cmdkey /add:"$share_disk_host" /user:"Azure\$share_disk_login" /pass:"$share_disk_pass" ;
net use w: /delete /y ;
net use w: \\$share_disk_host\$share_disk_name ; 
"@

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines('c:\mount_share.cmd', $share_file, $Utf8NoBomEncoding)

LogWrite "Create mount_share file, done"
LogWrite "------------------------------------------------"

#install choco packages
if ( $choco_list -ne "" ) {
  LogWrite "Install choco packages: " $choco_list
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $down = New-Object System.Net.WebClient
  
  iex ($down.DownloadString('https://chocolatey.org/install.ps1'))
  choco feature enable -n allowGlobalConfirmation 
  choco install $choco_list -y 
  } 
  else {
    LogWrite "No choco packages for install, skip..."
  }


LogWrite "------------------------------------------------"
LogWrite "Init done"