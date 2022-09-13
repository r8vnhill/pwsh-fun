#
# Module manifest for module 'FileUtils'
#
# Generated by: R8V
#
# Generated on: 31-Mar-22
#

@{

  # Script module or binary module file associated with this manifest.
  RootModule        = 'Ravenhill.FileUtils.psm1'

  # Version number of this module.
  ModuleVersion     = '1.1.2207.1'

  # ID used to uniquely identify this module
  GUID              = '7cc0736f-5c85-48a9-b9d2-19bec5fdd433'


  # Author of this module
  Author            = 'R8V'

  # Company or vendor of this module
  CompanyName       = 'Ravenhill Studios'

  # Copyright statement for this module
  Copyright         = 'pwsh-fun by R8V is licensed under a Creative Commons Attribution 4.0 ' `
    + 'International License. Based on a work at https://github.com/r8vnhill/pwsh-fun.'

  # Description of the functionality provided by this module
  Description       = 'Commands to enhance functionalities for files and directories for ' + `
    'PowerShell.'
  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  ScriptsToProcess = @('Ravenhill.FileUtils_aux', 'ConvertTo-Icon.ps1')

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  # NestedModules = @()

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
  FunctionsToExport = @('Remove-EmptyDirectories', 'ConvertTo-Jpeg', 'ConvertTo-Icon', 
    'Compress-Directories')

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
  CmdletsToExport   = @()

  # Variables to export from this module
  VariablesToExport = @()

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
  AliasesToExport   = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
  # ModuleList = @()

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
  PrivateData       = @{

    PSData = @{

      # Tags applied to this module. These help with module discovery in online galleries.
      # Tags = @()

      # A URL to the license for this module.
      # LicenseUri = ''

      # A URL to the main website for this project.
      # ProjectUri = ''

      # A URL to an icon representing this module.
      # IconUri = ''

      # ReleaseNotes of this module
      # ReleaseNotes = ''

      # Prerelease string of this module
      # Prerelease = ''

      # Flag to indicate whether the module requires explicit user acceptance for install/update/save
      # RequireLicenseAcceptance = $false

      # External dependent modules of this module
      # ExternalModuleDependencies = @()

    } # End of PSData hashtable

  } # End of PrivateData hashtable

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''

}