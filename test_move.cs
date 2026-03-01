using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class TestMoveIcon {
    [DllImport("user32.dll", EntryPoint = "FindWindowW")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", EntryPoint = "FindWindowExW")] public static extern IntPtr FindWindowEx(IntPtr hWndParent, IntPtr hWndChildAfter, string lpszClass, string lpszWindow);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint LVM_FIRST = 0x1000;
    public const uint LVM_SETITEMPOSITION = LVM_FIRST + 15;

    public static void Main() {
        IntPtr progman = FindWindow("Progman", null);
        IntPtr shellview = FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (shellview == IntPtr.Zero) {
            IntPtr workerw = IntPtr.Zero;
            do {
                workerw = FindWindowEx(IntPtr.Zero, workerw, "WorkerW", null);
                shellview = FindWindowEx(workerw, IntPtr.Zero, "SHELLDLL_DefView", null);
            } while (shellview == IntPtr.Zero && workerw != IntPtr.Zero);
        }
        IntPtr listview = FindWindowEx(shellview, IntPtr.Zero, "SysListView32", null);
        if (listview == IntPtr.Zero) { Console.WriteLine("Listview not found"); return; }

        Console.WriteLine("Moving icon 0 to 500,500...");
        // MAKELPARAM(500, 500)
        IntPtr lp = (IntPtr)((500 << 16) | (500 & 0xFFFF));
        SendMessage(listview, LVM_SETITEMPOSITION, (IntPtr)0, lp);
    }
}
