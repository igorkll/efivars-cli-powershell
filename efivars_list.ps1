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

$INFO_CLASS = 1
$size = 1024 * 1024
$result = New-Object Byte[]($size)
$rc = [Ntdll]::NtEnumerateSystemEnvironmentValuesEx($INFO_CLASS, $result, [ref] $size)
$lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
if ($rc -eq 0)
{
    $currentPos = 0
    while ($true)
    {
        # Get the offset to the next entry
        $nextOffset = [System.BitConverter]::ToUInt32($result, $currentPos)
        if ($nextOffset -eq 0)
        {
            break
        }

        # Get the vendor GUID for the current entry
        $guidBytes = $result[($currentPos + 4)..($currentPos + 4 + 15)]
        [Guid] $vendor = [Byte[]]$guidBytes
        
        # Get the name of the current entry
        $name = [System.Text.Encoding]::Unicode.GetString($result[($currentPos + 20)..($currentPos + $nextOffset - 1)])

        # Return a new object to the pipeline
        New-Object PSObject -Property @{Namespace = $vendor.ToString('B'); VariableName = $name.Replace("`0","") }

        # Advance to the next entry
        $currentPos = $currentPos + $nextOffset
    }
}
else
{
    Write-Error "Unable to retrieve list of UEFI variables, last error = $lastError."
}