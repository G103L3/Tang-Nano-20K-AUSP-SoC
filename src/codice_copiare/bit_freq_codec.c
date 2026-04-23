/*! \file bit_freq_codec.c
 * \author Gioele Giunta
 * \version 2.5
 * \since 2025
 * \brief Implementazione del modulo bit freq codec
 */

/* Headers specifici */
#include "complex_g3.h"
#include "serial_bridge.h"
#include "leds.h"
#include "bit_freq_codec.h"

#ifdef __cplusplus
extern "C" {
#endif



/*! \fn int interpret_bits(int freqs[3])
 * \param freqs An array of three integers representing the detected frequencies
 * \returns An integer representing the interpreted signal_codes: 0, 1, -2 (error), or -3 (noise)
 * \brief Interprets the detected frequencies and returns the corresponding bit value.
 * 
 * This function checks the presence of specific frequencies in the input array and determines
 * the bit value based on the combination of active frequencies. It also handles error cases
 * such as multitone detection or noise.
 */
/**
 * @brief Funzione interpret_bits.
 * @param freqs[3] Parametro freqs[3].
 * @return Valore di ritorno.
 */
int interpret_bits(int freqs[3]) 
{
    int count = 0;
    int active[3] = {0};

    for (int i = 0; i < 3; ++i) {
        if (freqs[i] > 0) {
            active[i] = 1;
            count++;
        }
    }

    if (count == 2) {
    /*MEMO */
    /* 0 = un 0; 1 = due 0; 2 = tre 0; 3 = quattro 0; 4 = cinque 0; 5 = sei 0; 6 = sette 0; 7 = 14 0; 8 = 21 0 */
    /*10 = un 1; 11 = due 1; 12 = tre 1; 13 = quattro 1; 14 = cinque 1; 15 = sei 1; 16 = sette 1; 17 = 14 1; 18 = 21 1 */
    /*printf("freqs: %d %d %d\n", freqs[0], freqs[1], freqs[2]); */
        if (active[0] && active[1] && !active[2]){ 
            //Frequenza appartenente agli 0, si valuta quanti 0 di seguito
            turn_green(1); 
            if(freqs[0] < MASTER_BASE + (TONE_STEP*19) && freqs[1] == MASTER_BASE){
                return (freqs[0]-MASTER_BASE)/(TONE_STEP);
            }
            if(freqs[0] < SLAVE_BASE + (TONE_STEP*19) && freqs[1] == SLAVE_CARRIER){
                return (freqs[0]-SLAVE_BASE)/(TONE_STEP);
            }
            if(freqs[0] < CONFIG_BASE + (TONE_STEP*19) && freqs[1] == CONFIG_CARRIER){
                return (freqs[0]-CONFIG_BASE)/(TONE_STEP);
            }
        } 
        if (!active[0] && active[1] && active[2]){ 
            //Frequenza ppartenente agli 1, si valuta quanti 1 di seguito
            turn_green(1);  
            if(freqs[2] < MASTER_BASE + (TONE_STEP*19) && freqs[1] == MASTER_BASE){
                return (freqs[2]-MASTER_BASE)/(TONE_STEP);
            }
            if(freqs[2] < SLAVE_BASE + (TONE_STEP*19) && freqs[1] == SLAVE_CARRIER){
                return (freqs[2]-SLAVE_BASE)/(TONE_STEP);
            }
            if(freqs[2] < CONFIG_BASE + (TONE_STEP*19) && freqs[1] == CONFIG_CARRIER){
                return (freqs[2]-CONFIG_BASE)/(TONE_STEP);
            }
        }
        return -2; /* errore logico: f1 + f3 */
    } else if (count == 3) {
        return -2; /* multitone */
    } else {
        return -3; /* noise */
    }
}


/*! \fn struct_tone_bits bit_coder(struct_tone_frequencies tones)
 * \param tones A struct_tone_frequencies object containing the detected frequencies
 * \returns A struct_tone_bits object containing the interpreted signal_codes for master, slave, and configuration
 * \brief Converts the detected frequencies into signal_codes for master, slave, and configuration.
 * 
 * This function interprets the frequencies detected in the DTMF signal and converts them into signal_codes.
 * It uses the interpret_bits function to determine the bit values based on the presence of specific frequencies.
 */
/**
 * @brief Funzione bit_coder.
 * @param tones Parametro tones.
 * @return Valore di ritorno.
 */
struct_tone_bits bit_coder(struct_tone_frequencies tones) 
{
    int master_bit = interpret_bits(tones.master);
    int slave_bit  = interpret_bits(tones.slave);
    int config_bit = interpret_bits(tones.configuration);

    struct_tone_bits result;
    result.master = master_bit;
    result.slave = slave_bit;
    result.configuration = config_bit;
    return result;
}

/*! \fn struct_out_tones frequency_coder(int bit, int role)
 * \param bit An integer representing the bit to be encoded (0 or 1)
 * \param role An integer representing the role (0 for master, 1 for slave, 2 for configuration)
 * \returns A struct_out_tones object containing the encoded frequencies
 * \brief Encodes a bit into specific frequencies based on the role.
 * 
 * This function maps the input bit and role to specific frequency pairs. It returns a struct_out_tones
 * object containing the two frequencies corresponding to the input parameters.
 */
/**
 * @brief Funzione frequency_coder.
 * @param bit Parametro bit.
 * @param role Parametro role.
 * @return Valore di ritorno.
 */
struct_out_tones frequency_coder(int bit, int role){
    struct_out_tones out_tones;
    out_tones.tones[0] = -1;
    out_tones.tones[1] = -1;
    /*MEMO */
    /* 0 = un 0; 1 = due 0; 2 = tre 0; 3 = quattro 0; 4 = cinque 0; 5 = sei 0; 6 = sette 0; 7 = 14 0; 8 = 21 0 */
    /*10 = un 1; 11 = due 1; 12 = tre 1; 13 = quattro 1; 14 = cinque 1; 15 = sei 1; 16 = sette 1; 17 = 14 1; 18 = 21 1 */
    if (role == 0) { /* Master */
        out_tones.tones[0] = MASTER_BASE + (bit * TONE_STEP); /* Frequenza di segnale per il master */
        out_tones.tones[1] = MASTER_BASE + (TONE_STEP * 18); /* 8200 Hz portante master */
    } else if (role == 1) { /* Slave */
        out_tones.tones[0] = SLAVE_BASE + (bit * TONE_STEP); /* Frequenza di segnale per lo slave */
        out_tones.tones[1] = SLAVE_CARRIER; /* 9000 Hz portante slave */
    } else if (role== 2) { /* Configuration */
        out_tones.tones[0] = CONFIG_BASE + (bit * TONE_STEP); /* Frequenza di segnale per il config */
        out_tones.tones[1] = CONFIG_CARRIER; /* 8600 Hz portante config */
    }

    return out_tones;
}


#ifdef __cplusplus
}
#endif
