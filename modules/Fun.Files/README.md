# 📁 Fun.Files

**Fun.Files** is a PowerShell module for exploring, transforming, and copying file contents in a structured and flexible way. It’s ideal for auditing files, gathering snippets, scripting transformations, or preparing content for pasting into editors or issue trackers.

## Table of Contents

- [📁 Fun.Files](#-funfiles)
  - [Table of Contents](#table-of-contents)
  - [✨ Features](#-features)
  - [📦 Installation](#-installation)
  - [🧩 Commands](#-commands)
    - [`Invoke-FileTransform`](#invoke-filetransform)
      - [🔧 Basic usage](#-basic-usage)
      - [🎯 Filtering with multiple patterns](#-filtering-with-multiple-patterns)
      - [📂 Multiple directories](#-multiple-directories)
      - [🔁 With pipeline input](#-with-pipeline-input)
      - [🧪 Transform and overwrite](#-transform-and-overwrite)
    - [`Get-FilteredFiles`](#get-filteredfiles)
    - [`Show-FileContents`](#show-filecontents)
    - [`Get-FileContents`](#get-filecontents)
    - [`Copy-FileContents`](#copy-filecontents)
  - [📄 License](#-license)
  - [👨‍💻 Author](#-author)
  - [📬 Contributing](#-contributing)

## ✨ Features

- 📄 Recursively process files with customizable transformations
- 🔍 Advanced file filtering using regular-expression-based include/exclude patterns
- 🔁 Inject custom logic per file using `Invoke-FileTransform`
- 📋 Copy multiple files’ contents to clipboard with formatting

## 📦 Installation

From `pwsh-fun` root:

```powershell
Import-Module "./modules/Fun.Files/Fun.Files.psd1"
```

## 🧩 Commands

### `Invoke-FileTransform`

Recursively applies a script block to all matching files in one or more directories. You can filter files using regular expressions on their relative paths.

#### 🔧 Basic usage

```powershell
Invoke-FileTransform -Path './logs' -FileProcessor {
    param ($file, $header)
    Write-Host $header
    Get-Content $file -Raw
}
```

Prints the full content of every file under `./logs`, each prefixed with its full path.

#### 🎯 Filtering with multiple patterns

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

Processes `.log` and `.txt` files but skips any located in `archive/` folders or with names starting with `old_`.

#### 📂 Multiple directories

```powershell
Invoke-FileTransform -Path './src', './tests' -IncludeRegex '.*\.ps1$' -FileProcessor {
    param ($file, $header)
    "$header`n$([IO.File]::ReadAllText($file.FullName))" | Set-Clipboard
}
```

Copies all PowerShell scripts from `./src` and `./tests` to the clipboard, prepending each with its full path. (This is what [`Copy-FileContents`](#copy-filecontents) does)

#### 🔁 With pipeline input

```powershell
'./docs', './examples' | Invoke-FileTransform -IncludeRegex '.*\.md$' -FileProcessor {
    param ($file, $header)
    "$header`n$($file.Length) bytes"
}
```

Uses pipeline input to process all Markdown files from multiple directories, printing the file size and path.

#### 🧪 Transform and overwrite

```powershell
Invoke-FileTransform -Path './notes' -IncludeRegex '.*\.md$' -FileProcessor {
    param ($file, $header)
    $text = Get-Content $file -Raw
    $newText = $text -replace 'TODO', '✅'
    Set-Content $file.FullName -Value $newText
}
```

Searches for `TODO` in all Markdown files and replaces them with ✅.

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

## 📄 License

BSD 2-Clause License  
[opensource.org/license/bsd-2-clause](https://opensource.org/license/bsd-2-clause)

## 👨‍💻 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://github.com/r8vnhill)

## 📬 Contributing

Feel free to fork, file issues, or suggest improvements!
