$dllPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "DesktopWidgets.dll"
$csharp = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Drawing;
using System.Diagnostics;
namespace DesktopWidgets {
    public class WindowUtils {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
        [DllImport("user32.dll")]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string className, string windowTitle);
        [DllImport("user32.dll", EntryPoint="GetWindowLong")]
        public static extern IntPtr GetWindowLongPtr32(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")]
        public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint="SetWindowLong")]
        public static extern IntPtr SetWindowLongPtr32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
        [DllImport("user32.dll", EntryPoint="SetWindowLongPtr")]
        public static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
        public static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex) {
            if (IntPtr.Size == 8) return GetWindowLongPtr64(hWnd, nIndex);
            else return GetWindowLongPtr32(hWnd, nIndex);
        }
        public static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong) {
            if (IntPtr.Size == 8) return SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
            else return SetWindowLongPtr32(hWnd, nIndex, dwNewLong);
        }
        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        public const int GWL_EXSTYLE = -20;
        public const int WS_EX_TOOLWINDOW = 0x80;
        public const int WS_EX_APPWINDOW = 0x40000;
        public static void HideFromAltTab(IntPtr hWnd) {
            long style = GetWindowLongPtr(hWnd, GWL_EXSTYLE).ToInt64();
            style &= ~WS_EX_APPWINDOW; 
            style |= WS_EX_TOOLWINDOW;
            SetWindowLongPtr(hWnd, GWL_EXSTYLE, new IntPtr(style));
        }
    }
    public class DesktopIcons {
        // Constants
        const int LVM_FIRST = 0x1000;
        const int LVM_GETITEMCOUNT = LVM_FIRST + 4;
        const int LVM_GETITEMRECT = LVM_FIRST + 14;
        const int LVIR_ICON = 1; // Text and Icon
        const int MEM_COMMIT = 0x1000;
        const int MEM_RELEASE = 0x8000;
        const int PAGE_READWRITE = 0x04;
        const int PROCESS_VM_OPERATION = 0x0008;
        const int PROCESS_VM_READ = 0x0010;
        const int PROCESS_VM_WRITE = 0x0020;
        // P/Invoke
        [DllImport("user32.dll")]
        static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        [DllImport("user32.dll")]
        static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string className, string windowTitle);
        [DllImport("user32.dll")]
        static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
        [DllImport("user32.dll")]
        static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
        [DllImport("kernel32.dll")]
        static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
        [DllImport("kernel32.dll")]
        static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, int flAllocationType, int flProtect);
        [DllImport("kernel32.dll")]
        static extern bool VirtualFreeEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, int dwFreeType);
        [DllImport("kernel32.dll")]
        static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, IntPtr lpBuffer, int nSize, out int lpNumberOfBytesWritten);
        [DllImport("kernel32.dll")]
        static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, IntPtr lpBuffer, int nSize, out int lpNumberOfBytesRead);
        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr hObject);
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }
        public static IntPtr GetDesktopListView() {
            IntPtr hShellDefView = IntPtr.Zero;
            IntPtr hWorkerw = IntPtr.Zero;
            IntPtr hDesktop = IntPtr.Zero;
            // Method 1: Progman
            IntPtr hProgman = FindWindow("Progman", "Program Manager");
            hShellDefView = FindWindowEx(hProgman, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (hShellDefView == IntPtr.Zero) {
                // Method 2: WorkerW iteration
                do {
                    hWorkerw = FindWindowEx(IntPtr.Zero, hWorkerw, "WorkerW", null);
                    hShellDefView = FindWindowEx(hWorkerw, IntPtr.Zero, "SHELLDLL_DefView", null);
                } while (hShellDefView == IntPtr.Zero && hWorkerw != IntPtr.Zero);
            }
            if (hShellDefView != IntPtr.Zero) {
                hDesktop = FindWindowEx(hShellDefView, IntPtr.Zero, "SysListView32", null);
            }
            return hDesktop;
        }
        public static List<Rectangle> GetIconRects() {
            List<Rectangle> icons = new List<Rectangle>();
            IntPtr hListView = GetDesktopListView();
            if (hListView == IntPtr.Zero) return icons;
            int count = SendMessage(hListView, LVM_GETITEMCOUNT, 0, 0);
            if (count == 0) return icons;
            int processId;
            GetWindowThreadProcessId(hListView, out processId);
            IntPtr hProcess = OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE, false, processId);
            if (hProcess == IntPtr.Zero) return icons;
            IntPtr pRect = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)Marshal.SizeOf(typeof(RECT)), MEM_COMMIT, PAGE_READWRITE);
            if (pRect != IntPtr.Zero) {
                try {
                    for (int i = 0; i < count; i++) {
                        RECT rect = new RECT();
                        rect.Left = LVIR_ICON;
                        IntPtr pLocalRect = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(RECT)));
                        Marshal.StructureToPtr(rect, pLocalRect, false);
                        int bytesWritten;
                        WriteProcessMemory(hProcess, pRect, pLocalRect, Marshal.SizeOf(typeof(RECT)), out bytesWritten);
                        Marshal.FreeHGlobal(pLocalRect);
                        SendMessage(hListView, LVM_GETITEMRECT, i, pRect.ToInt32());
                        int bytesRead;
                        IntPtr pReadRect = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(RECT)));
                        ReadProcessMemory(hProcess, pRect, pReadRect, Marshal.SizeOf(typeof(RECT)), out bytesRead);
                        rect = (RECT)Marshal.PtrToStructure(pReadRect, typeof(RECT));
                        Marshal.FreeHGlobal(pReadRect);
                        icons.Add(new Rectangle(rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top));
                    }
                }
                finally {
                    VirtualFreeEx(hProcess, pRect, 0, MEM_RELEASE);
                    CloseHandle(hProcess);
                }
            }
            return icons;
        }
        // New Helper for Widget-to-Widget
        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
        public static Rectangle GetWindowRectSimple(IntPtr hWnd) {
            RECT r;
            if (GetWindowRect(hWnd, out r)) {
                return new Rectangle(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);
            }
            return Rectangle.Empty;
        }
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'DesktopWidgets.WindowUtils').Type) {
    Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Drawing, System.Windows.Forms
}
function global:Hide-FromAltTab {
    param([IntPtr]$Handle)
    [DesktopWidgets.WindowUtils]::HideFromAltTab($Handle)
}
function global:Get-DesktopIconRects {
    return [DesktopWidgets.DesktopIcons]::GetIconRects()
}
function global:Get-OtherWidgetRects {
    param([int]$ExcludePid)
    $rects = @()
    $procs = Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -like "DesktopWidget_*" -and $_.Id -ne $ExcludePid
    }
    foreach ($p in $procs) {
        $r = [DesktopWidgets.DesktopIcons]::GetWindowRectSimple($p.MainWindowHandle)
        if ($r.Width -gt 0) { $rects += $r }
    }
    return $rects
}
