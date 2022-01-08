#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Cwd qw(cwd);
use File::Find qw(find);
use File::Spec;
use Getopt::Long qw(GetOptions);
#use Data::Dump qw( dd pp );

# TODO: Check that we're in the top-level directory of the core distribution,
# preferably in a way consistent with other Porting/ programs.
# TODO: Allow for command-line options:
#   * verbose DONE 01/08/2021
#   * distro: repeatable switch specifying individual dist/ distros to be
#   tested; default will be testing all which have a CPAN release (currently,
#   40). BASIC FRAMEWORK DONE 01/08/2021; selections not yet used.

my $verbose = '';
my @distros_requested = ();
GetOptions(
    "verbose"  => \$verbose,
    "distro=s" => \@distros_requested,
) or die "Unable to get command-line options: $!";

#say "AAA: $_" for @distros_requested;
my $dir = cwd();
my $maint_file = File::Spec->catfile($dir, 'Porting', 'Maintainers.pl');
require $maint_file;   # to get %Modules in package Maintainers

my $manilib_file = File::Spec->catfile($dir, 'Porting', 'manifest_lib.pl');
require $manilib_file; # to get function sort_manifest()

my %distmodules = ();
for my $m (keys %Maintainers::Modules) {
    if ($Maintainers::Modules{$m}{FILES} =~ m{dist/}) {
        $distmodules{$m} = $Maintainers::Modules{$m};
    }
}

# Sanity checks; all modules under dist/ should be blead-upstream and have P5P
# as maintainer.
for my $m (keys %distmodules) {
    if ($distmodules{$m}{UPSTREAM} ne 'blead') {
        warn "Distro $m has UPSTREAM other than 'blead'";
    }
    if ($distmodules{$m}{MAINTAINER} ne 'P5P') {
        warn "Distro $m has MAINTAINER other than 'P5P'";
    }
}

#pp(\%distmodules);
say "\nFound ", scalar keys %distmodules, " 'dist/' entries in \%Maintainers::Modules"
    if $verbose;

# Order of Battle:

# First, identify any dist/ distros which appear not to have current releases
# on CPAN.  We'll call these 'unreleased'.

my %makefile_pl_status = ();

for my $m (keys %distmodules) {
    if (! exists $distmodules{$m}{DISTRIBUTION}) {
        my ($distname) = $distmodules{$m}{FILES} =~ m{^dist/(.*)/?$};
        $makefile_pl_status{$distname} = 'unreleased';
    }
}

# Second, identify those dist/ distros which have their own hard-coded
# Makefile.PLs in the core distribution.  We'll call these 'native'.

my $manifest = File::Spec->catfile($dir, 'MANIFEST');
my @sorted = read_manifest($manifest);

for my $f (@sorted) {
    next unless $f =~ m{^dist/};
    my $path = (split /\t+/, $f)[0];
    if ($path =~ m{/(.*?)/Makefile\.PL$}) {
        my $distro = $1;
        $makefile_pl_status{$distro} = 'native'
            unless exists $makefile_pl_status{$distro};
    }
}

# Third, identify those dist/ distros whose Makefile.PL is generated during
# Perl's own 'make' process.

find(\&get_generated_makefiles, ( "$dir/dist" ));

# Fourth, identify those dist/ distros whose Makefile.PLs must presumably be
# obtained from CPAN.

for my $d (sort keys %distmodules) {
    next unless exists $distmodules{$d}{FILES};
    # pattern below can be simplified once
    # https://github.com/Perl/perl5/pull/19336 is accepted
    my ($distname) = $distmodules{$d}{FILES} =~ m{^dist/(.*)/?$};
    if (! exists $makefile_pl_status{$distname}) {
        $makefile_pl_status{$distname} = 'cpan';
    }
}

#pp(\%makefile_pl_status);
my %counts;
for my $module (sort keys %makefile_pl_status) {
    $counts{$makefile_pl_status{$module}}++;
}
if ($verbose) {
    say '';
    for my $k (sort keys %counts) {
        printf "%-20s%4s\n" => ($k, $counts{$k});
    }
    say '';
    printf "%-40s%-12s\n" => ('Distribution', 'Status');
    printf "%-40s%-12s\n" => ('------------', '------');
    for my $module (sort keys %makefile_pl_status) {
        printf "%-40s%-12s\n" => ($module, $makefile_pl_status{$module});
    }
}

# TODO:  The balance of this will have to be tested on Dromedary in order to
# have access to the older perl executables compile by Tux.
#
# OUTER_LOOP: Loop over all the modules listed by keys in %makefile_pl_status,
# or in only those modules requested on command-line and stored in
# %distros_requested.  Construct a CPAN-style distribution for each, getting
# an appropriate Makefile.PL as needed from source, built source or CPAN, and
# adding files in the EXCLUDED list by getting them from CPAN.
#
# INNER_LOOP: Loop over the list of older perl executables.  Call 'thisperl
# Makefile.PL; make; make test' on the current distro, noting failures at any
# stage.

if ($ENV{HOSTNAME} eq 'dromedary.p5h.org') {
    my $drompath = '/media/Tux/perls/bin';
    my @perls = ( qw|
        perl5.6
        perl5.8
        perl5.10
        perl5.12
        perl5.14
        perl5.16
        perl5.18
        perl5.20
        perl5.22
        perl5.24
        perl5.26
        perl5.28
        perl5.30
        perl5.32
        perl5.34.0
    | );
    for my $p (@perls) {
        my $path_to_perl = File::Spec->catfile($drompath, $p);
        warn "Could not locate $path_to_perl" unless -e $path_to_perl;
        my $rv = system(qq| $path_to_perl -v 1>/dev/null 2>&1 |);
        warn "Could not execute perl -v with $path_to_perl" if $rv;
    }
}

say "\nFinished!" if $verbose;

##### SUBROUTINES #####

sub get_generated_makefiles {
    if ( $File::Find::name =~ m{^$dir/dist/(.*?)/Makefile\.PL$} ) {
        my $distro = $1;
        if (! exists $makefile_pl_status{$distro}) {
            $makefile_pl_status{$distro} = 'generated';
        }
    }
}

sub read_manifest {
    my $manifest = shift;
    open(my $IN, '<', $manifest) or die("Can't read '$manifest': $!");
    my @manifest = <$IN>;
    close($IN) or die($!);
    chomp(@manifest);
    
    my %seen= ( '' => 1 ); # filter out blank lines
    return grep { !$seen{$_}++ } sort_manifest(@manifest);
}
