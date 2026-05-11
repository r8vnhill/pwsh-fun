# 📁 Fun.Ffmpeg

**Fun.Ffmpeg** is a PowerShell module for ... TODO

## Table of Contents

- [📁 Fun.Ffmpeg](#-funffmpeg)
  - [Table of Contents](#table-of-contents)
  - [✨ Features](#-features)
  - [📦 Installation](#-installation)
  - [🧩 Commands](#-commands)
  - [📄 License](#-license)
  - [👨‍💻 Author](#-author)
  - [📬 Contributing](#-contributing)

## ✨ Features

- TODO
- ...

## 📦 Installation

From `pwsh-fun` root:

```powershell
Import-Module "./modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1"
```

## 🧩 Commands

- `Convert-ToVvc`: Convert video files to VVC (H.266) with optional validation and parallel execution.
  Uses explicit ffmpeg/ffprobe paths, unique same-directory temporary files, and
  atomic promotion after validation. `-EncoderThreads` controls the ffmpeg
  `-threads` value and defaults to `0`, preserving ffmpeg automatic thread
  selection.
- `Invoke-FunFfmpegInternalVvcWorker`: exported only as an internal parallel
  runspace entrypoint for `Convert-ToVvc`; do not call it directly.

## 📄 License

BSD 2-Clause License  
[opensource.org/license/bsd-2-clause](https://opensource.org/license/bsd-2-clause)

## 👨‍💻 Author

**Ignacio Slater-Muñoz**  
[gitlab.com/r8vnhill](https://gitlab.com/r8vnhill)

## 📬 Contributing

Feel free to fork, file issues, or suggest improvements!
