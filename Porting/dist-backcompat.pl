#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Cwd;
use File::Find;
use File::Spec;
#use Data::Dump qw( dd pp );

# TODO: Check that we're in the top-level directory of the core distribution

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
say "Located ", scalar keys %distmodules, " 'dist/' entries in \%Maintainers::Modules";

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
for my $k (sort keys %counts) {
    printf "%-20s%4s\n" => ($k, $counts{$k});
}

say "\nFinished!";

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
