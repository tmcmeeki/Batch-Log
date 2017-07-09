package Batch::Log;
#
# Batch::Log.pm - simple wrapper for Log::Log4perl.
# $Revision: 1.3 $, Copyright (C) 2011 Thomas McMeekin
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
=head1 NAME

Batch::Log - simple wrapper for Log::Log4perl.

=head1 SYNOPSIS

  use Batch::Log qw/ :all /;

  my $log = get_logger("mylog");

  $log->debug("got here");

  set_level($log, 'OFF');

=head1 DESCRIPTION

Batch::Log.pm - simple wrapper for Log::Log4perl.

This is a simple wrapper for B<Log4perl> which sets up logging to both
file and terminal simultaneously.

It performs automatic configuration of logging locations and formats, e.g.
the log file's path is derived automatically.

It bases the initial logging format on the value of the environment variable 
B<DEBUG> which can be set to any of the following values:

  OFF TRACE DEBUG INFO WARN ERROR FATAL ALL

If the variable is not specified, logging will assume a level of INFO.

The default directory for logs is the user's $HOME/log directory, and 
the filename will  resemble the program name (but with a '.log' extension),

The logging level can be modified at run-time using the B<set_level> function,
per below.  Note that the level of logging will also determine the format of
the log message, e.g. TRACE and DEBUG logging has more information 
embedded in the message than INFO logging.

=head2 PUBLIC ROUTINES (exported)

=over 4

=item 1a.  get_logger(EXPR)

Retrieve the logger object for use in standard logging operations.  This
is equivalent to the Log4perl routine of the name name.  You should be
able to use this object just as you would a B<Log4perl> object.

This routine will setup all appenders and formats based on the value
of the DEBUG shell variable at the time of the call.

=item 1b.  set_level([LEVEL])

This routine allows you to modify the logging level/format at run-time.
If the LEVEL parameter is unspecified it will take its value from the DEBUG
shell variable.  

Note that the LEVEL parameter is a string rather than an integer, and will
be translated by this module into a value as recognised by Log4perl.

=back

=head2 OTHER ROUTINES (not exported)

=over 4

=item 2a.  default_level([LEVEL])

Reports the default logging level.  Does not modify any internal variables.

=item 2b.  get_level

Reports the current logging level being used by all appenders.

=item 3a.  get_path

Reports the current pathname of the logging file.

=item 3b.  set_path

Establishes the default pathname for the logging file and reports it.
Note that this is automatically run as soon as this module is loaded.

=item 4a.  get_pattern

Reports the current message pattern being used by all appenders.

=item 4b.  set_pattern([LEVEL])

Modifies the current message pattern to that of the LEVEL specified. 
If LEVEL is not specified then a default will apply.  All appenders
will then be updated to the new pattern.

=back

=cut

use strict;

use Data::Dumper;
use Exporter;
use File::Basename;
use File::Spec;
use Log::Log4perl qw/ :levels :no_extra_logdie_message /;
#use Module::Loaded;


# ---- package constants ----
use constant DN_LOG => File::Spec->catfile($ENV{'HOME'}, "log");

use constant EXT_LOG => "log";

use constant P_NORMAL => '%d %p %F{1} %m%n';
use constant P_DEBUG => '%d %p %F{2}(%L) %M{2} %m%n';
use constant P_TRACE => '%d %p pid=%P %T %m%n';


# ---- package globals ----
our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);


# ---- package locals ----
my %_setting;

my @_appender = (
	{ 'name' => "TermBatch::Log", 'type' => "Screen" },
	{ 'name' => "FileBatch::Log", 'type' => "File" },

#	---> add more appenders here if need be
);

# ---- sub-routines ----
BEGIN {
        $VERSION = sprintf "%d.%03d", q$Revision: 1.3 $ =~ /(\d+)/g;

        @ISA = qw(Exporter Log::Log4perl);

        @EXPORT_OK = qw(get_logger set_level OFF TRACE DEBUG INFO WARN ERROR FATAL ALL);

	%EXPORT_TAGS = (
		levels => [qw/ OFF TRACE DEBUG INFO WARN ERROR FATAL ALL /],
		all => [qw/ get_logger set_level OFF TRACE DEBUG INFO WARN ERROR FATAL ALL /],
	);
}


#INIT { };


sub _create_appenders {
	my $log = shift;
	my $c_appender = "Log::Log4perl::Appender";

	for my $record (@_appender) {

		my $type = $record->{'type'};
		my $id = $record->{'name'};
		my $class = $c_appender . "::" . $type;

#		print "class [$class] type [$type]\n";
#		printf "_setting [%s]\n", Dumper(\%_setting);
#		printf "set_path [%s]\n", set_path();

		my $oa = (); 	# reset

		if ($type eq 'File') {

			$oa = $c_appender->new($class, 'name' => $id,
				'filename' => $_setting{'path'});

		} elsif ($type eq 'Screen') {

			$oa = $c_appender->new($class, 'name' => $id,
				'stderr' => 0, 'utf8' => 0);

		}
#		print "ref(oa) " . ref($oa) . "\n";

		$log->add_appender($oa);

		$record->{'object'} = $oa;	# remember for later
	}
#	printf "_appender [%s]\n", Dumper(\@_appender);
}


sub _get_setting {
	my $setting = shift;

	unless (exists $_setting{$setting}) {
		return undef;
	}

	return $_setting{$setting};
}


sub default_level {
	my $level = shift;	# optional

	$level = exists($ENV{'DEBUG'}) ? $ENV{'DEBUG'} : "INFO"
		unless (defined $level);

	return $level;
}


sub get_level {

	return _get_setting('level');
}


sub set_level {
	my $log = shift;
	my $level = default_level(shift);

	set_pattern($level);

	# convert to a numeric value and thus validate!

	my $level_num = Log::Log4perl::Level::to_priority($level);

##	printf "\t\txxx level [$level] level_num [%ld]\n", $level_num;

	$log->level($level_num);

	$_setting{'level'} = $level;

	return $level;
}


sub get_path {

	return _get_setting('path');
}


sub set_path {
	my $ext = EXT_LOG;
	my $fn_log = basename($0);

	$fn_log =~ s/(pl|t|pm)$/$ext/;

	my $pn_log = (-d DN_LOG) ? File::Spec->catfile(DN_LOG, $fn_log) : $fn_log;

	$_setting{'path'} = $pn_log;

	return $pn_log;
}


sub get_logger {
	my $log = Log::Log4perl::get_logger(shift);

	set_path();

	_create_appenders($log);

	set_level($log);

	return $log;
}


sub get_pattern {

	return _get_setting('pattern');
}


sub set_pattern {
	my $level = default_level(shift);

	# establish a default pattern

	# levels: TRACE DEBUG INFO WARN ERROR FATAL
	my %pattern = ( 'INFO' => P_NORMAL, 'TRACE' => P_TRACE );

	my $pattern = exists($pattern{$level}) ? $pattern{$level} : P_DEBUG;

#	print "\t\txxx pattern [$pattern]\n";

	# apply the pattern layout to my registered appenders

	my $layout = Log::Log4perl::Layout::PatternLayout->new($pattern);

	for my $record (@_appender) {

		my $name = $record->{'name'};
		my $oa = $record->{'object'};

#		printf "name [$name] ref [%s] layout [%s]\n", ref($oa), ref($layout);

		$oa->layout($layout);
	}

	$_setting{'pattern'} = $pattern;

	return $pattern;
}


#END { }

1;

__END__

=head1 TO-DO

1. Test creation and disablement of appenders after initial creation, i.e.
dynamic appender creation.

2. Create a routine for a Tk-style logger, i.e. logging to a widget which
should necessarily disable the STDOUT appender.

=head1 VERSION

$Revision: 1.3 $

=head1 AUTHOR

Copyright (C) 2011  Tom McMeekin

=head1 SEE ALSO

L<perl>, L<Log::Log4perl>.

=cut

