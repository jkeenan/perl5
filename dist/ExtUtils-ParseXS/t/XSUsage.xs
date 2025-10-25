#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Old perls (pre 5.8.9 or so) did not have PERL_UNUSED_ARG in XSUB.h.
 * This is normally covered by ppport.h. */
#ifndef PERL_UNUSED_ARG
#  if defined(lint) && defined(S_SPLINT_S) /* www.splint.org */
#    include <note.h>
#    define PERL_UNUSED_ARG(x) NOTE(ARGUNUSED(x))
#  else
#    define PERL_UNUSED_ARG(x) ((void)x)
#  endif
#endif
#ifndef PERL_UNUSED_VAR
#  define PERL_UNUSED_VAR(x) ((void)x)
#endif

int xsusage_one()       { return 1; } 
int xsusage_two()       { return 2; }
int xsusage_three()     { return 3; }
int xsusage_four()      { return 4; }
int xsusage_five(int i) { PERL_UNUSED_ARG(i); return 5; }
int xsusage_six(int i)  { PERL_UNUSED_ARG(i); return 6; }

MODULE = XSUsage         PACKAGE = XSUsage	PREFIX = xsusage_

PROTOTYPES: DISABLE

int
xsusage_one()

int
xsusage_two()
    ALIAS:
        two_x = 1
        FOO::two = 2
    INIT:
        PERL_UNUSED_VAR(ix);

int
interface_v_i()
    INTERFACE:
        xsusage_three

int
xsusage_four(...)

int
xsusage_five(int i, ...)

int
xsusage_six(int i = 0)


=pod

=head1 TEST OF POD AT END OF XS FILES

This block of Plain Old Documentation, if placed at the end of C<.xs> files,
will generate warnings that can serve as a corpus for debugging
L<GH #23859|https://github.com/Perl/perl5/issues/23859>.

=over 4

=item bullet point

Input: none

Output: some

=back

=cut
