# 🧩 Fun.Loader

**Fun.Loader** is a utility module in the [`pwsh-fun`](https://github.com/r8vnhill/pwsh-fun) project designed to dynamically load and unload all modular components in the repository.

This module includes two functions:

- `Install-FunModules`: Loads all `.psm1` modules found in the `modules/` folder into the current PowerShell session.
- `Remove-FunModules`: Unloads any currently loaded `pwsh-fun` modules from the session.

## 📦 Functions

### `Install-FunModules`

Dynamically loads all `.psm1` files found in subfolders of the `modules/` directory.

#### Features:

- Supports `-WhatIf`, `-Confirm`, and `-Verbose`
- Uses `Import-Module -Scope Global` so functions are accessible in the current session
- Skips missing `.psm1` files with a warning

#### Examples

```powershell
Install-FunModules
Install-FunModules -Verbose
Install-FunModules -BasePath "C:\path\to\pwsh-fun"
```

### `Remove-FunModules`

Removes all currently loaded modules that were imported from the `modules/` folder.

#### Features:

- Supports `-WhatIf`, `-Confirm`, and `-Verbose`
- Only removes modules that are actively loaded
- Skips unloaded modules silently

#### Examples

```powershell
Remove-FunModules
Remove-FunModules -WhatIf
Remove-FunModules -Verbose
```

## 🛠️ Development

To update the list of available functions, edit the following files:

- `public/Install-FunModules.ps1`
- `public/Remove-FunModules.ps1`
- `Fun.Loader.psm1` (for dot-sourcing)
- `Fun.Loader.psd1` (for exported metadata)

## 📁 Module Structure

```plaintext
Fun.Loader/
├── public/
│   ├── Install-FunModules.ps1
│   └── Remove-FunModules.ps1
├── Fun.Loader.psm1
├── Fun.Loader.psd1
└── README.md
```

## 🔗 Related

- [Main Repository](https://github.com/r8vnhill/pwsh-fun)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)