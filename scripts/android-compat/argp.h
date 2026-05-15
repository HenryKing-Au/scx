/* Minimal GNU argp.h for cross-building elfutils on Android. */
#ifndef SCX_ANDROID_ARGP_H
#define SCX_ANDROID_ARGP_H

#include <stdio.h>
#include <errno.h>

#ifndef __error_t_defined
#define __error_t_defined 1
typedef int error_t;
#endif

struct argp_option {
  const char *name;
  int key;
  const char *arg;
  int flags;
  const char *doc;
  int group;
};

struct argp_state {
  void *input;
  void *hook;
  char *name;
  char **argv;
  int argc;
  int err_stream;
};

struct argp_child {
  const struct argp *argp;
  int group;
};

typedef error_t (*argp_parser_t)(int key, char *arg, struct argp_state *state);

struct argp {
  const struct argp_option *options;
  argp_parser_t parser;
  const char *args_doc;
  const char *doc;
  const struct argp_child *children;
  char *(*help_filter)(int key, const char *text, void *input);
  const char *argp_domain;
};

#define OPTION_ARG_OPTIONAL 0x1
#define OPTION_HIDDEN 0x2
#define OPTION_ALIAS 0x4
#define OPTION_DOC 0x8
#define OPTION_NO_USAGE 0x10

#define ARGP_KEY_ARG 0x100001
#define ARGP_KEY_END 0x100002
#define ARGP_KEY_SUCCESS 0x100003
#define ARGP_KEY_ERROR 0x100004

#define ARGP_NO_ARGS 0x1
#define ARGP_NO_ERRS 0x2
#define ARGP_IN_ORDER 0x4
#define ARGP_NO_HELP 0x8
#define ARGP_HELP_FMT_MASK 0x3f00
#define ARGP_HELP_FMT 0x100
#define ARGP_HELP_SEE 0x200
#define ARGP_HELP_LONG 0x400
#define ARGP_HELP_SHORT 0x800
#define ARGP_HELP_USAGE 0x1000
#define ARGP_HELP_PRE_DOC 0x2000
#define ARGP_HELP_POST_DOC 0x4000
#define ARGP_HELP_HEADER 0x8000
#define ARGP_HELP_EXIT_OK 0x10000
#define ARGP_HELP_EXIT_ERR 0x20000

#define ARGP_PARSE_NO_EXIT 0x1
#define ARGP_PARSE_ARGV0 0x2

#define ARGP_ERR_UNKNOWN EINVAL

extern char *program_invocation_short_name;
extern error_t argp_parse(const struct argp *argp, int argc, char **argv,
                          unsigned flags, int *arg_index, void *input);
extern void argp_help(const struct argp *argp, FILE *stream, unsigned flags,
                      char *name);
extern void (*const argp_program_version_hook)(FILE *, struct argp_state *);
extern const char *const argp_program_bug_address;

#endif /* SCX_ANDROID_ARGP_H */
