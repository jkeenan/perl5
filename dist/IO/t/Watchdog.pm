package Watchdog;

use strict;

use Config;
use Test::More;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = ('watchdog');

my $is_mswin    = $^O eq 'MSWin32';
my $is_vms      = $^O eq 'VMS';
my $is_cygwin   = $^O eq 'cygwin';
our $NO_ENDING = 0;

sub watchdog ($;$)
{
    my $timeout = shift;
    my $method  = shift || "";
    my $timeout_msg = 'Test process timed out - terminating';

    # Valgrind slows perl way down so give it more time before dying.
    $timeout *= 10 if $ENV{PERL_VALGRIND};

    my $pid_to_kill = $$;   # PID for this process

    if ($method eq "alarm") {
        goto WATCHDOG_VIA_ALARM;
    }

    # shut up use only once warning
    my $threads_on = $threads::threads && $threads::threads;

    # Don't use a watchdog process if 'threads' is loaded -
    #   use a watchdog thread instead
    if (!$threads_on || $method eq "process") {

        # On Windows and VMS, try launching a watchdog process
        #   using system(1, ...) (see perlport.pod)
        if ($is_mswin || $is_vms) {
            # On Windows, try to get the 'real' PID
            if ($is_mswin) {
                eval { require Win32; };
                if (defined(&Win32::GetCurrentProcessId)) {
                    $pid_to_kill = Win32::GetCurrentProcessId();
                }
            }

            # If we still have a fake PID, we can't use this method at all
            return if ($pid_to_kill <= 0);

            # Launch watchdog process
            my $watchdog;
            eval {
                local $SIG{'__WARN__'} = sub {
                    _diag("Watchdog warning: $_[0]");
                };
                my $sig = $is_vms ? 'TERM' : 'KILL';
                my $prog = "sleep($timeout);" .
                           "warn qq/# $timeout_msg" . '\n/;' .
                           "kill(q/$sig/, $pid_to_kill);";

                # If we're in taint mode PATH will be tainted
                $ENV{PATH} =~ /(.*)/s;
                local $ENV{PATH} = untaint_path($1);

                # On Windows use the indirect object plus LIST form to guarantee
                # that perl is launched directly rather than via the shell (see
                # perlfunc.pod), and ensure that the LIST has multiple elements
                # since the indirect object plus COMMANDSTRING form seems to
                # hang (see perl #121283). Don't do this on VMS, which doesn't
                # support the LIST form at all.
                if ($is_mswin) {
                    my $runperl = which_perl();
                    $runperl =~ /(.*)/;
                    $runperl = $1;
                    if ($runperl =~ m/\s/) {
                        $runperl = qq{"$runperl"};
                    }
                    $watchdog = system({ $runperl } 1, $runperl, '-e', $prog);
                }
                else {
                    my $cmd = _create_runperl(prog => $prog);
                    $watchdog = system(1, $cmd);
                }
            };
            if ($@ || ($watchdog <= 0)) {
                _diag('Failed to start watchdog');
                _diag($@) if $@;
                undef($watchdog);
                return;
            }

            # Add END block to parent to terminate and
            #   clean up watchdog process
            eval("END { local \$! = 0; local \$? = 0;
                        wait() if kill('KILL', $watchdog); };");
            return;
        }

        # Try using fork() to generate a watchdog process
        my $watchdog;
        eval { $watchdog = fork() };
        if (defined($watchdog)) {
            if ($watchdog) {   # Parent process
                # Add END block to parent to terminate and
                #   clean up watchdog process
                eval "END { local \$! = 0; local \$? = 0;
                            wait() if kill('KILL', $watchdog); };";
                return;
            }

            ### Watchdog process code

            # Load POSIX if available
            eval { require POSIX; };

            # Execute the timeout
            sleep($timeout - 2) if ($timeout > 2);   # Workaround for perlbug #49073
            sleep(2);

            # Kill test process if still running
            if (kill(0, $pid_to_kill)) {
                _diag($timeout_msg);
                kill('KILL', $pid_to_kill);
		if ($is_cygwin) {
		    # sometimes the above isn't enough on cygwin
		    sleep 1; # wait a little, it might have worked after all
		    system("/bin/kill -f $pid_to_kill") if kill(0, $pid_to_kill);
		}
            }

            # Don't execute END block (added at beginning of this file)
            $NO_ENDING = 1;

            # Terminate ourself (i.e., the watchdog)
            POSIX::_exit(1) if (defined(&POSIX::_exit));
            exit(1);
        }

        # fork() failed - fall through and try using a thread
    }

    # Use a watchdog thread because either 'threads' is loaded,
    #   or fork() failed
    if (eval {require threads; 1}) {
        'threads'->create(sub {
                # Load POSIX if available
                eval { require POSIX; };

                # Execute the timeout
                my $time_left = $timeout;
                do {
                    $time_left = $time_left - sleep($time_left);
                } while ($time_left > 0);

                # Kill the parent (and ourself)
                select(STDERR); $| = 1;
                _diag($timeout_msg);
                POSIX::_exit(1) if (defined(&POSIX::_exit));
                my $sig = $is_vms ? 'TERM' : 'KILL';
                kill($sig, $pid_to_kill);
            })->detach();
        return;
    }

    # If everything above fails, then just use an alarm timeout
WATCHDOG_VIA_ALARM:
    if (eval { alarm($timeout); 1; }) {
        # Load POSIX if available
        eval { require POSIX; };

        # Alarm handler will do the actual 'killing'
        $SIG{'ALRM'} = sub {
            select(STDERR); $| = 1;
            _diag($timeout_msg);
            POSIX::_exit(1) if (defined(&POSIX::_exit));
            my $sig = $is_vms ? 'TERM' : 'KILL';
            kill($sig, $pid_to_kill);
        };
    }
}

1;
