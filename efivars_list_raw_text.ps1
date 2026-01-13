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

$INFO_CLASS = 1 #efi vars

$size = 0
$status = [Ntdll]::NtEnumerateSystemEnvironmentValuesEx($INFO_CLASS, [IntPtr]::Zero, [ref]$size)
$buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($size)

try {
    $status = [Ntdll]::NtEnumerateSystemEnvironmentValuesEx($INFO_CLASS, $buf, [ref]$size)
    if ($status -ne 0) {
        Write-Warning "NtEnumerateSystemEnvironmentValuesEx failed NTSTATUS=0x{0:X8}" -f $status
        exit
    }

    $bytes = New-Object byte[] $size
    [Runtime.InteropServices.Marshal]::Copy($buf, $bytes, 0, $size)

    $text = [System.Text.Encoding]::Unicode.GetString($bytes)
    Write-Host $text
} finally {
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
}