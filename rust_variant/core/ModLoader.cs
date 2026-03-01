using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Microsoft.CSharp;
using System.CodeDom.Compiler;
using System.Linq;

namespace DesktopWidgets {
    public static class ModLoader {
        private static Dictionary<string, Type> _mods = new Dictionary<string, Type>();
        public static IEnumerable<string> ModTypes { get { return _mods.Keys; } }

        public static void Load() {
            string modDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mods");
            if (!Directory.Exists(modDir)) Directory.CreateDirectory(modDir);

            string[] files = Directory.GetFiles(modDir, "*.cs");
            CSharpCodeProvider provider = new CSharpCodeProvider(new Dictionary<string, string> { { "CompilerVersion", "v4.0" } });
            CompilerParameters parms = new CompilerParameters {
                GenerateExecutable = false,
                GenerateInMemory = true,
                ReferencedAssemblies = { 
                    "System.dll", "System.Drawing.dll", "System.Windows.Forms.dll", "System.Core.dll", "System.Data.dll",
                    Assembly.GetExecutingAssembly().Location 
                }
            };

            foreach (string f in files) {
                try {
                    CompilerResults res = provider.CompileAssemblyFromFile(parms, f);
                    if (res.Errors.HasErrors) continue;

                    foreach (Type t in res.CompiledAssembly.GetTypes()) {
                        if (typeof(WidgetHost).IsAssignableFrom(t) && !t.IsAbstract) {
                            string name = t.Name.Replace("Widget", "");
                            _mods[name] = t;
                        }
                    }
                } catch { }
            }
        }

        public static WidgetHost CreateMod(string type, string id) {
            if (!_mods.ContainsKey(type)) return null;
            return (WidgetHost)Activator.CreateInstance(_mods[type], new object[] { id });
        }
    }
}
