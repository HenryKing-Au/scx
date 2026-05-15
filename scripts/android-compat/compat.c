/* Stubs for elfutils on Android (bionic lacks GNU argp/obstack). */
#include "argp.h"
#include <errno.h>

char *program_invocation_short_name = "elfutils";

error_t argp_parse(const struct argp *argp, int argc, char **argv, unsigned flags,
                   int *arg_index, void *input) {
  (void)argp;
  (void)argc;
  (void)argv;
  (void)flags;
  (void)arg_index;
  (void)input;
  return 0;
}

void argp_help(const struct argp *argp, FILE *stream, unsigned flags, char *name) {
  (void)argp;
  (void)stream;
  (void)flags;
  (void)name;
}

void _obstack_free(void) {}
