#windows 2012 or higher needed

#Declare our named parameters here...
param(
  $share_host,
  $share_name,
  $share_login,
  $share_pass
)

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
  $disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
      New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $diskLabel -Confirm:$false -Force
  $count++
}

#create c:\mount_share.cmd
$share_file = @"
cmdkey /add:"$share_host" /user:"Azure\$share_login" /pass:"$share_pass"
net use y: /delete /y
net use y: \\$share_host\$share_name
pause
"@

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines('c:\mount_share.cmd', $share_file, $Utf8NoBomEncoding)

#rename network disk
c:\mount_share.cmd
$Rename = New-Object -ComObject Shell.Application
$Rename.NameSpace("Y:\").Self.Name = $share_name
