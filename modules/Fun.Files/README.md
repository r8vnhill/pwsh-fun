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
    - [`Show-FileContents`](#show-filecontents)
      - [🔍 Basic Usage](#-basic-usage-1)
      - [📦 Multiple Paths](#-multiple-paths)
      - [🧩 From the Pipeline](#-from-the-pipeline)
    - [`Get-FileContents`](#get-filecontents)
      - [✅ Basic Usage](#-basic-usage-2)
      - [🔍 Filter with Regex](#-filter-with-regex)
      - [📁 Multiple Directories](#-multiple-directories-1)
      - [🧪 Pipeline Input](#-pipeline-input)
      - [🧵 Process Files](#-process-files)
      - [🧩 Combine with Clipboard or Display](#-combine-with-clipboard-or-display)
    - [`Copy-FileContents`](#copy-filecontents)
      - [Use Cases](#use-cases)
      - [Pipelining Examples](#pipelining-examples)
    - [`Compress-FilteredFiles`](#compress-filteredfiles)
      - [🧩 Basic Usage](#-basic-usage-3)
      - [🎯 Include and Exclude Patterns](#-include-and-exclude-patterns)
      - [� With Pipeline Input](#-with-pipeline-input-1)
      - [🔬 What-If Support](#-what-if-support)
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

### `Show-FileContents`

Recursively displays file contents from one or more directories with readable headers and optional ANSI color formatting.

#### 🔍 Basic Usage

```powershell
Show-FileContents -Path './docs'
```

Prints all files under `./docs` with cyan headers and gray content (if supported by your terminal).

#### 📦 Multiple Paths

```powershell
Show-FileContents -Path './src', './examples'
```

Recursively prints all files from both `./src` and `./examples`.

#### 🧩 From the Pipeline

```powershell
'./src', './tests' | Show-FileContents
```

Same as above, but provides paths via pipeline input—ideal for dynamic or filtered lists.

> 💡 Color formatting (cyan for headers, gray for content) is automatically disabled in unsupported environments like CI logs.

### `Get-FileContents`

Recursively returns `[FileContent]` objects for matching files in one or more directories.

Each object includes:
- **`Path`**: Full file path
- **`Header`**: A formatted label like `File: ./path/to/file.txt`
- **`ContentText`**: Raw content of the file as a single string

#### ✅ Basic Usage

```powershell
Get-FileContents -Path './src'
```

Returns all files under `./src`.

#### 🔍 Filter with Regex

```powershell
Get-FileContents -Path './src' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'tests/'
```

Includes only `.ps1` files, excluding any under a `tests/` folder.

#### 📁 Multiple Directories

```powershell
Get-FileContents -Path './src', './lib'
```

Reads all files under both directories.

#### 🧪 Pipeline Input

```powershell
'./src', './docs' | Get-FileContents
```

Reads all files from the piped directories.

#### 🧵 Process Files

```powershell
$files = Get-FileContents -Path './logs' -IncludeRegex '.*\.log$'
$files | ForEach-Object {
    "$($_.Header)`n$($_.ContentText.Length) bytes"
}
```

Prints each file's header and its content length.

#### 🧩 Combine with Clipboard or Display

```powershell
Get-FileContents -Path './examples' |
    ForEach-Object { $_.ToString() } |
    Set-Clipboard
```

Copies formatted file previews to clipboard.

### `Copy-FileContents`

Recursively copies file contents (with headers) to your clipboard **and returns them as strings**, making it easy to integrate into pipelines.

```powershell
Copy-FileContents -Path './src' -IncludeRegex '.*\.ps1$'
```

This command:

- Recursively finds `.ps1` files under `./src`
- Prepends each with a formatted header
- Copies the full result to your clipboard
- Returns the formatted text as output

#### Use Cases

- 📋 Sharing annotated code snippets
- 🐞 Debugging and reproducing issues
- 📚 Collecting content for documentation

#### Pipelining Examples

```powershell
# Save copied content to a file as well
Copy-FileContents -Path './examples' | Set-Content 'snippet.txt'

# Search within the copied output
Copy-FileContents -Path './data' | Select-String 'TODO'
```

The command can accept multiple paths or pipeline input:

```powershell
# Use piped paths
'./src', './lib' | Copy-FileContents
```

💡 Ideal when combining multiple folders or filtering content before pasting.

### `Compress-FilteredFiles`

Compresses a set of filtered files into a `.zip` archive, preserving directory structure relative to each root.

#### 🧩 Basic Usage

```powershell
Compress-FilteredFiles -Path './src' -DestinationZip 'output.zip'
```

Archives all files under `./src` into `output.zip`.

#### 🎯 Include and Exclude Patterns

```powershell
Compress-FilteredFiles `
    -Path './modules' `
    -DestinationZip 'archive.zip' `
    -IncludeRegex '.*\.ps1$', '.*\.psm1$' `
    -ExcludeRegex '.*\/tests\/.*'
```

Includes only `.ps1` and `.psm1` files under `./modules`, skipping any in `tests` folders.

#### 🔁 With Pipeline Input

```powershell
'./src', './lib' | Compress-FilteredFiles -DestinationZip 'combined.zip'
```

Accepts paths from the pipeline for flexibility in scripts and filters.

#### 🔬 What-If Support

```powershell
Compress-FilteredFiles -Path './docs' -DestinationZip 'docs.zip' -WhatIf
```

Simulates the operation without writing any files. Useful for dry runs or CI setups.

> 💡 The command only emits output once when not streaming input, and does nothing if no files match.

## 📄 License

BSD 2-Clause License  
[opensource.org/license/bsd-2-clause](https://opensource.org/license/bsd-2-clause)

## 👨‍💻 Author

**Ignacio Slater-Muñoz**  
[github.com/r8vnhill](https://github.com/r8vnhill)

## 📬 Contributing

Feel free to fork, file issues, or suggest improvements!
