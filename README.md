# 🎉 pwsh-fun

[![PowerShell](https://img.shields.io/badge/pwsh-7%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/github/license/r8vnhill/pwsh-fun?color=informational)](./LICENSE)

**`pwsh-fun`** is a modular PowerShell toolkit for working with files in a fun, scriptable, and flexible way. It provides utilities for reading, transforming, copying, and displaying file contents — plus tooling to manage the modular structure itself.

Whether you're inspecting logs, collecting code snippets, or building custom transformation pipelines, `pwsh-fun` gives you a consistent and extensible interface.

## 📚 Modules

This project is composed of two main modules:

### 📁 [Fun.Files](./modules/Fun.Files/README.md)

Tools for working with file contents:

- ✅ Process files recursively with custom logic
- 🔍 Filter with include/exclude regex patterns
- 🖨 Display file contents with headers and colors
- 📋 Copy structured file blocks to your clipboard

### 🧩 [Fun.Loader](./modules/Fun.Loader/README.md)

Manage module loading:

- Dynamically load all submodules in one command (`Install-FunModules`)
- Unload them just as easily (`Remove-FunModules`)

## ✨ Example Usage

```powershell
# Load everything
Import-Module ./modules/Fun.Loader/Fun.Loader.psd1
Install-FunModules

# Display file contents with formatting
Show-FileContents -Path './examples'

# Copy .ps1 files to clipboard
Copy-FileContents -Path './src' -IncludeRegex '.*\.ps1$'

# Use regex-powered transformations
Invoke-FileTransform -Path './logs' -IncludeRegex '.*\.log$' -FileProcessor {
    param ($file, $header)
    "$header`n$((Get-Content $file -Raw).Length) bytes"
}
```

## 📦 Installation

Clone the repo and import modules directly from the `modules/` folder:

```powershell
git clone https://github.com/r8vnhill/pwsh-fun
cd pwsh-fun
Import-Module ./modules/Fun.Loader/Fun.Loader.psd1
Install-FunModules
```

> 📌 This only installs the modules for the current session.

## 🔁 Persistent Setup

To have access to `pwsh-fun` commands in **all sessions**, add the following to your PowerShell profile:

```powershell
# Your profile path:
# $PROFILE or $PROFILE.CurrentUserAllHosts
Import-Module "C:\path\to\pwsh-fun\modules\Fun.Loader\Fun.Loader.psd1"
Install-FunModules
```

To open your profile for editing:

```powershell
code $PROFILE
```

Or create one if it doesn’t exist:

```powershell
if (!(Test-Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }
```

## 🛠️ Development Structure

```plaintext
pwsh-fun/
├── modules/
│   ├── Fun.Files/    # File inspection and transformation utilities
│   └── Fun.Loader/   # Module loading/unloading infrastructure
├── tests/            # Pester tests for all modules
└── README.md         # You are here
```

## 👥 Contributing

All contributions are welcome! Please follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

- Use `pwsh` 7+
- Follow existing coding and documentation style
- Submit PRs with tests if possible

## 📄 License

This project is licensed under the [BSD 2-Clause License](./LICENSE).

## 🙋 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://github.com/r8vnhill)

Have fun scripting 🐚
