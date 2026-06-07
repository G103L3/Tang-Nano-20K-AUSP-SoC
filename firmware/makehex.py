#!/usr/bin/env python3
# Converte firmware.bin nel formato ram32.hex per l'ITCM del Gowin PicoRV32:
# una parola da 32 bit (little-endian) per riga, 8 cifre esadecimali, padding a NWORDS.
import sys
binfile = sys.argv[1] if len(sys.argv) > 1 else "firmware.bin"
nwords  = int(sys.argv[2]) if len(sys.argv) > 2 else 8192   # 32 KB / 4
data = open(binfile, "rb").read()
data += b"\x00" * ((4 - len(data) % 4) % 4)                 # allinea a 4
words = len(data)//4
out = []
for i in range(nwords):
    if i < words:
        w = data[4*i] | (data[4*i+1]<<8) | (data[4*i+2]<<16) | (data[4*i+3]<<24)
    else:
        w = 0
    out.append("%08x" % w)
open("ram32.hex","w").write("\n".join(out) + "\n")
print("ram32.hex: %d parole (%d dal firmware, resto 0). Prime righe:" % (nwords, words))
