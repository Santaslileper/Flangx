using System;
using System.Runtime.InteropServices;

namespace DesktopWidgets {
    public static class RustCore {
        [StructLayout(LayoutKind.Sequential)]
        public struct WidgetRect { public int Left, Top, Width, Height; }

        [DllImport("interaction.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int get_desktop_icons([Out] WidgetRect[] outRects, int maxCount);

        [DllImport("interaction.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int calculate_snap(int currentX, int currentY, int width, int height, 
            WidgetRect[] peers, int peerCount, WidgetRect[] icons, int iconCount, out int outX, out int outY);
    }
}
