# ------------ EFI vars api unlock
Add-Type @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct LUID
{
    public uint LowPart;
    public int HighPart;
}

[StructLayout(LayoutKind.Sequential)]
public struct TOKEN_PRIVILEGES
{
    public uint PrivilegeCount;
    public LUID Luid;
    public uint Attributes;
}

public class AdjPriv
{
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out LUID lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges,
        ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    public const uint TOKEN_ADJUST_PRIVILEGES = 0x20;
    public const uint TOKEN_QUERY = 0x8;
    public const uint SE_PRIVILEGE_ENABLED = 0x2;

    public static bool EnablePrivilege(string privilege)
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
            return false;

        LUID luid;
        if (!LookupPrivilegeValue(null, privilege, out luid))
            return false;

        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Luid = luid;
        tp.Attributes = SE_PRIVILEGE_ENABLED;

        return AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
if (-not [AdjPriv]::EnablePrivilege("SeSystemEnvironmentPrivilege")) {
    Write-Warning "The SeSystemEnvironmentPrivilege privilege could not be enabled"
    exit
}

Write-Host "SeSystemEnvironmentPrivilege privilege successfully obtained"

# ------------ reading efivars
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Ntdll {
    [DllImport("ntdll.dll")]
    public static extern uint NtEnumerateSystemEnvironmentValuesEx(
        uint InformationClass,
        IntPtr Buffer,
        ref uint BufferLength
    );
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class EFI {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern uint GetFirmwareEnvironmentVariableEx(
    string name,
    string guid,
    byte[] buffer,
    uint size,
    out uint attributes
  );
}
"@

function Get-EfiVariableValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Guid,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $buf = New-Object byte[] 4096
    $attr = 0

    $size = [EFI]::GetFirmwareEnvironmentVariableEx($Name, "{" + $Guid + "}", $buf, 4096, [ref]$attr)

    if($size -eq 0){
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Warning "Read failed, Win32 error $err"
    }

    $data = $buf[0..($size-1)] | ForEach-Object { "{0:X2}" -f $_ }

    return $($data -join ' ')
}

$INFO_CLASS = 1 #efi vars

$size = 0
$status = [Ntdll]::NtEnumerateSystemEnvironmentValuesEx($INFO_CLASS, [IntPtr]::Zero, [ref]$size)
$buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($size)

$status = [Ntdll]::NtEnumerateSystemEnvironmentValuesEx($INFO_CLASS, $buf, [ref]$size)
if ($status -ne 0) {
    Write-Warning "NtEnumerateSystemEnvironmentValuesEx failed NTSTATUS=0x{0:X8}" -f $status
    exit
}

$result = New-Object byte[] $size
[Runtime.InteropServices.Marshal]::Copy($buf, $result, 0, $size)

$currentPos = 0
$prevGuid = $null
$varsForGuid = @()

while ($true) {
    $nextOffset = [System.BitConverter]::ToUInt32($result, $currentPos)
    if ($nextOffset -eq 0) { break }

    $guidBytes = $result[($currentPos + 4)..($currentPos + 19)]
    $vendorGuid = [System.Guid]::New(
        [System.BitConverter]::ToInt32($guidBytes,0),
        [System.BitConverter]::ToInt16($guidBytes,4),
        [System.BitConverter]::ToInt16($guidBytes,6),
        $guidBytes[8..15]
    )

    $nameLength = $nextOffset - 20
    $nameBytes = $result[($currentPos + 20)..($currentPos + 20 + $nameLength - 1)]
    $name = [System.Text.Encoding]::Unicode.GetString($nameBytes).TrimEnd([char]0)

    if ($prevGuid -ne $null -and $prevGuid.ToString() -ne $vendorGuid.ToString()) {
        Write-Host "GUID: $prevGuid"
        foreach ($v in $varsForGuid) {
            $value = Get-EfiVariableValue -Guid $prevGuid.ToString() -Name $v
            Write-Host "  $v : $value"
        }
        Write-Host ""
        $varsForGuid = @()
    }

    $prevGuid = $vendorGuid
    $varsForGuid += $name
    $currentPos += $nextOffset
}

if ($prevGuid -ne $null) {
    Write-Host "GUID: $prevGuid"
    foreach ($v in $varsForGuid) {
        $value = Get-EfiVariableValue -Guid $prevGuid.ToString() -Name $v
        Write-Host "  $v : $value"
    }
    Write-Host ""
}