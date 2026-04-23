/*! \file decoder.c
 * \author Gioele Giunta
 * \version 1.9
 * \since 2025
 * \brief Implementazione del modulo decoder
 */

/* Headers specifici */
#include "decoder.h"
#include "string.h"
#include "leds.h"

#ifdef __cplusplus
extern "C" {
#endif


/* Calcola il rumore medio dello spettro per stabilire soglie dinamiche */
/**
 * @brief Funzione estimate_noise_floor.
 * @param data Parametro data.
 * @param size Parametro size.
 * @return Valore di ritorno.
 */
double estimate_noise_floor(complex_g3_t *data, int size) {
    double sum = 0.0;
    for (int i = 0; i < size; i++) {
        sum += complex_magnitude(data[i]);
    }
    return sum / (double)size;
}

/*Test */
double sum_bins = 0, sum_amp = 0, sum_bins2 = 0, sum_bins_amp = 0, slope = 0, intercept = 0;
int regress_count = 0;


double const T = 1.0 / FS;  /* Sampling interval */

/* AUSP FREQUENCIES */
int ausp_freq[] = {
        /* Prima riga: MASTER_BASE */
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
    
        /* Seconda riga: SLAVE usa le stesse frequenze del master con portante a 9000 Hz */
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
    
        /* Terza riga: CONFIG usa le stesse frequenze del master ma con portante a 8600 Hz */
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
    
double const freq_tolerance = (double)G_SAMPLE_RATE/(double)G_ARRAY_SIZE; /* Frequency tolerance due to FFT resolution */

void serial_init(unsigned long baudrate);
void serial_write_char(char c);
void serial_write_string(const char* str);
void serial_write_formatted(const char* format, ...);

struct_interpolated_frequency check_active_frequencies(complex_g3_t *data, int  bin_1, int bin_2, int id, double noise_floor);
struct_interpolated_frequency interpolate_peak_frequency(complex_g3_t *data, int peak_bin, double sample_rate, int fft_size);




/*! \fn struct_tone_frequencies decode_ausp(complex_g3_t *data)
 * \param data Array of complex numbers representing the FFT output
 * \returns A struct_tone_frequencies containing the decoded frequencies
 * \brief Decodes the AUSP frequencies from the FFT output
 * 
 * This function checks for specific frequencies in the FFT output and returns a struct_tone_frequencies
 * containing the detected frequencies for master, slave, and configuration.
 */
/**
 * @brief Funzione decode_ausp.
 * @param data Parametro data.
 * @return Valore di ritorno.
 */
struct_tone_frequencies decode_ausp(complex_g3_t *data) 
{
	struct_tone_frequencies decoded_tones;
	serial_init(115200);
	int results_[3][3] = 
	{
		{0, 0, 0},
		{0, 0, 0},
		{0, 0, 0}
	};

        turn_off();

        double noise_floor = estimate_noise_floor(data, NN);

        for (int i = 0; i < sizeof(ausp_freq)/sizeof(int); i++) {
                int range_start = floor(ausp_freq[i]/(freq_tolerance));
                int range_end = range_start+1;
                struct_interpolated_frequency frequencies = check_active_frequencies(data, range_start, range_end, i, noise_floor);
                if(frequencies.work){
                        serial_write_formatted("Debug: Freq: %f Amp: %f Threshold: %f\n", frequencies.frequency, frequencies.estimated_amplitude, frequencies.dynamic_amplitude_threshold);
                        if ((fabs(frequencies.frequency - ausp_freq[i]) <= freq_tolerance) && (frequencies.estimated_amplitude > frequencies.dynamic_amplitude_threshold)) {
                                int row = (i/ROW_LEN);
                                int column;
                                int l = i % ROW_LEN;
                                if(l >= 0 && l <= 8){column = 0;}
/**
 * @brief Funzione if.
 * @param 17 Parametro 17.
 * @return Valore di ritorno.
 */
                                else if(l >= 9 && l <= 17){column = 2;}
/**
 * @brief Funzione if.
 * @param 18 Parametro 18.
 * @return Valore di ritorno.
 */
                                else if(l == 18){column = 1;}
                                if(row < 3 && column < 3) {
                                        results_[row][column] = ausp_freq[i];
                                }
                                turn_blue(1);
                                serial_write_formatted("Debug: freq %f amp: %f \n", frequencies.frequency, frequencies.estimated_amplitude);
                        } else {
                                turn_red(1);
                                int row = i / ROW_LEN;
                                int column;
                                int l = i % ROW_LEN;
                                if(l >= 0 && l <= 8){column = 0;}
/**
 * @brief Funzione if.
 * @param 17 Parametro 17.
 * @return Valore di ritorno.
 */
                                else if(l >= 9 && l <= 17){column = 2;}
/**
 * @brief Funzione if.
 * @param 18 Parametro 18.
 * @return Valore di ritorno.
 */
                                else if(l == 18){column = 1;}
                                if(row < 3 && column < 3) {
                                        results_[row][column] = -1;
                                }
                        }
                }
        }

	memcpy(decoded_tones.master, results_[0], 3 * sizeof(int));
	memcpy(decoded_tones.slave, results_[1], 3 * sizeof(int));
	memcpy(decoded_tones.configuration, results_[2], 3 * sizeof(int));
	

	return decoded_tones;
}

/*! \struct struct_interpolated_frequency
 * \brief Structure to hold the interpolated frequency and its properties
 * 
 * This structure contains the frequency, estimated amplitude, dynamic amplitude threshold,
 * and a work flag indicating if the frequency was successfully detected.
 */
/**
 * @brief Funzione check_active_frequencies.
 * @param data Parametro data.
 * @param bin_1 Parametro bin_1.
 * @param bin_2 Parametro bin_2.
 * @param id Parametro id.
 * @param noise_floor Parametro noise_floor.
 * @return Valore di ritorno.
 */
struct_interpolated_frequency check_active_frequencies(complex_g3_t *data, int  bin_1, int bin_2, int id, double noise_floor){
        int i, j;
        struct_interpolated_frequency detected_freq;
        detected_freq.work = 0;
        detected_freq.frequency = -1.0;  /* Default value indicating no frequency detected */
        detected_freq.estimated_amplitude = -1.0;  /* Default value indicating no amplitude detected */
        detected_freq.dynamic_amplitude_threshold = -1.0;  /* Default value indicating no threshold detected */
        for (j = bin_1; j <=bin_2; j++)
        {
                double freq = (double)(FS * j) / NN;
                double amp = complex_magnitude(data[j]);
                if(G_LINEAR_REGRESSION_MODE == 0){


                        double dynamic_amplitude_threshold = noise_floor * 8.0;

                        if (amp > dynamic_amplitude_threshold)
                        {
                                serial_write_formatted("Debug: Freq: %f Amplitude: %f  Threshold: %f \n", freq, amp, dynamic_amplitude_threshold);

                                for(i = j-6; i < j + 6 && complex_magnitude(data[i]) <= amp; i++) {
                                }

                                if (i == j+6)
                                {
                                        detected_freq = interpolate_peak_frequency(data, j, FS, NN);
                                        detected_freq.dynamic_amplitude_threshold = dynamic_amplitude_threshold;
                                        detected_freq.work = 1;

                                        serial_write_formatted("Debug: Detected amp: %f diff_freq: %f tolerance: %f threshold: %f\n", detected_freq.estimated_amplitude, fabs(detected_freq.frequency - ausp_freq[id]), freq_tolerance, dynamic_amplitude_threshold);

                                        return detected_freq;

                                }


                        }
                }else if(G_LINEAR_REGRESSION_MODE == 2){
                        regress_linear_update(j, amp);
                }

        }
        return detected_freq;
}

/*! \struct struct_interpolated_frequency
 * \brief Structure to hold the interpolated frequency and its properties
 * 
 * This structure contains the frequency, estimated amplitude, dynamic amplitude threshold,
 * and a work flag indicating if the frequency was successfully detected.
 */
/**
 * @brief Funzione interpolate_peak_frequency.
 * @param data Parametro data.
 * @param peak_bin Parametro peak_bin.
 * @param sample_rate Parametro sample_rate.
 * @param fft_size Parametro fft_size.
 * @return Valore di ritorno.
 */
struct_interpolated_frequency interpolate_peak_frequency(complex_g3_t *data, int peak_bin, double sample_rate, int fft_size) {
    /* Evita di fare interpolazione se il picco è al bordo dello spettro */
    if (peak_bin <= 0 || peak_bin >= fft_size - 1) {
			/*Formattazione del Return */
			struct_interpolated_frequency frequency;
			frequency.frequency = peak_bin * sample_rate / fft_size;
			frequency.estimated_amplitude = complex_magnitude(data[peak_bin]);
        return frequency;
    }
    
    /* Ottieni le ampiezze dei tre bin */
    double alpha = complex_magnitude(data[peak_bin-1]);
    double beta = complex_magnitude(data[peak_bin]);
    double gamma = complex_magnitude(data[peak_bin+1]);

	serial_write_formatted("Debug: Alpha %f Beta %f Gamma %f\n", alpha, beta, gamma);
    
    /* Formula dell'interpolazione parabolica */
    double p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
    
    /* Limita p nell'intervallo [-0.5, 0.5] per evitare risultati anomali */
    if (p < -0.5) p = -0.5;
    if (p > 0.5) p = 0.5;
    
    /* Calcola la frequenza interpolata */
    double interpolated_bin = peak_bin + p;
    double interpolated_freq = interpolated_bin * sample_rate / fft_size;
    
	/* Calcola l'ampiezza interpolata */
	double interpolated_amplitude = beta - 0.25 * (alpha - gamma) * p;

	/*Formattazione del Return */
	struct_interpolated_frequency frequency;
	frequency.frequency = interpolated_freq;
	frequency.estimated_amplitude = interpolated_amplitude;
    return frequency;
}
/**
 * @brief Funzione regress_linear_update.
 * @param bin Parametro bin.
 * @param amplitude Parametro amplitude.
 */


void regress_linear_update(const int bin, const double amplitude) {
    sum_bins += bin;
    sum_amp += amplitude;
    sum_bins2 += bin * bin;
    sum_bins_amp += bin * amplitude;
	regress_count++;
    
    double denominator = regress_count * sum_bins2 - sum_bins * sum_bins;
    if (denominator == 0) {
        serial_write_string("Error: denominator zero, probably all bin values are equal\n");
    }
    
    slope = (regress_count * sum_bins_amp - sum_bins * sum_amp) / denominator;
    intercept = (sum_amp - (slope) * sum_bins) / regress_count;
	serial_write_formatted("Slope: %f  Intercept: %f \n", slope, intercept);
}


#ifdef __cplusplus
}
#endif
