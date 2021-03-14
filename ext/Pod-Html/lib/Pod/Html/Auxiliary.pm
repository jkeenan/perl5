package Pod::Html::Auxiliary;
use strict;
require Exporter;

our $VERSION = 1.26; # Please keep in synch with lib/Pod/Html.pm
our @ISA = qw(Exporter);
#parse_command_line
our @EXPORT_OK = qw(
    anchorify
    html_escape
    htmlify
    relativize_url
    trim_leading_whitespace
    unixify
    usage
);

#use Config;
use File::Spec;
use File::Spec::Unix;
#use Getopt::Long;
use Pod::Simple::XHTML;
use Text::Tabs;
use locale; # make \w work right in non-ASCII lands

#sub parse_command_line {
#    my %opts = ();
#
#    unshift @ARGV, split ' ', $Config{pod2html} if $Config{pod2html};
#    my $result = GetOptions(\%opts,
#        'backlink!',
#        'cachedir=s',
#        'css=s',
#        'flush',
#        'help',
#        'header!',
#        'htmldir=s',
#        'htmlroot=s',
#        'index!',
#        'infile=s',
#        'libpods=s', # deprecated
#        'outfile=s',
#        'poderrors!',
#        'podpath=s',
#        'podroot=s',
#        'quiet!',
#        'recurse!',
#        'title=s',
#        'verbose!',
#    );
#    usage("-", "invalid parameters") if not $result;
#
#    usage("-") if defined $opts{help};    # see if the user asked for help
#    $opts{help} = ''; # just to make -w shut-up.
#    return \%opts;
#}

sub usage {
    my $podfile = shift;
    warn "$0: $podfile: @_\n" if @_;
    die <<END_OF_USAGE;
Usage:  $0 --help --htmldir=<name> --htmlroot=<URL>
           --infile=<name> --outfile=<name>
           --podpath=<name>:...:<name> --podroot=<name>
           --cachedir=<name> --flush --recurse --norecurse
           --quiet --noquiet --verbose --noverbose
           --index --noindex --backlink --nobacklink
           --header --noheader --poderrors --nopoderrors
           --css=<URL> --title=<name>

  --[no]backlink  - turn =head1 directives into links pointing to the top of
                      the page (off by default).
  --cachedir      - directory for the directory cache files.
  --css           - stylesheet URL
  --flush         - flushes the directory cache.
  --[no]header    - produce block header/footer (default is no headers).
  --help          - prints this message.
  --htmldir       - directory for resulting HTML files.
  --htmlroot      - http-server base directory from which all relative paths
                      in podpath stem (default is /).
  --[no]index     - generate an index at the top of the resulting html
                      (default behaviour).
  --infile        - filename for the pod to convert (input taken from stdin
                      by default).
  --outfile       - filename for the resulting html file (output sent to
                      stdout by default).
  --[no]poderrors - include a POD ERRORS section in the output if there were 
                      any POD errors in the input (default behavior).
  --podpath       - colon-separated list of directories containing library
                      pods (empty by default).
  --podroot       - filesystem base directory from which all relative paths
                      in podpath stem (default is .).
  --[no]quiet     - suppress some benign warning messages (default is off).
  --[no]recurse   - recurse on those subdirectories listed in podpath
                      (default behaviour).
  --title         - title that will appear in resulting html file.
  --[no]verbose   - self-explanatory (off by default).

END_OF_USAGE

}

sub unixify {
    my $full_path = shift;
    return '' unless $full_path;
    return $full_path if $full_path eq '/';

    my ($vol, $dirs, $file) = File::Spec->splitpath($full_path);
    my @dirs = $dirs eq File::Spec->curdir()
               ? (File::Spec::Unix->curdir())
               : File::Spec->splitdir($dirs);
    if (defined($vol) && $vol) {
        $vol =~ s/:$// if $^O eq 'VMS';
        $vol = uc $vol if $^O eq 'MSWin32';

        if( $dirs[0] ) {
            unshift @dirs, $vol;
        }
        else {
            $dirs[0] = $vol;
        }
    }
    unshift @dirs, '' if File::Spec->file_name_is_absolute($full_path);
    return $file unless scalar(@dirs);
    $full_path = File::Spec::Unix->catfile(File::Spec::Unix->catdir(@dirs),
                                           $file);
    $full_path =~ s|^\/|| if $^O eq 'MSWin32'; # C:/foo works, /C:/foo doesn't
    $full_path =~ s/\^\././g if $^O eq 'VMS'; # unescape dots
    return $full_path;
}

# relativize_url - convert an absolute URL to one relative to a base URL.
# Assumes both end in a filename.
#

sub relativize_url {
    my ($dest, $source) = @_;

    # Remove each file from its path
    my ($dest_volume, $dest_directory, $dest_file) =
        File::Spec::Unix->splitpath( $dest );
    $dest = File::Spec::Unix->catpath( $dest_volume, $dest_directory, '' );

    my ($source_volume, $source_directory, $source_file) =
        File::Spec::Unix->splitpath( $source );
    $source = File::Spec::Unix->catpath( $source_volume, $source_directory, '' );

    my $rel_path = '';
    if ($dest ne '') {
       $rel_path = File::Spec::Unix->abs2rel( $dest, $source );
    }

    if ($rel_path ne '' && substr( $rel_path, -1 ) ne '/') {
        $rel_path .= "/$dest_file";
    } else {
        $rel_path .= "$dest_file";
    }

    return $rel_path;
}

#
# html_escape: make text safe for HTML
#
sub html_escape {
    my $rest = $_[0];
    $rest   =~ s/&/&amp;/g;
    $rest   =~ s/</&lt;/g;
    $rest   =~ s/>/&gt;/g;
    $rest   =~ s/"/&quot;/g;
    $rest =~ s/([[:^print:]])/sprintf("&#x%x;", ord($1))/aeg;
    return $rest;
}

=head2 htmlify

    htmlify($heading);

Converts a pod section specification to a suitable section specification
for HTML. Note that we keep spaces and special characters except
C<", ?> (Netscape problem) and the hyphen (writer's problem...).

=cut

sub htmlify {
#    my( $heading) = @_;
#    $heading =~ s/(\s+)/ /g;
#    $heading =~ s/\s+\Z//;
#    $heading =~ s/\A\s+//;
#    # The hyphen is a disgrace to the English language.
#    # $heading =~ s/[-"?]//g;
#    $heading =~ s/["?]//g;
#    $heading = lc( $heading );
#    return $heading;
    my( $heading) = @_;
    return Pod::Simple::XHTML->can("idify")->(undef, $heading, 1);
}

=head2 anchorify

    anchorify(@heading);

Similar to C<htmlify()>, but turns non-alphanumerics into underscores.  Note
that C<anchorify()> is not exported by default.

=cut

sub anchorify {
    my ($anchor) = @_;
    $anchor = htmlify($anchor);
    $anchor =~ s/\W/_/g;
    return $anchor;
}

# Remove any level of indentation (spaces or tabs) from each code block consistently
# Adapted from: https://metacpan.org/source/HAARG/MetaCPAN-Pod-XHTML-0.002001/lib/Pod/Simple/Role/StripVerbatimIndent.pm
sub trim_leading_whitespace {
    my ($para) = @_;

    # Start by converting tabs to spaces
    @$para = Text::Tabs::expand(@$para);

    # Find the line with the least amount of indent, as that's our "base"
    my @indent_levels = (sort(map { $_ =~ /^( *)./mg } @$para));
    my $indent        = $indent_levels[0] || "";

    # Remove the "base" amount of indent from each line
    foreach (@$para) {
        $_ =~ s/^\Q$indent//mg;
    }

    return;
}

1;

