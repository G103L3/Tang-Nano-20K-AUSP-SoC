#!/bin/sh
# ============================================================================
# EFES - genera i VCD (waveform reali) delle testbench dei componenti.
# Eseguire da questa cartella:   sh run.sh
# Poi aprire i .vcd in GTKWave:  gtkwave tb_pwm.vcd
#
# GHDL mette in VCD TUTTI i segnali della gerarchia (anche gli interni dell'unita'
# sotto test: in GTKWave compaiono sotto tb_xxx -> uut -> ...).
# ============================================================================
set -e
cd "$(dirname "$0")"

STD="--std=08 --mb-comments"
SRC=../src

# libreria di lavoro pulita ad ogni run
rm -f work-obj08.cf

run() {            # $1 = entita' testbench, $2.. = file VHDL del componente
    tb="$1"; shift
    echo "=== $tb ==="
    ghdl -a $STD "$@" "$tb.vhd"
    ghdl -e $STD "$tb"
    ghdl -r $STD "$tb" --vcd="$tb.vcd" --stop-time=20ms
    echo "  -> $tb.vcd"
}

run tb_pwm        "$SRC/pwm_generic_master.vhd"
run tb_uart       "$SRC/uart_generic.vhd"
run tb_spi_adc    "$SRC/spi_master.vhd"
run tb_flash_spi  "$SRC/flash_spi.vhd"
run tb_sdram      sdram_sip_model.vhd          # RAM: modello SIP comportamentale (locale)

echo ""
echo "Fatto. VCD generati. Esempio:  gtkwave tb_pwm.vcd"
