$src = @'
using System;
using System.Runtime.InteropServices;
public static class Win32 {
    public static uint WM_CLOSE = 0x10;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
    public static extern IntPtr PostMessage(IntPtr hWnd, UInt32 Msg, int wParam, int lParam);
}
'@

Add-Type -TypeDefinition $src
Get-Process | Where-Object {$_.MainWindowTitle -ne "" -and $_.MainWindowTitle -ne "Администратор: Windows PowerShell"} | %{[Win32]::PostMessage($_.MainWindowHandle, [Win32]::WM_CLOSE, 0, 0)}