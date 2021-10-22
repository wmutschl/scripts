param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

'running with full privileges'
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
# temporarily change to the correct folder
Push-Location $dir
restic -r ../xps_backup backup --use-fs-snapshot --exclude-file=restic-exclude-windows.txt --verbose C:\
# now back to previous directory
Pop-Location