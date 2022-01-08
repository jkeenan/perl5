#!/usr/bin/env perl
use 5.14.0;
use warnings;
#use Data::Dump ( qw| dd pp| );
#use Carp;
use Cwd;
use Data::Dumper;$Data::Dumper::Indent=1;
use File::Find;
use File::Spec;

#my $dir = $ENV{PERL_WORKDIR};
#chdir $dir or croak "Unable to chdir to git checkout of Perl 5";

# TODO: Check that we're in the top-level directory of the core distribution

my $dir = cwd();
my $maint_file = File::Spec->catfile($dir, 'Porting', 'Maintainers.pl');
require $maint_file;
#dd( { %Maintainers::Modules } );

my $manilib_file = File::Spec->catfile($dir, 'Porting', 'manifest_lib.pl');
require $manilib_file; # to get function sort_manifest()

my %distmodules = ();
for my $m (keys %Maintainers::Modules) {
    if ($Maintainers::Modules{$m}{FILES} =~ m{dist/}) {
        $distmodules{$m} = $Maintainers::Modules{$m};
    }
}
#dd( { %distmodules } );
say "Located ", scalar keys %distmodules, " 'dist/' entries in \%Maintainers::Modules";

my %makefile_pl_status = ();
for my $m (keys %distmodules) {
    if (! exists $distmodules{$m}{DISTRIBUTION}) {
        $makefile_pl_status{$m} = 'unreleased';
    }
}
#say "Are these modules unreleased to CPAN?";
#say $_ for sort keys %unreleased;
#say '';
#dd(\%makefile_pl_status);
my ($current_count, $last_count);
$current_count = $last_count = scalar keys %makefile_pl_status;

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
#dd(\%makefile_pl_status);
$current_count = scalar keys %makefile_pl_status;
my $native_count = $current_count - $last_count;
say "$native_count 'dist/' distros have native Makefile.PLs";
$last_count = $current_count;

find(\&get_generated_makefiles, ( "$dir/dist" ));

#dd(\%makefile_pl_status);
$current_count = scalar keys %makefile_pl_status;
my $generated_count = $current_count - $last_count;
say "$generated_count 'dist/' distros have Makefile.PLs generated during Perl 5 'make'";
$last_count = $current_count;

# I now need to complete population of %makefile_pl_status with KVPs for those
# distros whose Makefile.PL must be obtained from CPAN.

for my $d (sort keys %distmodules) {
    next unless exists $distmodules{$d}{FILES};
    # pattern below can be simplified once
    # https://github.com/Perl/perl5/pull/19336 is accepted
    my ($distname) = $distmodules{$d}{FILES} =~ m{^dist/(.*)/?$};
    if (! exists $makefile_pl_status{$distname}) {
        $makefile_pl_status{$distname} = 'cpan';
    }
}
#dd(\%makefile_pl_status);
$current_count = scalar keys %makefile_pl_status;
my $cpan_count = $current_count - $last_count;
say "$cpan_count 'dist/' distros (presumably) get their Makefile.PLs from CPAN";
$last_count = $current_count;


say "Finished!";

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
