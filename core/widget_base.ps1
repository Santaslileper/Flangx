# core/widget_base.ps1
# Base widget functionality - Aggregator
# This file now serves as a loader for the modular components.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Resolve path relative to this script
$coreDir = $PSScriptRoot

# Load Modules
. "$coreDir\window_utils.ps1"
. "$coreDir\desktop_icons.ps1"
. "$coreDir\grid_logic.ps1"
. "$coreDir\widget_utils.ps1"
. "$coreDir\theme_utils.ps1"
. "$coreDir\widget_state.ps1"
. "$coreDir\widget_interaction.ps1"
. "$coreDir\widget_context_menu.ps1"
. "$coreDir\widget_factory.ps1"
