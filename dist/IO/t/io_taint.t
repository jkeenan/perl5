#!./perl -T

use Config;

BEGIN {
    if ($ENV{PERL_CORE}
        and $Config{'extensions'} !~ /\bIO\b/ && $^O ne 'VMS'
        or not ${^TAINT}) # not ${^TAINT} => perl without taint support
    {
        print "1..0\n";
        exit 0;
    }
}

use strict;
use Test::More (tests => 5);

END { unlink "./__taint__$$" }

use IO::File;
my $x = IO::File->new( "> ./__taint__$$" ) || die("Cannot open ./__taint__$$\n");
print $x "$$\n";
$x->close;

$x = IO::File->new( "< ./__taint__$$" ) || die("Cannot open ./__taint__$$\n");
chop(my $unsafe = <$x>);
eval { kill 0 * $unsafe };
SKIP: {
  skip($^O) if $^O eq 'MSWin32' or $^O eq 'NetWare';
  #print STDERR $@;
  like($@, qr/^Insecure/,
    "Caught 'Insecure dependency ... while running with -T switch' error");
}
$x->close;

# We could have just done a seek on $x, but technically we haven't tested
# seek yet...
$x = IO::File->new( "< ./__taint__$$" ) || die("Cannot open ./__taint__$$\n");
$x->untaint;
ok(!$?, "Calling 'untaint' worked");
chop($unsafe = <$x>);
eval { kill 0 * $unsafe };
unlike($@,qr/^Insecure/, "No 'insecure dependency' error detected");
$x->close;

TODO: {
  todo_skip("Known bug in 5.10.0",2) if $] >= 5.010 and $] < 5.010_001;

  # this will segfault if it fails

  sub PVBM () { 'foo' }
  { my $dummy = index 'foo', PVBM }

  eval { IO::Handle::untaint(PVBM) };
  pass("IO::Handle::untaint(PVBM) worked");

  eval { IO::Handle::untaint(\PVBM) };
  pass("IO::Handle::untaint(\PVBM) worked");
}

exit 0;
