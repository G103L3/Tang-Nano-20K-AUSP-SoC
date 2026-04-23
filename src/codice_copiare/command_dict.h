/*! \file command_dict.h
 * \author Gioele Giunta
 * \version 2.9
 * \since 2025
 * \brief Interfaccia del modulo command dict
 */

#ifndef COMMAND_DICT_H
#define COMMAND_DICT_H
#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CMD_UNKNOWN = 0,
    CMD_REQ,
    CMD_SET,
    CMD_OK,
    CMD_MOVEMENT,
    CMD_ABORT,
    CMD_EXT
} Command;

Command command_from_string(const char *s);
const char* command_to_string(Command cmd);

#ifdef __cplusplus
}
#endif

#endif /* COMMAND_DICT_H */
