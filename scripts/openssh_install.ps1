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
LogWrite "------------------------------------------------"
LogWrite "install-sshd"
$file = "$env:ProgramFiles\OpenSSH-Win64\install-sshd.ps1"
powershell.exe -ExecutionPolicy ByPass -File $file
LogWrite "------------------------------------------------"
LogWrite "install-sshd, done"

LogWrite "------------------------------------------------"
LogWrite "Set sshd StartupType Automatic"
Set-Service sshd -StartupType Automatic
LogWrite "------------------------------------------------"
LogWrite "Set sshd StartupType Automatic, done"

LogWrite "------------------------------------------------"
LogWrite "Start-Service sshd for default confing files create"
Start-Service -Name sshd

LogWrite "------------------------------------------------"
LogWrite "Stop-Service sshd"
Stop-Service -Name sshd


LogWrite "------------------------------------------------"
LogWrite "create sshd_config"
#sshd_config
$sshd_config=@"
AuthenticationMethods   publickey
AuthorizedKeysFile      .ssh/authorized_keys
Subsystem       sftp    sftp-server.exe
# Logging
SyslogFacility AUTH
LogLevel DEBUG
"@
Set-Content "$env:ProgramData\ssh\sshd_config" -Value $sshd_config
LogWrite "------------------------------------------------"
LogWrite "create sshd_config, done" "$env:ProgramData\ssh\sshd_config"

LogWrite "------------------------------------------------"
LogWrite "Restart-Service sshd"
Restart-Service -Name sshd

LogWrite "------------------------------------------------"
LogWrite "Allow ssh on firewall"
#firewall allow 22 tcp connection
New-NetFirewallRule `
  -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
  -Enabled True `
  -Direction Inbound `
  -Protocol TCP `
  -Action Allow `
  -LocalPort 22

#add ssh keys
LogWrite "------------------------------------------------"
LogWrite "Add ssh keys to administator user"
$ssh_user="Administrator"
New-Item -ItemType Directory -Force -Path "C:\Users\$ssh_user\.ssh"
Get-Content "$env:temp\e-keys\*.pub" | Set-Content "C:\Users\$ssh_user\.ssh\authorized_keys"


#OpenSSH change default shell to powershell
LogWrite "------------------------------------------------"
LogWrite "OpenSSH change default shell to powershell"
New-ItemProperty `
  -Path "HKLM:\SOFTWARE\OpenSSH" `
  -Name "DefaultShell" `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -PropertyType String `
  -Force

LogWrite "------------------------------------------------"
LogWrite "set acl to the ssh keyfile"
$acl = Get-Acl "C:\Users\$ssh_user\.ssh\authorized_keys"
$acl.SetAccessRuleProtection($true, $false)
$administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
$systemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
$acl.SetAccessRule($administratorsRule)
$acl.SetAccessRule($systemRule)
$acl | Set-Acl


LogWrite "------------------------------------------------"
LogWrite "Format RAW disks"
#make all disk online
Get-Disk | Where-Object IsOffline -Eq $True | Set-Disk -IsOffline $False 

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
