use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw( refaddr );

*qquote= *Data::Dumper::qquote;

sub StoreData
{
    my $hashref = shift ;
    my $store = shift ;
print STDERR "XXX: ", refaddr($hashref), "\n";

    my (undef, $file, $line) = caller;
print STDERR "SD: $file\n";
    ok 1, "StoreData called from $file, line $line";
    ok ref $store eq 'HASH', "Store Data is a hash reference";
    ok tied %$hashref, "Storing to tied hash";

    while (my ($k, $v) = each %$store) {
        no warnings 'uninitialized';
	#diag "Stored [$k][$v]";
        $$hashref{$k} = $v ;
    }

}

sub VerifyData
{
    my $hashref = shift ;
    my $expected = shift ;
    my %expected = %$expected;
print STDERR "YYY: ", refaddr($hashref), "\n";

    my (undef, $file, $line) = caller;
print STDERR "VD: $file\n";
    ok 1, "VerifyData called from $file, line $line";

    ok ref $expected eq 'HASH', "Expected data is a hash reference";
    ok tied %$hashref, "Verifying a tied hash";

    my %bad = ();
    while (my ($k, $v) = each %$hashref) {
        no warnings 'uninitialized';
        if ($expected{$k} eq $v) {
            #diag "Match " . qquote($k) . " => " . qquote($v);
            delete $expected{$k} ;
        }
        else {
            #diag "No Match " . qquote($k) . " => " . qquote($v) . " want " . qquote($expected{$k});
            $bad{$k} = $v;
        }
    }

    if( ! ok(keys(%bad) + keys(%expected) == 0, "Expected == Actual") ) {
        my $bad = "Expected does not match actual\n";
        if (keys %expected ) {
            $bad .="  No Match from Expected:\n" ;
            while (my ($k, $v) = each %expected) {
                $bad .= "\t" . qquote($k) . " => " . qquote($v) . "\n";
            }
        }
        if (keys %bad ) {
            $bad .= "\n  No Match from Actual:\n" ;
            while (my ($k, $v) = each %bad) {
                no warnings 'uninitialized';
                $bad .= "\t" . qquote($k) . " => " . qquote($v) . "\n";
            }
        }
        diag( "${bad}\n" );
    }
}


1;
