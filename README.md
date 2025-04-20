# 🧰 pwsh-fun

**pwsh-fun** is a modular PowerShell toolkit for working with files, terminal enhancements, and scripting productivity. Each submodule provides focused functionality that can be loaded independently or as part of the entire suite.

## 📦 Available Modules

| Module                               | Description                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------- |
| [`Fun.Files`](./modules/Fun.Files)   | Read, display, transform, and copy file contents with header formatting     |
| [`Fun.Loader`](./modules/Fun.Loader) | Load/unload all pwsh-fun modules easily in your current session             |
| `Fun.Terminal`                       | *(Coming soon)* Terminal-focused helpers for prompts, colors, and utilities |

## ⚡ Quick Start

```powershell
# Load all modules (development mode)
Import-Module .\modules\Fun.Loader\Fun.Loader.psd1
Install-FunModules
```

Or load a single module:

```powershell
Import-Module .\modules\Fun.Files\Fun.Files.psd1
```

## 🧩 Highlights

### `Show-FileContents`

View all file contents in a directory, with headers and optional color support.

```powershell
Show-FileContents -Path './examples'
```

### `Get-FileContents`

Get structured `[FileContent]` objects with path, header, and content text.

```powershell
Get-FileContents -Path './src' -IncludePatterns '*.ps1' -ExcludePatterns '*test*'
```

### `Copy-FileContents`

Copy the formatted contents of multiple files to your clipboard.

```powershell
Copy-FileContents -Path './logs'
```

### `Invoke-FileTransform`

Apply your own logic to each file.

```powershell
Invoke-FileTransform -Path './data' -FileProcessor {
    param ($file, $header)
    "$header`n$($file.Name.ToUpper())"
}
```

## 🏗️ Project Structure

```plaintext
pwsh-fun/
├── modules/
│   ├── Fun.Files/     # File operations module
│   ├── Fun.Loader/    # Module loader/unloader
│   └── Fun.Terminal/  # Terminal utilities (WIP)
├── .vscode/           # Dev environment settings
├── .gitignore
├── LICENSE
└── README.md
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
