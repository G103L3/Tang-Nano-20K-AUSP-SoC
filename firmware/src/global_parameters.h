#ifndef GLOBAL_PARAMETERS_H_
#define GLOBAL_PARAMETERS_H_

#include <stdint.h>
#include <stdbool.h>

#define G_SAMPLE_RATE       48000
#define G_ARRAY_SIZE        512
#define G_WINDOW_SIZE       256
#define G_MAX_AMPLITUDE     4096.0
#define G_SEQUENCE_LENGTH   100
#define G_PI                3.14159265358979323846

#define G_LINEAR_REGRESSION_MODE 0
#define G_TESTING_MODE      0

#define MASTER_BASE         1000
#define SLAVE_BASE          MASTER_BASE
#define CONFIG_BASE         MASTER_BASE
#define SLAVE_CARRIER       9000
#define CONFIG_CARRIER      8600
#define TONE_STEP           400
#define ROW_LEN             19

typedef struct struct_out_tones {
    int tones[2];
} struct_out_tones;

typedef struct struct_tone_frequencies {
    int master[3];
    int slave[3];
    int configuration[3];
} struct_tone_frequencies;

typedef struct struct_tone_bits {
    int master;
    int slave;
    int configuration;
} struct_tone_bits;

#endif
