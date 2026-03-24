# `Fun.OCD`

This module exists **solely** because I have OCD.

It's not a product. It's not a framework. It's not even sane.  
It's just a bunch of PowerShell commands I use to keep *my* systems clean, organized, and just the way I like them.

Also, it's a backup. Also, a reference. Also, maybe useful to you? Who knows.

> [!IMPORTANT]  
> ❗ **This module is not imported by default.**  
> It’s not in the GitHub releases. It’s not on PSGallery. It’s not manifesting via sheer will.  
> Clone the repo and import it manually if you're into that sort of thing.

> [!CAUTION]  
> Will it work on your machine? ¯\\\_(ツ)\_/¯  
> Works on mine. That’s the QA process.

## 🛠️ Importing the module

I don't know, maybe

```powershell
Import-Module -Name modules\Fun.OCD\Fun.OCD.psd1 -Force
```

Assuming you are on the correct path and have the module cloned.

## 🧪 Testing (or lack thereof)

Absolutely zero tests.  
This code is powered by vibes. **Read it before you run it.** Seriously.

## 📚 Documentation

Some commands have docs.  
Some don’t.  
Some are just eldritch incantations with `-WhatIf`.  
You’ve been warned.

## 📦 Reclaiming space with `Move-AndLinkItem`

`Move-AndLinkItem` is useful when `C:` is filling up with development tooling caches and local package stores.

If you want to push the usual offenders to `B:`, create a destination folder first:

```powershell
New-Item -ItemType Directory -Path 'B:\Dev-Cache' -Force
```

Then move them with junctions:

```powershell
$paths = @(
    'C:\Users\usuario\AppData\Local\ms-playwright',
    'C:\Users\usuario\AppData\Local\pnpm',
    'C:\Users\usuario\AppData\Local\pnpm-cache',
    'C:\Users\usuario\AppData\Local\uv',
    'C:\Users\usuario\AppData\Local\Coursier',
    'C:\Users\usuario\AppData\Local\cabal'
)

foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        Move-AndLinkItem -PathToSymlink $path -PathToContent 'B:\Dev-Cache' -UseJunction
    }
}
```

That leaves the original paths in place as junctions, so your tools keep working while the actual data lives on `B:`.

## ❓ Why this exists

Because I have OCD.  
Because I got tired of rewriting the same stuff on every machine.  
Because if I didn’t put this somewhere, I’d go feral.

---

That’s it! Have fun — `pwsh-fun` 😎  
*(P.S. Yes, I know this README is cringe. I’m leaning into it.)*
