/*! \file command_dict.c
 * \author Gioele Giunta
 * \version 2.4
 * \since 2025
 * \brief Implementazione del modulo command dict
 */

/* Librerie */
#include <string.h>

/* Headers specifici */
#include "command_dict.h"

typedef struct {
    const char *name;
    Command cmd;
} CmdEntry;

static const CmdEntry dict[] = {
    {"REQ", CMD_REQ},
    {"SET", CMD_SET},
    {"OK",  CMD_OK},
    {"MOVEMENT", CMD_MOVEMENT},
    {"ABORT", CMD_ABORT},
    {"EXT", CMD_EXT},
    {NULL,   CMD_UNKNOWN}
};
/**
 * @brief Funzione command_from_string.
 * @param s Parametro s.
 * @return Valore di ritorno.
 */

Command command_from_string(const char *s){
    for(const CmdEntry *e = dict; e->name; ++e){
        if(strcmp(e->name, s) == 0)
            return e->cmd;
    }
    return CMD_UNKNOWN;
}
/**
 * @brief Funzione command_to_string.
 * @param cmd Parametro cmd.
 * @return Valore di ritorno.
 */

const char* command_to_string(Command cmd){
    for(const CmdEntry *e = dict; e->name; ++e){
        if(e->cmd == cmd)
            return e->name;
    }
    return "UNKNOWN";
}
