# ==========================================
# Setup simulazione GHDL per Windows
# ==========================================
Write-Host "=== Setup simulazione GHDL ===" -ForegroundColor Cyan

$ConfigFile = ".ghdl_sim.json"

# ===============================
# Caricamento configurazione
# ===============================
if (Test-Path $ConfigFile) {
    $use_old = Read-Host "Configurazione precedente trovata. Usarla? (y/n)"
    if ($use_old -eq "y") {
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        $main_file = $config.main_file
        $tb_file = $config.tb_file
        $tb_entity = $config.tb_entity
        $extra_files = $config.extra_files
        Write-Host "Configurazione caricata." -ForegroundColor Green
    } else {
        Remove-Item $ConfigFile -Force
    }
}

# ===============================
# Input dati (solo se non caricati)
# ===============================
if (-not $main_file) {
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
        Write-Host "Puoi usare anche i percorsi se sono in sottocartelle (es. gowin_picorv32/gowin_picorv32)."
        Write-Host "Scrivi '.' per terminare." -ForegroundColor Yellow

        while ($true) {
            $extra = Read-Host ">"
            if ($extra -eq ".") {
                break
            } elseif (-not [string]::IsNullOrWhiteSpace($extra)) {
                $extra_files += $extra
            }
        }
    }

    # ===============================
    # Salvataggio configurazione
    # ===============================
    $configData = @{
        main_file = $main_file
        tb_file = $tb_file
        tb_entity = $tb_entity
        extra_files = $extra_files
    }
    $configData | ConvertTo-Json | Set-Content $ConfigFile
    Write-Host "Configurazione salvata in $ConfigFile" -ForegroundColor Green
}

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
# Pulizia
# ===============================
Write-Host "Pulizia file temporanei..." -ForegroundColor Cyan

# Su Windows GHDL crea file .exe al momento dell'elaborazione dell'entità
if (Test-Path "$tb_entity.exe") { Remove-Item "$tb_entity.exe" -ErrorAction SilentlyContinue }
if (Test-Path "$main_file.o") { Remove-Item "$main_file.o" -ErrorAction SilentlyContinue }
if (Test-Path "$tb_file.o") { Remove-Item "$tb_file.o" -ErrorAction SilentlyContinue }

foreach ($f in $extra_files) {
    # Estrae solo il nome del file se c'è un percorso di mezzo per la pulizia dei .o
    $objName = Split-Path $f -Leaf
    if (Test-Path "$objName.o") { Remove-Item "$objName.o" -ErrorAction SilentlyContinue }
}

Write-Host "=== Simulazione completata ===" -ForegroundColor Green
Write-Host "Output salvato in ./output/tb_output_${main_file}.ghw"