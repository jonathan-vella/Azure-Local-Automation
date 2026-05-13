@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    # Matches the version of the renamed module (AzLocal.UpdateManagement v0.7.3)
    # to clearly signal this is the final release published under the legacy name.
    ModuleVersion = '0.7.3'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    # This is the same GUID that has been associated with AzStackHci.ManageUpdates
    # since v0.5.x. PSGallery requires the GUID to match across all versions of
    # a module ID, so this stub MUST carry forward the original GUID.
    GUID = 'a8b9c0d1-e2f3-4a5b-6c7d-8e9f0a1b2c3d'

    # Author of this module
    Author = 'Neil Bird, Microsoft'

    # Company or vendor of this module
    CompanyName = 'Microsoft'

    # Copyright statement for this module
    Copyright = '(c) Microsoft. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'DEPRECATED - this module has been renamed to AzLocal.UpdateManagement. This package is a transitional stub: it exports no functions and emits a deprecation warning on import that points to the new module name. Install the renamed module instead: Install-Module AzLocal.UpdateManagement. See https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md for the migration note.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module - none; this is a transitional stub.
    FunctionsToExport = @()

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Azure', 'AzureLocal', 'AzureStackHCI', 'Deprecated', 'Renamed', 'Updates')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/NeilBird/Azure-Local/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/NeilBird/Azure-Local'

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 0.7.3 - Module renamed to AzLocal.UpdateManagement

This package is a transitional stub. It exports no functions; importing it only
emits a deprecation warning.

AzStackHci.ManageUpdates has been renamed to AzLocal.UpdateManagement to align
with the Azure Local product name (Microsoft retired the "Azure Stack HCI"
brand in late 2024).

### Action required

    Uninstall-Module AzStackHci.ManageUpdates -AllVersions
    Install-Module AzLocal.UpdateManagement

All previously-published AzStackHci.ManageUpdates versions have been unlisted
from PSGallery. This v0.7.3 transitional stub will also be unlisted once any
remaining automation has migrated to the new name.

See:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md
'@
        }
    }
}
