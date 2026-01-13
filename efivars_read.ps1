param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Guid,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$Name
)

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

# ------------ EFI vars writing

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

$buf = New-Object byte[] 4096
$attr = 0

$size = [EFI]::GetFirmwareEnvironmentVariableEx($Name, $Guid, $buf, 4096, [ref]$attr)

if($size -eq 0){
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Warning "Read failed, Win32 error $err"
    exit
}

$data = $buf[0..($size-1)] | ForEach-Object { "{0:X2}" -f $_ }

Write-Host "GUID : $Guid"
Write-Host "Name : $Name"
Write-Host "Size : $size"
Write-Host "Attr : 0x$('{0:X8}' -f $attr)"
Write-Host "Data : $($data -join ' ')"