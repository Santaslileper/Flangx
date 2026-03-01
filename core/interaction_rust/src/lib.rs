use std::ffi::c_void;

// Native Win32 Types (redefined for zero-dependency build)
type HWND = isize;
type HANDLE = isize;
type BOOL = i32;
type WPARAM = usize;
type LPARAM = isize;

#[repr(C)]
#[derive(Debug, Clone, Copy, Default)]
struct RECT {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct WidgetRect {
    pub left: i32,
    pub top: i32,
    pub width: i32,
    pub height: i32,
}

// Win32 External Functions
extern "system" {
    fn FindWindowW(class_name: *const u16, window_name: *const u16) -> HWND;
    fn FindWindowExW(parent: HWND, child_after: HWND, class_name: *const u16, window_name: *const u16) -> HWND;
    fn SendMessageW(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LPARAM;
    fn GetWindowThreadProcessId(hwnd: HWND, process_id: *mut u32) -> u32;
    fn OpenProcess(access: u32, inherit: BOOL, process_id: u32) -> HANDLE;
    fn VirtualAllocEx(process: HANDLE, address: *mut c_void, size: usize, alloc_type: u32, protect: u32) -> *mut c_void;
    fn VirtualFreeEx(process: HANDLE, address: *mut c_void, size: usize, free_type: u32) -> BOOL;
    fn WriteProcessMemory(process: HANDLE, address: *mut c_void, buffer: *const c_void, size: usize, written: *mut usize) -> BOOL;
    fn ReadProcessMemory(process: HANDLE, address: *mut c_void, buffer: *mut c_void, size: usize, read: *mut usize) -> BOOL;
    fn CloseHandle(handle: HANDLE) -> BOOL;
}

const LVM_FIRST: u32 = 0x1000;
const LVM_GETITEMCOUNT: u32 = LVM_FIRST + 4;
const LVM_GETITEMRECT: u32 = LVM_FIRST + 14;
const LVIR_ICON: i32 = 1;

const PROCESS_VM_OPERATION: u32 = 0x0008;
const PROCESS_VM_READ: u32 = 0x0010;
const PROCESS_VM_WRITE: u32 = 0x0020;
const MEM_COMMIT: u32 = 0x1000;
const MEM_RELEASE: u32 = 0x8000;
const PAGE_READWRITE: u32 = 0x04;

#[no_mangle]
pub unsafe extern "C" fn get_desktop_icons(out_rects: *mut WidgetRect, max_count: i32) -> i32 {
    let progman_name = [80u16, 114, 111, 103, 109, 97, 110, 0]; // "Progman"
    let shell_def_name = [83u16, 72, 69, 76, 76, 68, 76, 76, 95, 68, 101, 102, 86, 105, 101, 119, 0];
    let worker_w_name = [87u16, 111, 114, 107, 101, 114, 87, 0];
    let list_view_name = [83u16, 121, 115, 76, 105, 115, 116, 86, 105, 101, 119, 51, 50, 0];

    let h_progman = FindWindowW(progman_name.as_ptr(), std::ptr::null());
    let mut h_shell_view = FindWindowExW(h_progman, 0, shell_def_name.as_ptr(), std::ptr::null());
    
    if h_shell_view == 0 {
        let mut h_workerw = 0;
        loop {
            h_workerw = FindWindowExW(0, h_workerw, worker_w_name.as_ptr(), std::ptr::null());
            if h_workerw == 0 { break; }
            h_shell_view = FindWindowExW(h_workerw, 0, shell_def_name.as_ptr(), std::ptr::null());
            if h_shell_view != 0 { break; }
        }
    }
    
    if h_shell_view == 0 { return 0; }
    let h_listview = FindWindowExW(h_shell_view, 0, list_view_name.as_ptr(), std::ptr::null());
    if h_listview == 0 { return 0; }
    
    let count = SendMessageW(h_listview, LVM_GETITEMCOUNT, 0, 0) as i32;
    if count <= 0 { return 0; }
    
    let mut proc_id = 0;
    GetWindowThreadProcessId(h_listview, &mut proc_id);
    let h_proc = OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE, 0, proc_id);
    if h_proc == 0 { return 0; }
    
    let p_rect = VirtualAllocEx(h_proc, std::ptr::null_mut(), std::mem::size_of::<RECT>(), MEM_COMMIT, PAGE_READWRITE);
    if p_rect.is_null() { CloseHandle(h_proc); return 0; }
    
    let final_count = if count > max_count { max_count } else { count };
    let mut actual_found = 0;
    
    for i in 0..final_count {
        let mut r = RECT { left: LVIR_ICON, ..Default::default() };
        WriteProcessMemory(h_proc, p_rect, &r as *const _ as *const c_void, std::mem::size_of::<RECT>(), std::ptr::null_mut());
        SendMessageW(h_listview, LVM_GETITEMRECT, i as usize, p_rect as isize);
        ReadProcessMemory(h_proc, p_rect, &mut r as *mut _ as *mut c_void, std::mem::size_of::<RECT>(), std::ptr::null_mut());
        
        let width = r.right - r.left;
        let height = r.bottom - r.top;
        if width > 0 && height > 0 {
          *out_rects.offset(actual_found as isize) = WidgetRect {
              left: r.left,
              top: r.top,
              width,
              height,
          };
          actual_found += 1;
        }
    }
    
    VirtualFreeEx(h_proc, p_rect, 0, MEM_RELEASE);
    CloseHandle(h_proc);
    actual_found
}

#[no_mangle]
pub unsafe extern "C" fn calculate_snap(
    current_x: i32, current_y: i32, width: i32, height: i32,
    peers_ptr: *const WidgetRect, peer_count: i32,
    icons_ptr: *const WidgetRect, icon_count: i32,
    out_x: *mut i32, out_y: *mut i32
) -> i32 {
    let mut final_x = current_x;
    let mut final_y = current_y;
    let threshold = 30; // Increased threshold for better feel
    let mut snapped = 0;

    let mut best_dist_x = i32::MAX;
    let mut best_dist_y = i32::MAX;

    // --- Peer Snapping (High Priority) ---
    for i in 0..peer_count {
        let p = &*peers_ptr.offset(i as isize);
        let p_right = p.left + p.width;
        let p_bottom = p.top + p.height;

        check_val(current_x, p_right + 10, threshold, &mut final_x, &mut best_dist_x, &mut snapped);
        check_val(current_x + width, p.left - 10, threshold, &mut final_x, &mut best_dist_x, &mut snapped);
        check_val(current_x, p.left, threshold, &mut final_x, &mut best_dist_x, &mut snapped);
        check_val(current_x + width, p_right, threshold, &mut final_x, &mut best_dist_x, &mut snapped);

        check_val(current_y, p_bottom + 10, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
        check_val(current_y + height, p.top - 10, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
        check_val(current_y, p.top, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
        check_val(current_y + height, p_bottom, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
    }

    // --- Desktop Icon Snapping ---
    for i in 0..icon_count {
        let p = &*icons_ptr.offset(i as isize);
        // Snap to icon left/top/right/bottom edges
        check_val(current_x, p.left, threshold, &mut final_x, &mut best_dist_x, &mut snapped);
        check_val(current_x + width, p.left + p.width, threshold, &mut final_x, &mut best_dist_x, &mut snapped);
        check_val(current_y, p.top, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
        check_val(current_y + height, p.top + p.height, threshold, &mut final_y, &mut best_dist_y, &mut snapped);
    }
    
    *out_x = final_x;
    *out_y = final_y;
    snapped
}

fn check_val(val: i32, target: i32, threshold: i32, out: &mut i32, best_dist: &mut i32, snapped: &mut i32) {
    let dist = (val - target).abs();
    if dist < threshold && dist < *best_dist {
        *best_dist = dist;
        *out = target;
        *snapped = 1;
    }
}

#[no_mangle]
pub unsafe extern "C" fn test_collision(
    x: i32, y: i32, w: i32, h: i32,
    targets_ptr: *const WidgetRect, count: i32
) -> i32 {
    for i in 0..count {
        let t = &*targets_ptr.offset(i as isize);
        if x < t.left + t.width && x + w > t.left && y < t.top + t.height && y + h > t.top {
            return 1;
        }
    }
    0
}
