package Statsd::Client;
#
# 
use strict;
use warnings;
use Data::Dumper;

use Net::Statsd;
use Time::HiRes qw( time );

our $VERSION = 0.02;

# args:
# required:
#  host
#  port
#  application_name
# optional:
#  environment: a name for the current high level environment to group stats from this application under
#  sample_rate: default 1.  can be set to any number between 0 and 1
sub new {
	my $class = shift;
	my %args  = @_;
	my $self = bless \%args, $class;

	die "'statsd_host' is a required argument" unless $self->{statsd_host};
	die "'statsd_port' is a required argument" unless $self->{statsd_port};
	die "'application_name' is a required argument" unless $self->{application_name};
	die "'environment' is a required argument" unless $self->{environment};
	
	$Net::Statsd::HOST = $self->{statsd_host};
	$Net::Statsd::PORT = $self->{statsd_port};

	my $label;
	if ($self->{environment}) {
		$label = sprintf("%s.%s",
			$self->sanitize_field($self->{environment}),
			$self->{application_name},
		);
	} else {
		$label = $self->{application_name};
	}
	$self->{label} = $label;

	$self->{sample_rate} = 1 unless defined $self->{sample_rate};

	return $self;
}

# store a start time value
sub start_timer {
	my $self = shift;
	$self->{start_time} = time;
}

# subtract the start time from the current time and return the total duration in milliseconds
sub end_timer {
	my $self = shift;
	return unless defined($self->{start_time});
	return int(1000 * (time - $self->{start_time}));
}

# break up a file path (e.g. /aaa/bbb/ccc) into a nested key (e.g. aaa.bbb.ccc)
sub sanitize_path {
	my $self = shift;
	my $val = shift;
	return 'undefined' unless defined($val) && length($val);
	$val =~ s|\.|_|g;
	$val =~ s|^/||;
	$val =~ s|/$||;
	$val =~ s|/|\.|g;
	return lc($val);
}

# sanitize a field so we can use it as a single statsd key component (i.e. remove periods)
sub sanitize_field {
	my $self = shift;
	my $val = shift;
	return 'undefined' unless defined($val) && length($val);
	$val =~ s|^/||;
	$val =~ s|/|_|g;
	$val =~ s|\.|_|g;
	return lc($val);
}


# breakdown search metrics into different segments based on arbitrary criteria
# e.g. timing data for tracking_groups.similar_image_searches
sub record_stats_breakdowns {
	my $self = shift;
	my %args = @_;

	die "'metric_group_name' is required" unless $args{metric_group_name};

	my $timer_names       = delete($args{timer_names}) || {};
	my $counter_names     = delete($args{counter_names}) || {};
	my $metric_group_name = delete($args{metric_group_name});
	my $milliseconds      = delete($args{milliseconds});
	

	die 'timer_names must be a hash ref' if $timer_names && ref($timer_names) ne 'HASH';
	die 'counter_names must be a hash ref' if $counter_names && ref($counter_names) ne 'HASH';
	die sprintf("[%s] are not valid parameters", sort keys %args) if keys %args;

	if ($counter_names && ref($counter_names) eq 'HASH' && scalar keys %$counter_names) {

		my @keys;
		while (my ($key,$value) = each (%$counter_names)) {
			# ignore empty values
			next unless defined($value) && length($value);

			push @keys, $self->create_statsd_label(
					metric_group_name => $metric_group_name, 
					key => $key,
					value => $value,
				),
		}

		# send a list of keys at once to increment
		Net::Statsd::increment(
			\@keys,
			$self->{sample_rate},
		);
	}

	# log timing data to statsd
	if (defined($milliseconds) && $timer_names && ref($timer_names) eq 'HASH' && scalar keys %$timer_names) {

		while (my ($key,$value) = each (%$timer_names)) {
			# ignore empty values
			next unless defined($value) && length($value);
			
			Net::Statsd::timing(
				$self->create_statsd_label(
					metric_group_name => $metric_group_name, 
					key => $key,
					value => $value,
				),
				$milliseconds,
				$self->{sample_rate},
			);
		}
	}

	return;
}

# format the label for the given metric
sub create_statsd_label {
	my $self = shift;
	my %args = @_;
	my $metric_group_name = $args{metric_group_name} or die "'metric_group_name' is required";
	my $key = defined($args{key}) ? $args{key} : 'undefined';
	my $value = defined($args{value}) ? $args{value} : 'undefined';

	if (ref($value) || ref($key)) {
		die sprintf("A reference was passed in as a statsd key name. ignoring. %s, %s", Dumper($key), Dumper($value));
	}

	my $metric_name = sprintf(
		"%s.%s",
		$self->sanitize_field($key),
		$self->sanitize_field($value),
	);

	return sprintf(
		"%s.%s.%s", 
		$self->{label}, 
		$metric_group_name, 
		$metric_name, 
	);
}

1;

__END__

=head1 Name

Statsd::Client - Manage sending breakdowns of metrics sent to statsd

=head1 Synopsis

This module encapsulates the logic around sending batches of keys to statsd in one requests. 
e.g. if you want to breakdown all your request counts and timing data based on multiple parameters, and organize it in a hierarchy on the statsd server.  


=head1 Usage

	my $client = Statsd::Client->new(
		statsd_host => 'stats.somewhere.net',
		statsd_port => 8125,
		application_name => 'statsd.client.test',
		environment => 'dev',
	);
	
	$client->start_timer();

	... (your application code) ...

	$client->record_stats_breakdowns(
		metric_group_name => "demo.test",
		counter_names => {
			requests => 'total',
			language => 'en',
		},
		timer_names => {
			requests => 'total',
		},
		milliseconds => $client->end_timer(),
	);


=head1 Methods

=over

=item B<new> statsd_host => '', statsd_port => #, application_name => '', environment => '', sample_rate => #,

	statsd_host: the hostname of the statsd server
	statsd_port: the port that statsd server is listening on
	application_name: the name of the application.  this will be used in the key name sent to statsd
	environment: the name of the environment (e.g. dev, qa, prod...). this will be the top level name in the key sent to statsd
	sample_rate: the sample rate sent to statsd.  by default this will be 1, which means all data points will be sent.  may be a value betwee 0 - 1

=item B<record_stats_breakdowns> metric_group_name => '', counter_names => {}, timer_names => {}, milliseconds => #

	metric_group_name: this is the name under which all the other counter and timing metrics will be added
	counter_names: these are all the breakdowns for which you want to count the number of requests
	timer_names: these are all the breakdowns for which you want to view latency data
	milliseconds: this is the number of milliseconds you want to track in the timing data.  If you called the start_timer() method
	at the start of your application code, then you can pass in the value returned by end_timer() here.

=back
