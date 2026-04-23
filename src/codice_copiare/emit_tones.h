/*! \file emit_tones.h
 * \author Gioele Giunta
 * \version 2.3
 * \since 2025
 * \brief Interfaccia del modulo emit tones
 */

#ifndef EMIT_TONES_H
#define EMIT_TONES_H
/* Librerie */
#include <stdbool.h>
#include <stddef.h>

/* Headers specifici */
#include "global_parameters.h"  // Presumibilmente definisce 'role' e altri parametri condivisi

#ifdef __cplusplus
extern "C" {
#endif


/* Includi solo ciò che è strettamente necessario */

/* Forward declaration della funzione principale */
bool emit_tones(const struct_out_tones *pairs, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* EMIT_TONES_H */
