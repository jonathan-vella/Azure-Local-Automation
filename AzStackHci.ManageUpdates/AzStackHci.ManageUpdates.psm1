#Requires -Version 5.1
<#
.SYNOPSIS
    Deprecated. This module has been renamed to AzLocal.UpdateManagement.

.DESCRIPTION
    This is a TRANSITIONAL STUB. It contains no functions; importing it only
    emits a Write-Warning pointing to the renamed module (AzLocal.UpdateManagement).

    DO NOT depend on this package for any new automation. Migrate now:

        Uninstall-Module AzStackHci.ManageUpdates -AllVersions
        Install-Module AzLocal.UpdateManagement

    AzStackHci.ManageUpdates was renamed to AzLocal.UpdateManagement in v0.7.3
    to align with the Azure Local product name (Microsoft retired the
    "Azure Stack HCI" brand in late 2024). The module GUID is preserved across
    the rename.

.NOTES
    Author : Neil Bird, MSFT
    Version: 0.7.3 (transitional - final release under the legacy name)
#>

Write-Warning @'

==============================================================================
 AzStackHci.ManageUpdates has been renamed to AzLocal.UpdateManagement.

 This package is a transitional stub - it exports no functions and will be
 unlisted from PSGallery once remaining automation has migrated.

 Please update your automation to install the renamed module:

     Uninstall-Module AzStackHci.ManageUpdates -AllVersions
     Install-Module AzLocal.UpdateManagement

 See the migration note in the CHANGELOG:
   https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md
==============================================================================
'@
