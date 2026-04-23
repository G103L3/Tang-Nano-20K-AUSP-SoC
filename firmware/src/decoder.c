#include "decoder.h"
#include <string.h>

double estimate_noise_floor(complex_g3_t *data, int size) {
    double sum = 0.0;
    for (int i = 0; i < size; i++) {
        sum += complex_magnitude(data[i]);
    }
    return sum / (double)size;
}

static double sum_bins = 0, sum_amp = 0, sum_bins2 = 0, sum_bins_amp = 0;
static double slope = 0, intercept = 0;
static int    regress_count = 0;

static int ausp_freq[] = {
    MASTER_BASE + (0  * TONE_STEP), MASTER_BASE + (1  * TONE_STEP),
    MASTER_BASE + (2  * TONE_STEP), MASTER_BASE + (3  * TONE_STEP),
    MASTER_BASE + (4  * TONE_STEP), MASTER_BASE + (5  * TONE_STEP),
    MASTER_BASE + (6  * TONE_STEP), MASTER_BASE + (7  * TONE_STEP),
    MASTER_BASE + (8  * TONE_STEP), MASTER_BASE + (9  * TONE_STEP),
    MASTER_BASE + (10 * TONE_STEP), MASTER_BASE + (11 * TONE_STEP),
    MASTER_BASE + (12 * TONE_STEP), MASTER_BASE + (13 * TONE_STEP),
    MASTER_BASE + (14 * TONE_STEP), MASTER_BASE + (15 * TONE_STEP),
    MASTER_BASE + (16 * TONE_STEP), MASTER_BASE + (17 * TONE_STEP),
    MASTER_BASE + (18 * TONE_STEP),

    SLAVE_BASE + (0  * TONE_STEP), SLAVE_BASE + (1  * TONE_STEP),
    SLAVE_BASE + (2  * TONE_STEP), SLAVE_BASE + (3  * TONE_STEP),
    SLAVE_BASE + (4  * TONE_STEP), SLAVE_BASE + (5  * TONE_STEP),
    SLAVE_BASE + (6  * TONE_STEP), SLAVE_BASE + (7  * TONE_STEP),
    SLAVE_BASE + (8  * TONE_STEP), SLAVE_BASE + (9  * TONE_STEP),
    SLAVE_BASE + (10 * TONE_STEP), SLAVE_BASE + (11 * TONE_STEP),
    SLAVE_BASE + (12 * TONE_STEP), SLAVE_BASE + (13 * TONE_STEP),
    SLAVE_BASE + (14 * TONE_STEP), SLAVE_BASE + (15 * TONE_STEP),
    SLAVE_BASE + (16 * TONE_STEP), SLAVE_BASE + (17 * TONE_STEP),
    SLAVE_CARRIER,

    CONFIG_BASE + (0  * TONE_STEP), CONFIG_BASE + (1  * TONE_STEP),
    CONFIG_BASE + (2  * TONE_STEP), CONFIG_BASE + (3  * TONE_STEP),
    CONFIG_BASE + (4  * TONE_STEP), CONFIG_BASE + (5  * TONE_STEP),
    CONFIG_BASE + (6  * TONE_STEP), CONFIG_BASE + (7  * TONE_STEP),
    CONFIG_BASE + (8  * TONE_STEP), CONFIG_BASE + (9  * TONE_STEP),
    CONFIG_BASE + (10 * TONE_STEP), CONFIG_BASE + (11 * TONE_STEP),
    CONFIG_BASE + (12 * TONE_STEP), CONFIG_BASE + (13 * TONE_STEP),
    CONFIG_BASE + (14 * TONE_STEP), CONFIG_BASE + (15 * TONE_STEP),
    CONFIG_BASE + (16 * TONE_STEP), CONFIG_BASE + (17 * TONE_STEP),
    CONFIG_CARRIER
};

static double const freq_tolerance = (double)G_SAMPLE_RATE / (double)G_ARRAY_SIZE;

static struct_interpolated_frequency interpolate_peak_frequency(complex_g3_t *data, int peak_bin, double sample_rate, int fft_size) {
    struct_interpolated_frequency frequency;
    if (peak_bin <= 0 || peak_bin >= fft_size - 1) {
        frequency.frequency          = peak_bin * sample_rate / fft_size;
        frequency.estimated_amplitude = complex_magnitude(data[peak_bin]);
        return frequency;
    }
    double alpha = complex_magnitude(data[peak_bin - 1]);
    double beta  = complex_magnitude(data[peak_bin]);
    double gamma = complex_magnitude(data[peak_bin + 1]);
    double p = 0.5 * (alpha - gamma) / (alpha - 2.0 * beta + gamma);
    if (p < -0.5) p = -0.5;
    if (p >  0.5) p =  0.5;
    frequency.frequency           = (peak_bin + p) * sample_rate / fft_size;
    frequency.estimated_amplitude = beta - 0.25 * (alpha - gamma) * p;
    return frequency;
}

struct_interpolated_frequency check_active_frequencies(complex_g3_t *data, int bin_1, int bin_2, int id, double noise_floor) {
    struct_interpolated_frequency detected_freq;
    detected_freq.work                     = 0;
    detected_freq.frequency                = -1.0;
    detected_freq.estimated_amplitude      = -1.0;
    detected_freq.dynamic_amplitude_threshold = -1.0;

    for (int j = bin_1; j <= bin_2; j++) {
        double freq = (double)(FS * j) / NN;
        double amp  = complex_magnitude(data[j]);

        double dynamic_amplitude_threshold = noise_floor * 8.0;

        if (amp > dynamic_amplitude_threshold) {
            int i;
            for (i = j - 6; i < j + 6 && complex_magnitude(data[i]) <= amp; i++) {}
            if (i == j + 6) {
                detected_freq = interpolate_peak_frequency(data, j, FS, NN);
                detected_freq.dynamic_amplitude_threshold = dynamic_amplitude_threshold;
                detected_freq.work = 1;
                return detected_freq;
            }
        }
    }
    (void)freq_tolerance;
    return detected_freq;
}

struct_tone_frequencies decode_ausp(complex_g3_t *data) {
    struct_tone_frequencies decoded_tones;
    int results_[3][3] = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}};

    double noise_floor = estimate_noise_floor(data, NN);

    int n = (int)(sizeof(ausp_freq) / sizeof(int));
    for (int i = 0; i < n; i++) {
        int range_start = (int)floor(ausp_freq[i] / freq_tolerance);
        int range_end   = range_start + 1;
        struct_interpolated_frequency frequencies = check_active_frequencies(data, range_start, range_end, i, noise_floor);
        if (frequencies.work) {
            int row = i / ROW_LEN;
            int l   = i % ROW_LEN;
            int column;
            if (l >= 0 && l <= 8)        column = 0;
            else if (l >= 9 && l <= 17)  column = 2;
            else                          column = 1;

            if (row < 3 && column < 3) {
                if ((fabs(frequencies.frequency - ausp_freq[i]) <= freq_tolerance) &&
                    (frequencies.estimated_amplitude > frequencies.dynamic_amplitude_threshold)) {
                    results_[row][column] = ausp_freq[i];
                } else {
                    results_[row][column] = -1;
                }
            }
        }
    }

    memcpy(decoded_tones.master,        results_[0], 3 * sizeof(int));
    memcpy(decoded_tones.slave,         results_[1], 3 * sizeof(int));
    memcpy(decoded_tones.configuration, results_[2], 3 * sizeof(int));
    return decoded_tones;
}

void regress_linear_update(const int bin, const double amplitude) {
    sum_bins     += bin;
    sum_amp      += amplitude;
    sum_bins2    += bin * bin;
    sum_bins_amp += bin * amplitude;
    regress_count++;
    double denominator = regress_count * sum_bins2 - sum_bins * sum_bins;
    if (denominator == 0.0) return;
    slope     = (regress_count * sum_bins_amp - sum_bins * sum_amp) / denominator;
    intercept = (sum_amp - slope * sum_bins) / regress_count;
}
