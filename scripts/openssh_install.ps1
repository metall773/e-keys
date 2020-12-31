
$file = "$env:ProgramFiles\OpenSSH-Win64\install-sshd.ps1"
powershell.exe -ExecutionPolicy ByPass -File $file
Set-Service sshd -StartupType Automatic
Start-Service -Name sshd

#remove 2 last line from config
$sshd_config=@"
AuthenticationMethods   publickey
AuthorizedKeysFile      .ssh/authorized_keys
Subsystem       sftp    sftp-server.exe
# Logging
SyslogFacility AUTH
LogLevel DEBUG
"@
Set-Content "$env:ProgramData\ssh\sshd_config" -Value $sshd_config

Restart-Service -Name sshd

#firewall allow 22 tcp connection
New-NetFirewallRule `
  -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
  -Enabled True `
  -Direction Inbound `
  -Protocol TCP `
  -Action Allow `
  -LocalPort 22

#add ssh keys
$ssh_user="Administrator"
New-Item -ItemType Directory -Force -Path "C:\Users\$ssh_user\.ssh"

#change defaul shell to powershell
New-ItemProperty `
  -Path "HKLM:\SOFTWARE\OpenSSH" `
  -Name "DefaultShell" `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -PropertyType String `
  -Force

#set key file acl
$acl = Get-Acl "C:\Users\$ssh_user\.ssh\authorized_keys"
$acl.SetAccessRuleProtection($true, $false)
$administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
$systemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
$acl.SetAccessRule($administratorsRule)
$acl.SetAccessRule($systemRule)
$acl | Set-Acl