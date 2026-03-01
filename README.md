<div align="center">

# 🏢 Flangx: Desktop Widgets
**"Direct Window-Grid Coupling for Windows"**

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%28x64%29-blue?style=flat-square&logo=windows)](https://github.com/Santaslileper/Flangx)
[![Language](https://img.shields.io/badge/Language-Rust%20%2F%20C%23-orange?style=flat-square&logo=rust)](https://github.com/Santaslileper/Flangx)
[![Runtime](https://img.shields.io/badge/Runtime-.NET%204.0%2B-512BD4?style=flat-square&logo=.net)](https://github.com/Santaslileper/Flangx)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=flat-square)](md/LICENSE.md)

[Download Release](Flangx_Release.zip) • [Report Bug](https://github.com/Santaslileper/Flangx/issues) • [Source](src/) • [Mod SDK](mods/) • [Safety](md/SECURITY.md)

---

<img src="assets/preview.png" width="850" alt="Flangx Desktop Layout">

Drawing on mechanical engineering concepts, **Flangx** treats your desktop as a physical grid. Every widget is locked to the Windows icon system using a structural "flange" logic, providing consistent alignment and predictable window behavior.

---

</div>

### 🛠️ Technical Specifications
| **Component** | **Implementation Details** | **System Impact** |
| :--- | :--- | :--- |
| **Logic Layer** | Rust 1.70+ (`interaction.dll`) | Shared memory process access |
| **User Interface** | GDI+ Windows Forms (`Flangx.exe`) | Managed execution / Direct2D |
| **Memory Access** | Win32 `ReadProcessMemory` | No telemetry / Local only |
| **Compilation** | JIT via `csc.exe` (v4.0.30319) | Native binary execution |
| **State Storage** | Local JSON Persistence | 100% Offline |

---

### ✨ Core Features
*   📍 **Grid Alignment**: Snaps widgets to the existing Windows desktop icon grid (typically 100x100 or 75x75).
*   📦 **Collision Handling**: Dragging widgets into occupied grid spaces repositions existing elements.
*   🛠️ **Native Tools**:
    *   🕒 **Clock**: Direct system time synchronization.
    *   ⏲️ **Timer**: Local countdown execution.
    *   🌐 **HTML Renderer**: Standard browser frame for local/web reference.
    *   🧮 **Calculator**: Basic arithmetic processing.
*   🔌 **Modding Interface**: Automatically compiles `.cs` scripts found in the `mods/` directory at runtime.
*   💾 **Haptic Configuration**: Remembers position, size, and opacity settings via local config.

---

### 🔬 Technical Design Patterns
| **Pattern** | **Method** | **Result** |
| :--- | :--- | :--- |
| **Grid Mapping** | Win32 `FindWindowEx` / `ListView` hooks | Icon-relative positioning |
| **Dynamic Loading** | `System.Reflection` / C# Mod logic | Runtime tool expansion |
| **Efficiency** | Split-engine (Rust + C#) | Minimal background overhead |

---

### ⚡ Build & Deployment
Build the binary directly using your local Windows environment (No IDE required):

```powershell
# 1. Access the Flangx directory
cd Flangx

# 2. Compile using the native .NET Framework compiler
& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:Flangx.exe src/*.cs /reference:System.Windows.Forms.dll,System.Drawing.dll,System.Core.dll,System.Data.dll,System.Xml.dll /win32icon:assets/clock_icon.ico /platform:x64; Start-Process .\Flangx.exe
```

---

### 🛡️ Safety & Documentation
> [!IMPORTANT]
> **Data Isolation**: Flangx does not establish external network connections for core logic. All notes, layouts, and timer data are stored locally in the application directory.

| **Reference** | **Description** | **Requirement** |
| :--- | :--- | :--- |
| **[License](md/LICENSE.md)** | Proprietary Terms | Mandatory |
| **[Safety](md/SECURITY.md)** | Security Protocols | Advisory |
| **[Contribution](md/CONTRIBUTING.md)** | Development Guide | Optional |
| **[Conduct](md/CODE_OF_CONDUCT.md)** | Community Standards | Mandatory |
| **[Support](md/SUPPORT.md)** | Technical Help | Technical |

---

### ⚖️ License
This repository is released under **Proprietary (Structured Freedom)**. All rights reserved. 

<div align="center">
  
[Santaslileper](https://github.com/Santaslileper)

</div>
