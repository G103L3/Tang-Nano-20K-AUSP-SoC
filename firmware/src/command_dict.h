#ifndef COMMAND_DICT_H
#define COMMAND_DICT_H

typedef enum {
    CMD_UNKNOWN = 0,
    CMD_REQ,
    CMD_SET,
    CMD_OK,
    CMD_MOVEMENT,
    CMD_ABORT,
    CMD_EXT
} Command;

Command     command_from_string(const char *s);
const char *command_to_string(Command cmd);

#endif
