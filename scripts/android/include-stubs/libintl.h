/* Minimal gettext stubs for cross-compiling elfutils without libintl on Android.
 * Macros must not introduce top-level commas (would break error(0, 0, _("..."))).
 */
#ifndef SCX_LIBINTL_STUB_H
#define SCX_LIBINTL_STUB_H
#define gettext(Msgid) ((const char *)(Msgid))
#define ngettext(Msgid1, Msgid2, N) \
	((N) == 1 ? ((const char *)(Msgid1)) : ((const char *)(Msgid2)))
#define dgettext(Domain, Msgid) ((const char *)(Msgid))
#define dcgettext(Domain, Msgid, Category) ((const char *)(Msgid))
#define bindtextdomain(Domain, Dirname) ((const char *)(Dirname))
#define textdomain(Domain) ((const char *)(Domain))
#endif
