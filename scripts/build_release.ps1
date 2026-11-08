# ==============================================================================
# GearLease Production Release Build Script (PowerShell)
# Builds obfuscated artifacts with split debug symbol tables
# ==============================================================================

param (
    [ValidateSet("appbundle", "apk", "ipa")]
    [string]$Target = "appbundle",

    [ValidateSet("dev", "staging", "prod")]
    [string]$Flavor = "prod"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  GEARLEASE PRODUCTION RELEASE BUILD PIPELINE" -ForegroundColor Cyan
Write-Host "  Target: $Target | Flavor: $Flavor" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Clean and get dependencies
Write-Host "`n[1/4] Ensuring clean dependency state..." -ForegroundColor Yellow
flutter pub get

# 2. Run Quality Gates: Analyzer & Tests
Write-Host "`n[2/4] Running Quality Gates (Analyzer & Tests)..." -ForegroundColor Yellow
flutter analyze --fatal-infos
flutter test --coverage

# 3. Create Symbol Output Directory
$SymbolsDir = "./build/symbols/$Target/$Flavor"
if (!(Test-Path -Path $SymbolsDir)) {
    New-Item -ItemType Directory -Path $SymbolsDir -Force | Out-Null
}
Write-Host "`n[3/4] Symbols will be preserved in: $SymbolsDir" -ForegroundColor Green

# 4. Execute Obfuscated Build with Split Debug Info
Write-Host "`n[4/4] Building release binary with code obfuscation and symbol splitting..." -ForegroundColor Yellow

$EntryPoint = "lib/main_$Flavor.dart"
if (!(Test-Path -Path $EntryPoint)) {
    $EntryPoint = "lib/main.dart"
}

switch ($Target) {
    "appbundle" {
        flutter build appbundle `
            --release `
            -t $EntryPoint `
            --obfuscate `
            --split-debug-info=$SymbolsDir
    }
    "apk" {
        flutter build apk `
            --release `
            -t $EntryPoint `
            --obfuscate `
            --split-debug-info=$SymbolsDir
    }
    "ipa" {
        flutter build ipa `
            --release `
            -t $EntryPoint `
            --obfuscate `
            --split-debug-info=$SymbolsDir
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "  Debug symbols archived for crash deobfuscation in: $SymbolsDir" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
