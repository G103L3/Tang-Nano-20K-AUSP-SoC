#include "bit_freq_codec.h"

int interpret_bits(int freqs[3]) {
    int count = 0;
    int active[3] = {0};

    for (int i = 0; i < 3; ++i) {
        if (freqs[i] > 0) {
            active[i] = 1;
            count++;
        }
    }

    if (count == 2) {
        if (active[0] && active[1] && !active[2]) {
            if (freqs[0] < MASTER_BASE + (TONE_STEP * 19) && freqs[1] == MASTER_BASE)
                return (freqs[0] - MASTER_BASE) / TONE_STEP;
            if (freqs[0] < SLAVE_BASE + (TONE_STEP * 19) && freqs[1] == SLAVE_CARRIER)
                return (freqs[0] - SLAVE_BASE) / TONE_STEP;
            if (freqs[0] < CONFIG_BASE + (TONE_STEP * 19) && freqs[1] == CONFIG_CARRIER)
                return (freqs[0] - CONFIG_BASE) / TONE_STEP;
        }
        if (!active[0] && active[1] && active[2]) {
            if (freqs[2] < MASTER_BASE + (TONE_STEP * 19) && freqs[1] == MASTER_BASE)
                return (freqs[2] - MASTER_BASE) / TONE_STEP;
            if (freqs[2] < SLAVE_BASE + (TONE_STEP * 19) && freqs[1] == SLAVE_CARRIER)
                return (freqs[2] - SLAVE_BASE) / TONE_STEP;
            if (freqs[2] < CONFIG_BASE + (TONE_STEP * 19) && freqs[1] == CONFIG_CARRIER)
                return (freqs[2] - CONFIG_BASE) / TONE_STEP;
        }
        return -2;
    } else if (count == 3) {
        return -2;
    } else {
        return -3;
    }
}

struct_tone_bits bit_coder(struct_tone_frequencies tones) {
    struct_tone_bits result;
    result.master        = interpret_bits(tones.master);
    result.slave         = interpret_bits(tones.slave);
    result.configuration = interpret_bits(tones.configuration);
    return result;
}

struct_out_tones frequency_coder(int bit, int role) {
    struct_out_tones out_tones;
    out_tones.tones[0] = -1;
    out_tones.tones[1] = -1;
    if (role == 0) {
        out_tones.tones[0] = MASTER_BASE + (bit * TONE_STEP);
        out_tones.tones[1] = MASTER_BASE + (TONE_STEP * 18);
    } else if (role == 1) {
        out_tones.tones[0] = SLAVE_BASE + (bit * TONE_STEP);
        out_tones.tones[1] = SLAVE_CARRIER;
    } else if (role == 2) {
        out_tones.tones[0] = CONFIG_BASE + (bit * TONE_STEP);
        out_tones.tones[1] = CONFIG_CARRIER;
    }
    return out_tones;
}
