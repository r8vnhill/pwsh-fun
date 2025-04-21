# 📁 Fun.Files

**Fun.Files** is a PowerShell module for exploring, transforming, and copying file contents in a structured and flexible way. It’s ideal for auditing files, gathering snippets, scripting transformations, or preparing content for pasting into editors or issue trackers.

## ✨ Features

- 📄 Recursively process files with customizable transformations
- 🔍 Advanced file filtering using regular-expression-based include/exclude patterns
- 🔁 Inject custom logic per file using `Invoke-FileTransform`
- 📋 Copy multiple files’ contents to clipboard with formatting

## 📦 Installation

From `pwsh-fun` root:

```powershell
Import-Module "$PWD/modules/Fun.Files/Fun.Files.psd1"
```

## 🧩 Commands

### `Invoke-FileTransform`

The backbone of the module: recursively apply a script block to all files in a directory.

```powershell
Invoke-FileTransform -Path './logs' `
    -IncludeRegex '.*\.log$', '.*\.txt$' `
    -ExcludeRegex 'archive/', '^old_' `
    -FileProcessor {
        param ($file, $header)
        Write-Host $header
        Get-Content $file -Raw
    }
```

This will process `.log` and `.txt` files under `./logs`, but skip any files inside an `archive/` folder or starting with `old_`.

### `Get-FilteredFiles`

Returns `[System.IO.FileInfo]` objects for files filtered by regular expressions:

```powershell
Get-FilteredFiles -RootPath './src' `
                  -IncludeRegex '.*\.ps1$' `
                  -ExcludeRegex 'tests/'
```

### `Show-FileContents`

Prints all files under a directory with formatted headers and content blocks:

```powershell
Show-FileContents -Path './docs'
```

### `Get-FileContents`

Returns `[FileContent]` objects for matching files:

```powershell
Get-FileContents -Path './src' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'tests/'
```

Each object contains:

- `Path`: full file path
- `Header`: formatted header string
- `ContentText`: full contents of the file

### `Copy-FileContents`

Copies file contents (with headers) to your clipboard:

```powershell
Copy-FileContents -Path './src' -IncludeRegex '.*\.ps1$'
```

Useful for:
- Sharing code snippets
- Debugging
- Documentation

## 🧠 Type: `FileContent`

An internal type supporting formatting and clipboard functionality:

```powershell
[FileContent]::new("path", "File: path", "raw content")
```

## 🏷 Tags

`files`, `clipboard`, `utils`, `transform`, `text`

## 📄 License

BSD 2-Clause License  
[opensource.org/license/bsd-2-clause](https://opensource.org/license/bsd-2-clause)

## 👨‍💻 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://github.com/r8vnhill)

## 📬 Contributing

Feel free to fork, file issues, or suggest improvements!
