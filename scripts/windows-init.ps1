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