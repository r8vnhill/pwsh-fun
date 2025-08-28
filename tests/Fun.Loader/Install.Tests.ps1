#Requires -Version 7.0
Set-StrictMode -Version Latest
Import-Module Pester -ErrorAction Stop

BeforeAll {
  . "$PSScriptRoot/../../path/to/your/code/under/test.ps1"
  $alpha = [FunModuleRef]::new('Alpha','C:\Mods\Alpha\Alpha.psd1',[ModuleKind]::Manifest)
  $beta  = [FunModuleRef]::new('Beta','C:\Mods\Beta\Beta.psm1',[ModuleKind]::Script)
  Set-Variable Alpha -Scope Script -Value $alpha
  Set-Variable Beta  -Scope Script -Value $beta
}

Describe 'Install-FunModules (pipeline input)' {
  BeforeEach {
    Mock -CommandName Import-Module -Verifiable -MockWith {
      # Simulate a real module object with Version
      [pscustomobject]@{ Version = [version]'1.0.0' }
    }
  }

  It 'imports each module and returns results' {
    $res = @($Alpha,$Beta) | Install-FunModules -Scope Local -Confirm:$false
    Assert-MockCalled Import-Module -Times 2 -Exactly
    $res | Should -All -BeOfType FunModuleImportResult
    ($res | Where-Object Name -eq 'Alpha').Status | Should -Be 'Imported'
  }

  It 'honors -WhatIf (no Import-Module calls)' {
    @($Alpha,$Beta) | Install-FunModules -WhatIf -Confirm:$false | Out-Null
    Assert-MockCalled Import-Module -Times 0 -Exactly
  }
}

Describe 'Install-FunModules (self-discovery + error path)' {
  BeforeEach {
    # Mock discovery to yield one good and one failing module
    Mock -CommandName Get-FunModuleFiles -Verifiable -MockWith {
      @(
        [FunModuleRef]::new('Good','C:\Mods\Good\Good.psd1',[ModuleKind]::Manifest),
        [FunModuleRef]::new('Bad','C:\Mods\Bad\Bad.psm1',[ModuleKind]::Script)
      )
    }

    Mock -CommandName Import-Module -Verifiable -MockWith {
      param([string]$LiteralPath)
      if ($LiteralPath -like '*Bad.psm1') { throw "boom" }
      [pscustomobject]@{ Version = [version]'2.3.4' }
    }
  }

  It 'returns Imported and Failed statuses accordingly' {
    $res = Install-FunModules -Scope Local -Confirm:$false
    Assert-MockCalled Get-FunModuleFiles -Times 1 -Exactly
    Assert-MockCalled Import-Module     -Times 2

    ($res | Where-Object Name -eq 'Good').Status | Should -Be 'Imported'
    ($res | Where-Object Name -eq 'Bad').Status  | Should -Be 'Failed'
    ($res | Where-Object Name -eq 'Good').Version | Should -Be ([version]'2.3.4')
  }
}
