package Testing;
use 5.10.0;
use warnings;
require Exporter;
our $VERSION = 1.26; # Let's keep this same as lib/Pod/Html.pm
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    xconvert
    setup_testing_dir
);
use Cwd;
use Pod::Html;
use Config;
use File::Basename;
use File::Copy;
use File::Path ( qw| make_path | );
use File::Spec::Functions ':ALL';
use File::Temp ( qw| tempdir | );
use Data::Dumper;

*ok = \&Test::More::ok;
*is = \&Test::More::is;

our @no_arg_switches = ( qw|
    flush recurse norecurse
    quiet noquiet verbose noverbose
    index noindex backlink nobacklink
    header noheader poderrors nopoderrors
| );

sub setup_testing_dir {
    my $args = shift;
    die "setup_testing_dir() needs 'startdir' element"
        unless $args->{startdir};
    my $toptempdir = $args->{debug} ? tempdir() : tempdir( CLEANUP => 1 );
    if ($args->{debug}) {
        print STDERR "startdir:   $args->{startdir}\n";
        print STDERR "toptempdir: $toptempdir\n";
    }
    chdir $toptempdir or die "Unable to change to $toptempdir: $!";

    my $ephdir = catdir($toptempdir, 'ext', 'Pod-Html');
    my ($fromdir, $targetdir, @testfiles);

    $fromdir = catdir($ENV{PERL_CORE} ? $args->{startdir} : catdir($args->{startdir}, 'ext', 'Pod-Html'), 't');
    $targetdir = catdir($ephdir, 't');
    make_path($targetdir) or die("Cannot mkdir $targetdir for testing: $!");
    my $pod_glob = catfile($fromdir, '*.pod');
    @testfiles = glob($pod_glob);
    for my $f (@testfiles) {
        copy $f => $targetdir or die "Unable to copy: $!";
    }

    $fromdir = catdir($ENV{PERL_CORE} ? $args->{startdir} : catdir($args->{startdir}, 'ext', 'Pod-Html'), 'corpus');
    $pod_glob = catfile($fromdir, '*.pod');
    @testfiles = glob($pod_glob);

    $targetdir = catdir($ephdir, 'testdir', 'test.lib');
    make_path($targetdir) or die "Could not make $targetdir for testing: $!";

    my %copying = ();
    for my $g (@testfiles) {
        my $basename = basename($g);
        my ($stub) = $basename =~ m{^(.*)\.pod};
        $stub =~ s{^perl(.*)}{$1};
        $copying{$stub} = {
            source => $g,
            target => catfile($targetdir, "${stub}.pod")
        };
    }

    for my $k (keys %copying) {
        copy $copying{$k}{source} => $copying{$k}{target}
            or die "Unable to copy: $!";
    }

    chdir $ephdir or die "Unable to change to $ephdir: $!";
    return $toptempdir;
}

sub xconvert {
    my $args = shift;
    for my $k ('podstub', 'description', 'expect') {
        die("convert_n_test() must have $k element")
            unless length($args->{$k});
    }
    my $podstub = $args->{podstub};
    my $description = $args->{description};
    my $debug = $args->{debug} // 0;
    if (defined $args->{p2h}) {
        die "Value for 'p2h' must be hashref"
            unless ref($args->{p2h}) eq 'HASH'; # TEST ME
    }
    my $cwd = Pod::Html::_unixify( Cwd::cwd() );
    my ($vol, $dir) = splitpath($cwd, 1);
    my @dirs = splitdir($dir);
    shift @dirs if $dirs[0] eq '';
    my $relcwd = join '/', @dirs;

    my $new_dir  = catdir $dir, "t";
    my $infile   = catpath $vol, $new_dir, "$podstub.pod";
    my $outfile  = catpath $vol, $new_dir, "$podstub.html";

    my $args_table = _prepare_args_table( {
        infile      => $infile,
        outfile     => $outfile,
        cwd         => $cwd,
        p2h         => $args->{p2h},
    } );
    my @args_list = _prepare_args_list($args_table);
    Pod::Html::pod2html( @args_list );

    $cwd =~ s|\/$||;

    my $expect = _set_expected_html($args->{expect}, $relcwd, $cwd);
    my $result = _get_html($outfile);

    _process_diff( {
        expect      => $expect,
        result      => $result,
        description => $description,
        podstub     => $podstub,
        outfile     => $outfile,
        debug       => $debug,
    } );

    # pod2html creates these
    unless ($debug) {
        1 while unlink $outfile;
        1 while unlink "pod2htmd.tmp";
    }
}

sub _prepare_args_table {
    my $args = shift;
    my %args_table = (
        infile      =>    $args->{infile},
        outfile     =>    $args->{outfile},
        podpath     =>    't',
        htmlroot    =>    '/',
        podroot     =>    $args->{cwd},
    );
    my %no_arg_switches = map { $_ => 1 } @no_arg_switches;
    if (defined $args->{p2h}) {
        for my $sw (keys %{$args->{p2h}}) {
            if ($no_arg_switches{$sw}) {
                $args_table{$sw} = undef;
            }
            else {
                $args_table{$sw} = $args->{p2h}->{$sw};
            }
        }
    }
    return \%args_table;
}

sub _prepare_args_list {
    my $args_table = shift;
    my @args_list = ();
    for my $k (keys %{$args_table}) {
        if (defined $args_table->{$k}) {
            push @args_list, "--" . $k . "=" . $args_table->{$k};
        }
        else {
            push @args_list, "--" . $k;
        }
    }
    return @args_list;
}

sub _set_expected_html {
    my ($expect, $relcwd, $cwd) = @_;
    $expect =~ s/\[PERLADMIN\]/$Config::Config{perladmin}/;
    $expect =~ s/\[RELCURRENTWORKINGDIRECTORY\]/$relcwd/g;
    $expect =~ s/\[ABSCURRENTWORKINGDIRECTORY\]/$cwd/g;
    if (ord("A") == 193) { # EBCDIC.
        $expect =~ s/item_mat_3c_21_3e/item_mat_4c_5a_6e/;
    }
    $expect =~ s/\n\n(some html)/$1/m;
    $expect =~ s{(TESTING FOR AND BEGIN</h1>)\n\n}{$1}m;
    return $expect;
}

sub _get_html {
    my $outfile = shift;
    local $/;

    open my $in, '<', $outfile or die "cannot open $outfile: $!";
    my $result = <$in>;
    close $in;
    return $result;
}

sub _process_diff {
    my $args = shift;
    die("_process_diff() takes hash ref") unless ref($args) eq 'HASH';
    my %keys_needed = map { $_ => 1 } (qw| expect result description podstub outfile |);
    my %keys_seen   = map { $_ => 1 } ( keys %{$args} );
    my @keys_missing = ();
    for my $kn (keys %keys_needed) {
        push @keys_missing, $kn unless exists $keys_seen{$kn};
    }
    die("_process_diff() arguments missing: @keys_missing") if @keys_missing;

    my $diff = '/bin/diff';
    -x $diff or $diff = '/usr/bin/diff';
    -x $diff or $diff = undef;
    my $diffopt = $diff ? $^O =~ m/(linux|darwin)/ ? '-u' : '-c'
                        : '';
    $diff = 'fc/n' if $^O =~ /^MSWin/;
    $diff = 'differences' if $^O eq 'VMS';
    if ($diff) {
        ok($args->{expect} eq $args->{result}, $args->{description}) or do {
            my $expectfile = $args->{podstub} . "_expected.tmp";
            open my $tmpfile, ">", $expectfile or die $!;
            print $tmpfile $args->{expect}, "\n";
            close $tmpfile;
            open my $diff_fh, "-|", "$diff $diffopt $expectfile $args->{outfile}"
                or die("problem diffing: $!");
            print STDERR "# $_" while <$diff_fh>;
            close $diff_fh;
            unlink $expectfile unless $args->{debug};
        };
    }
    else {
        # This is fairly evil, but lets us get detailed failure modes
        # anywhere that we've failed to identify a diff program.
        is($args->{expect}, $args->{result}, $args->{description});
    }
    return 1;
}

1;
