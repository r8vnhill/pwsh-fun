# 🎉 pwsh-fun

[![PowerShell](https://img.shields.io/badge/pwsh-7%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/github/license/r8vnhill/pwsh-fun?color=informational)](./LICENSE)

**`pwsh-fun`** is a modular PowerShell toolkit for working with files in a structured, scriptable, and extensible way. Whether you're processing logs, building transformation pipelines, or preparing content for pasting, `pwsh-fun` helps you do it with consistency and fun.

## 📚 Modules

This toolkit is split into modular components that work great together:

### 📁 [Fun.Files](./modules/Fun.Files/README.md)

Advanced file inspection and transformation:

- ✅ Recursively process files with custom logic
- 🔍 Filter using include/exclude regular expressions
- 🖨 Display file contents with readable headers and color
- 📋 Copy contents to the clipboard with formatting
- 🗜 Compress selected files into `.zip` archives

See [`Fun.Files`](./modules/Fun.Files/README.md) for usage examples of:
- `Invoke-FileTransform`
- `Show-FileContents`
- `Get-FileContents`
- `Copy-FileContents`
- `Compress-FilteredFiles`

### 🧩 [Fun.Loader](./modules/Fun.Loader/README.md)

Simple module bootstrapping and cleanup:

- `Install-FunModules`: Loads all submodules from the `modules/` folder
- `Remove-FunModules`: Removes previously loaded submodules from the session

This is the easiest way to bootstrap the entire toolkit in a script or development shell.

## ✨ Example Usage

```powershell
# Load all pwsh-fun modules
Import-Module ./modules/Fun.Loader/Fun.Loader.psd1
Install-FunModules

# Display Markdown files with colored headers
Show-FileContents -Path './docs' -IncludeRegex '.*\.md$'

# Replace TODOs in all notes
Invoke-FileTransform -Path './notes' -IncludeRegex '.*\.md$' -FileProcessor {
    param ($file, $header)
    $text = Get-Content $file -Raw
    Set-Content $file -Value ($text -replace 'TODO', '✅')
}

# Copy code snippets to the clipboard
Copy-FileContents -Path './src' -IncludeRegex '.*\.ps1$'

# Archive only `.ps1` and `.psm1` files, skipping tests
Compress-FilteredFiles `
  -Path './modules' `
  -DestinationZip 'archive.zip' `
  -IncludeRegex '.*\.ps1$', '.*\.psm1$' `
  -ExcludeRegex 'tests/'
```

## 📦 Installation

Clone the repository and import modules directly:

```powershell
git clone https://gitlab\.com/r8vnhill/pwsh-fun
cd pwsh-fun
Import-Module ./modules/Fun.Loader/Fun.Loader.psd1
Install-FunModules
```

📌 This loads the modules only for the current session.

## 🔁 Persistent Setup

To use `pwsh-fun` in every session, add to your PowerShell profile:

```powershell
Import-Module "C:\path\to\pwsh-fun\modules\Fun.Loader\Fun.Loader.psd1"
Install-FunModules
```

To edit your profile:

```powershell
code $PROFILE
```

Create one if it doesn't exist:

```powershell
if (!(Test-Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }
```

## 🛠️ Project Structure

```plaintext
pwsh-fun/
├── modules/
│   ├── Fun.Files/     # File transformation and archiving
│   └── Fun.Loader/    # Dynamic module loading
└── README.md          # Project overview and usage
```

## 👥 Contributing

All contributions are welcome! Please:

- Use `pwsh` 7 or later
- Follow the established style and patterns
- Include tests if submitting changes
- See the [Code of Conduct](./CODE_OF_CONDUCT.md)

## 📄 License

Licensed under the [BSD 2-Clause License](./LICENSE).  
Simple, permissive, and open.

## 🙋 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://gitlab\.com/r8vnhill)

Have *fun* scripting 🐚
