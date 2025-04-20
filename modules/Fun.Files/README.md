# 📁 Fun.Files

**Fun.Files** is a PowerShell module for exploring, transforming, and copying file contents in a structured and color-enhanced way. It’s ideal for auditing files, gathering snippets, scripting transformations, or preparing content for pasting into editors or issue trackers.

## ✨ Features

- 📄 Recursively read and format files as `[FileContent]` objects
- 🎨 Color-coded display of file headers and content (if supported)
- 📋 Copy multiple files’ contents to clipboard with formatting
- 🔍 Advanced file filtering using wildcard-based include/exclude patterns
- 🔁 Inject your own logic per file using `Invoke-FileTransform`

## 📦 Installation

From `pwsh-fun` root:

```powershell
Import-Module "$PWD/modules/Fun.Files/Fun.Files.psd1"
```

## 🧩 Commands

### `Show-FileContents`

Prints all files under a directory with color-coded headers and content blocks.

```powershell
Show-FileContents -Path './docs'
```

### `Get-FileContents`

Returns `[FileContent]` objects for each matching file, including metadata and raw contents.

```powershell
Get-FileContents -Path './src' -IncludePatterns '*.ps1' -ExcludePatterns '*tests*'
```

Each object contains:

- `Path` – full file path
- `Header` – formatted string for display
- `ContentText` – full contents of the file

### `Copy-FileContents`

Copies file contents (with headers) to your clipboard, separated by newlines.

```powershell
Copy-FileContents -Path './src' -IncludePatterns '*.ps1'
```

Useful for:
- Sending code snippets
- Debugging
- Creating GitHub issues or documentation

### `Invoke-FileTransform`

The backbone of the module: recursively apply a script block to all files in a directory.

```powershell
Invoke-FileTransform -Path './logs' -FileProcessor {
    param ($file, $header)
    Write-Host $header
    Get-Content $file -Raw
}
```

## 🧠 Type: `FileContent`

This internal class powers the formatting and clipboard functionality.

```powershell
[FileContent]::new("path", "📄 File: path", "raw content")
```

You can override `.ToString()` to get a printable version of the file with its header.

## 🏷 Tags

`files`, `clipboard`, `utils`, `display`, `transform`, `text`

## 📄 License

BSD 2-Clause License  
[opensource.org/license/bsd-2-clause](https://opensource.org/license/bsd-2-clause)

## 👨‍💻 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://github.com/r8vnhill)

## 📬 Contributing

Feel free to fork, file issues, or suggest improvements!
