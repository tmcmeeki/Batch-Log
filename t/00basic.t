use Test::More tests => 191;
use Module::Loaded;
use Data::Dumper;


# -------- sub-routines --------
sub linecount {	# do a line-count on the file passed
	my $pn = shift;
	my $ra = shift;
	my $lc = 0;

	@$ra = ()
		if (defined $ra);

	open(FH, "<$pn") || die "open($pn) read failed";

	while (<FH>) {
		$lc++;

		chomp;

		push @$ra, $_
			if (defined $ra);
	}

	close(FH) || die "close($pn) failed";

	return $lc;
}


sub truncate_file {	# truncate the file passed
	my $pn = shift;

	open(FH, ">$pn") || die "open($pn) write failed";
	close(FH) || die "close($pn) failed";

	return linecount($pn);
}


sub is_loggable {
	my ($lvl1, $func)=@_;
	my $lvl2 = uc $func;

	my $nl1 = Log::Log4perl::Level::to_priority($lvl1);
	my $nl2 = Log::Log4perl::Level::to_priority($lvl2);

	return 1 if (Log::Log4perl::Level::isGreaterOrEqual($nl1, $nl2));

	return 0;
}


# -------- global --------
BEGIN { use_ok('Batch::Log', qw/ :all /) };
my $log = get_logger(__FILE__);
isa_ok($log, "Log::Log4perl::Logger");


# -------- path --------
isnt(Batch::Log::set_path, "",		"set_path non-null");
my @tokens = split(/\./, __FILE__);
my $re = $tokens[0];
like(Batch::Log::set_path, qr/$re/,	"set_path prefix");
like(Batch::Log::set_path, qr/log/,	"set_path suffix");

my $pn = Batch::Log::get_path;
isnt($pn, "",				"get_path non-null");
ok(-f $pn == 1,				"get_path exists");
ok(-w $pn == 1,				"get_path writable");

is(truncate_file($pn), 0,		"truncate initial");


# -------- miscellaneous --------
isnt( is_loaded('Log::Log4perl'), "",		"loaded 0");
isnt( is_loaded('Batch::Log'), "",		"loaded 1");

isnt( is_loaded('Tk'), 0,			"not_loaded 0");
isnt( is_loaded('Log::Dispatch::TkText'), 0,	"not_loaded 1");

is(Batch::Log::default_level, "INFO",		"default_level default");
is(Batch::Log::default_level("XXX"), "XXX",	"default_level override");
is(Batch::Log::default_level, "INFO",		"default_level reset");

is(Batch::Log::get_level, "INFO",		"get_level default");

delete $ENV{'DEBUG'};
isnt(exists $ENV{'DEBUG'}, 1,			"clear environment");
is(set_level($log), "INFO",			"set_level default");
my $rep = '\%.+n$';
like(Batch::Log::get_pattern, qr/$rep/,			"get_pattern default");

like(Batch::Log::set_pattern, qr/$rep/,			"set_pattern default");
like(Batch::Log::set_pattern("INFO"), qr/$rep/,		"set_pattern override");
like(Batch::Log::set_pattern("INVALID"), qr/$rep/,	"set_pattern invalid");


# -------- setup functions and levels --------
my @levels = qw/ OFF TRACE DEBUG INFO WARN ERROR FATAL ALL /;
my @functions = map { lc $_ } @levels;
pop @functions;
shift @functions;

#printf "functions [%s] levels [%s]\n", Dumper(\@functions), Dumper(\@levels);

# -------- test log functions at all levels --------
my $cycle = 0;
for my $level (@levels) {

	$ENV{'DEBUG'} = $level;

	is(set_level($log), $level,		"set_level   cycle $cycle shell=$level");
	is(set_level($log, $level), $level,	"set_level   cycle $cycle set=$level");

	is(Batch::Log::get_level, $level,	"get_level   cycle $cycle $level");
	for my $func (@functions) {

		my $what = "cycle=$cycle level=$level func=$func";

		$log->$func("'message $what'");

		my $lc = undef;
		if ($level eq 'ALL') {
			$lc = 1;
		} elsif ($level eq 'OFF') {
			$lc = 0;
		} else {
			$lc =is_loggable($level, $func); 
		}

		my @grep;

		is(linecount($pn, \@grep), $lc,	"linecount=$lc $what");

		my $re=uc " $func ";
		my @match = grep /$re/, @grep;
		is(@match, $lc,			"grep $what");


		is(truncate_file($pn), 0,	"truncate    $what");
		$cycle++;
	}
}

#$log->info(sprintf "log [%s]", Dumper($log));
#$log->info(sprintf "appenders [%s]", Dumper(Log::Log4perl::appenders));


# -------- finalise --------
#$log->info("processing complete.");

__END__

=head1 DESCRIPTION

00basic.t - test harness for Batch::Log - basic tests

=head1 VERSION

SEE DISTRIBUTION NOTES

=head1 AUTHOR

Copyright (C) 2011  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 2 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=head1 SEE ALSO

L<perl>.

=cut

