# ==========================================
# Setup simulazione GHDL per Windows
# ==========================================
Write-Host "=== Setup simulazione GHDL ===" -ForegroundColor Cyan

$ProfilesFile = ".ghdl_profiles.json"
$OldConfigFile = ".ghdl_sim.json"

# ===============================
# Migrazione da vecchio formato
# ===============================
if ((Test-Path $OldConfigFile) -and -not (Test-Path $ProfilesFile)) {
    Write-Host "Migrazione configurazione precedente..." -ForegroundColor Yellow
    $oldConfig = Get-Content $OldConfigFile | ConvertFrom-Json
    $oldConfig | Add-Member -NotePropertyName "name" -NotePropertyValue "Profilo default" -Force
    $oldConfig | Add-Member -NotePropertyName "vaporview_config" -NotePropertyValue $null -Force
    @($oldConfig) | ConvertTo-Json -Depth 20 | Set-Content $ProfilesFile
    Write-Host "Profilo esistente migrato come 'Profilo default'." -ForegroundColor Green
}

# ===============================
# Caricamento profili
# ===============================
$profiles = @()
if (Test-Path $ProfilesFile) {
    $loaded = Get-Content $ProfilesFile | ConvertFrom-Json
    if ($loaded -is [array]) { $profiles = $loaded } else { $profiles = @($loaded) }
}

$profileIndex = -1
$main_file = $null
$tb_file = $null
$tb_entity = $null
$extra_files = @()

if ($profiles.Count -gt 0) {
    Write-Host "`nProfili disponibili:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        Write-Host "  $($i + 1). $($profiles[$i].name)  [main: $($profiles[$i].main_file), tb: $($profiles[$i].tb_entity)]"
    }
    Write-Host "  $($profiles.Count + 1). Crea nuovo profilo" -ForegroundColor Cyan

    do {
        $choice = Read-Host "Seleziona un profilo (1-$($profiles.Count + 1))"
        $choiceNum = 0
        $valid = [int]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 1 -and $choiceNum -le ($profiles.Count + 1)
        if (-not $valid) { Write-Host "Scelta non valida, riprova." -ForegroundColor Red }
    } while (-not $valid)

    if ($choiceNum -le $profiles.Count) {
        $profileIndex = $choiceNum - 1
        $main_file   = $profiles[$profileIndex].main_file
        $tb_file     = $profiles[$profileIndex].tb_file
        $tb_entity   = $profiles[$profileIndex].tb_entity
        $extra_files = if ($profiles[$profileIndex].extra_files) { @($profiles[$profileIndex].extra_files) } else { @() }
        Write-Host "Profilo '$($profiles[$profileIndex].name)' caricato." -ForegroundColor Green
    }
}

# ===============================
# Input dati nuovo profilo
# ===============================
if ($profileIndex -eq -1) {
    $profileName = Read-Host "Nome profilo"
    if (-not $profileName) { Write-Host "Errore: nome profilo non valido." -ForegroundColor Red; exit 1 }

    $main_file = Read-Host "Nome file principale da analizzare (senza .vhd, es. spi_master)"
    if (-not $main_file) { Write-Host "Errore: nome file non valido." -ForegroundColor Red; exit 1 }

    $tb_file = Read-Host "Nome testbench (senza .vhd)"
    if (-not $tb_file) { Write-Host "Errore: nome testbench non valido." -ForegroundColor Red; exit 1 }

    $tb_entity = Read-Host "Nome entita del testbench"
    if (-not $tb_entity) { Write-Host "Errore: nome entita non valido." -ForegroundColor Red; exit 1 }

    $extra_files = @()
    $use_extra = Read-Host "Si usano altri file da compilare? (y/n)"
    if ($use_extra -eq "y") {
        Write-Host "Inserisci i file supplementari (senza .vhd)."
        Write-Host "Puoi usare anche percorsi per sottocartelle (es. gowin_picorv32/gowin_picorv32)."
        Write-Host "Scrivi '.' per terminare." -ForegroundColor Yellow
        while ($true) {
            $extra = Read-Host ">"
            if ($extra -eq ".") { break }
            elseif (-not [string]::IsNullOrWhiteSpace($extra)) { $extra_files += $extra }
        }
    }

    $newProfile = [PSCustomObject]@{
        name             = $profileName
        main_file        = $main_file
        tb_file          = $tb_file
        tb_entity        = $tb_entity
        extra_files      = $extra_files
        vaporview_config = $null
    }
    $profiles += $newProfile
    $profileIndex = $profiles.Count - 1
}

# ===============================
# Salva config VaporView prima di cancellare output
# ===============================
$vaporviewFile = "output/tb_output_${main_file}.json"
if (Test-Path $vaporviewFile) {
    $vvConfig = Get-Content $vaporviewFile -Raw | ConvertFrom-Json
    $profiles[$profileIndex] | Add-Member -NotePropertyName "vaporview_config" -NotePropertyValue $vvConfig -Force
    Write-Host "Configurazione VaporView salvata nel profilo." -ForegroundColor Green
}

# Salva profili (include eventuale nuovo profilo o vaporview aggiornato)
$profiles | ConvertTo-Json -Depth 20 | Set-Content $ProfilesFile
Write-Host "Profilo salvato in $ProfilesFile" -ForegroundColor Green

# ===============================
# Preparazione output
# ===============================
if (Test-Path "output") { Remove-Item -Recurse -Force "output" }
New-Item -ItemType Directory -Force -Path "output" | Out-Null

# ===============================
# Analisi VHDL
# ===============================
Write-Host "`nAnalisi file supplementari..." -ForegroundColor Cyan
foreach ($f in $extra_files) {
    Write-Host "  - $f.vhd"
    & "C:\GHDL\bin\ghdl.exe" -a --std=08 "$f.vhd"
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host "Analisi file principale ($main_file.vhd)..." -ForegroundColor Cyan
& "C:\GHDL\bin\ghdl.exe" -a --std=08 "$main_file.vhd"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Analisi testbench ($tb_file.vhd)..." -ForegroundColor Cyan
& "C:\GHDL\bin\ghdl.exe" -a --std=08 "$tb_file.vhd"
if ($LASTEXITCODE -ne 0) { exit 1 }

# ===============================
# Elaborazione ed esecuzione
# ===============================
Write-Host "Elaborazione entita $tb_entity..." -ForegroundColor Cyan
& "C:\GHDL\bin\ghdl.exe" -e --std=08 "$tb_entity"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Esecuzione simulazione..." -ForegroundColor Cyan
& "C:\GHDL\bin\ghdl.exe" -r --std=08 "$tb_entity" --wave="output/tb_output_${main_file}.ghw"

# ===============================
# Ripristino configurazione VaporView
# ===============================
$savedVV = $profiles[$profileIndex].vaporview_config
if ($savedVV) {
    $ghwAbsPath = "$PWD\output\tb_output_${main_file}.ghw"
    $savedVV | Add-Member -NotePropertyName "fileName" -NotePropertyValue $ghwAbsPath -Force
    $savedVV | ConvertTo-Json -Depth 20 | Set-Content "output/tb_output_${main_file}.json"
    Write-Host "Configurazione VaporView ripristinata." -ForegroundColor Green
    & code "$PWD/output/tb_output_${main_file}.json"
} else {
    & code "$PWD/output/tb_output_${main_file}.ghw"
}

# ===============================
# Pulizia file temporanei
# ===============================
Write-Host "Pulizia file temporanei..." -ForegroundColor Cyan

if (Test-Path "$tb_entity.exe") { Remove-Item "$tb_entity.exe" -ErrorAction SilentlyContinue }
if (Test-Path "$main_file.o")   { Remove-Item "$main_file.o"   -ErrorAction SilentlyContinue }
if (Test-Path "$tb_file.o")     { Remove-Item "$tb_file.o"     -ErrorAction SilentlyContinue }

foreach ($f in $extra_files) {
    $objName = Split-Path $f -Leaf
    if (Test-Path "$objName.o") { Remove-Item "$objName.o" -ErrorAction SilentlyContinue }
}

Write-Host "=== Simulazione completata ===" -ForegroundColor Green
Write-Host "Output salvato in ./output/tb_output_${main_file}.ghw"
