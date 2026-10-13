#!./perl
$|=1;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
}
use strict;
use warnings;
plan(tests =>   5);
use Tie::Array; # we need to test sorting tied arrays

##### goto #####

my (@output, $fail_msg);

eval { @output = sort {goto sub {}} 1,2; };
$fail_msg = q(Can't goto subroutine outside a subroutine);
cmp_ok(substr($@,0,length($fail_msg)),'eq',$fail_msg,'goto subr outside subr');

sub goto_sub {goto sub{}}
eval { @output = sort goto_sub 1,2; };
$fail_msg = q(Can't goto subroutine from a sort sub);
cmp_ok(substr($@,0,length($fail_msg)),'eq',$fail_msg,'goto subr from a sort sub');

eval { @output = sort {goto label} 1,2; };
$fail_msg = q(Can't "goto" out of a pseudo block);
cmp_ok(substr($@,0,length($fail_msg)),'eq',$fail_msg,'goto out of a pseudo block 1');

sub goto_label {goto label}
label: eval { @output = sort goto_label 1,2; };
$fail_msg = q(Can't "goto" out of a pseudo block);
cmp_ok(substr($@,0,length($fail_msg)),'eq',$fail_msg,'goto out of a pseudo block 2');

sub self_immolate {undef &self_immolate; $a<=>$b}
eval { @output = sort self_immolate 1,2,3 };
$fail_msg = q(Can't undef active subroutine);
cmp_ok(substr($@,0,length($fail_msg)),'eq',$fail_msg,'undef active subr');

