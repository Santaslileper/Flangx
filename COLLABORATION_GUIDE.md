# 🐛 Bug Report

**Before reporting:** Please check the [ISSUE_TEMPLATE.md](.github/ISSUE_TEMPLATE.md) and ensure your bug hasn't been reported.

## How to Report
1. **Title**: Concise summary (e.g., "[BUG] Widget disappears on dual monitor").
2. **Setup**: OS Version, .NET version, and Screen Resolution.
3. **Steps to Reproduce**: 
   - 1. Open Master Launcher.
   - 2. Click [+] and select 'Browser'.
   - 3. [Your step here]
4. **Expected vs Actual**: What did you think would happen? What actually happened?
5. **Logs**: If the application crashed, provide the output from the terminal/PowerShell window.

---

# 💡 Feature Requests
We welcome suggestions for new widgets and core engine improvements!

1. Check if the feature is already discussed in open issues.
2. Provide a clear description of the use case.
3. Sketch out the UI or logic if possible.

---

# 🚀 Pull Request Guidelines
1. **Proprietary Notice**: All contributions are licensed under the [LICENSE.md](LICENSE.md).
2. **Minimalist Design**: Keep the UI clean and follow the Windows 10/11 "Glassmorphism" aesthetic.
3. **Legacy Compatibility**: Code MUST compile with `csc.exe` (C# 5.0 / .NET 4.0). Do not use modern syntax like `?.` or `out var`.
4. **Comment-Free**: Submit code without developer comments to maintain the shipping look.
