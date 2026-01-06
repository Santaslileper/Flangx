Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$coreDir = $PSScriptRoot
. "$coreDir\app_config.ps1"
. "$coreDir\logging_utils.ps1" 
. "$coreDir\window_utils.ps1"
. "$coreDir\desktop_icons.ps1"
. "$coreDir\grid_logic.ps1"
. "$coreDir\widget_utils.ps1"
. "$coreDir\theme_utils.ps1"
. "$coreDir\widget_state.ps1"
. "$coreDir\widget_interaction.ps1"
. "$coreDir\widget_context_menu.ps1"
. "$coreDir\widget_factory.ps1"
