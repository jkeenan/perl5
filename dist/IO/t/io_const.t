use Config;

BEGIN {
    if($ENV{PERL_CORE}) {
        if ($Config{'extensions'} !~ /\bIO\b/) {
            print "1..0 # Skip: IO extension not compiled\n";
            exit 0;
        }
    }
}

use IO::Handle;
use Test::More tests => 6;

foreach my $const (qw(SEEK_SET SEEK_CUR SEEK_END     _IOFBF    _IOLBF    _IONBF)) {
    no strict 'refs';
    my $d1 = defined(&{"IO::Handle::" . $const}) ? 1 : 0;
    my $v1 = $d1 ? &{"IO::Handle::" . $const}() : undef;
    my $v2 = IO::Handle::constant($const);
    my $d2 = defined($v2);

    ok(! ($d1 != $d2 || ($d1 && ($v1 != $v2))),
        "$const tested okay");
}
