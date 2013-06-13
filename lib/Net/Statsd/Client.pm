package Net::Statsd::Client;
use Moo;
use Sub::Quote;

# ABSTRACT: Send data to StatsD / Graphite
# VERSION
# AUTHORITY

use Etsy::StatsD;
use Net::Statsd::Client::Timer;

has 'prefix' => (
  is => 'ro',
  default => quote_sub q{''},
);

has 'sample_rate' => (
  is => 'ro',
  default => quote_sub q{1},
);

has 'host' => (
  is => 'ro',
  default => quote_sub q{'localhost'},
);

has 'port' => (
  is => 'ro',
  default => quote_sub q{8125},
);

has 'statsd' => (
  is => 'rw',
);

has 'warning_callback' => (
  is => 'rw',
);

sub BUILD {
  my ($self) = @_;
  $self->statsd(
    Etsy::StatsD->new($self->host, $self->port)
  );
}

sub increment {
  my ($self, $metric, $sample_rate) = @_;
  $metric = "$self->{prefix}$metric";
  $sample_rate = $self->{sample_rate} unless defined $sample_rate;
  $self->{statsd}->increment($metric, $sample_rate);
}

sub decrement {
  my ($self, $metric, $sample_rate) = @_;
  $metric = "$self->{prefix}$metric";
  $sample_rate = $self->{sample_rate} unless defined $sample_rate;
  $self->{statsd}->decrement($metric, $sample_rate);
}

sub update {
  my ($self, $metric, $value, $sample_rate) = @_;
  $metric = "$self->{prefix}$metric";
  $sample_rate = $self->{sample_rate} unless defined $sample_rate;
  $self->{statsd}->update($metric, $value, $sample_rate);
}

sub timing_ms {
  my ($self, $metric, $time, $sample_rate) = @_;
  $metric = "$self->{prefix}$metric";
  $self->{statsd}->timing($metric, $time, $sample_rate);
}

sub timer {
  my ($self, $metric, $sample_rate) = @_;

  return Net::Statsd::Client::Timer->new(
    statsd => $self,
    metric => $metric,
    sample_rate => $sample_rate,
    warning_callback => $self->warning_callback,
  );
}

1;

__END__

=head1 SYNOPSIS

    use Net::Statsd::Client
    my $stats = Net::Statsd::Client->new(prefix => "service.frobnitzer.");
    $stats->increment("requests"); # service.frobnitzer.requests++ in graphite

    my $timer = $stats->timer("request_duration");
    # ... do something expensive ...
    $timer->finish;

=head1 ATTRIBUTES

=head2 prefix

B<Optional:> A prefix to be added to all metric names logged throught his
object.

=head2 sample_rate

B<Optional:> A value between 0 and 1, determines what fraction of events
will actually be sent to the server. This sets the default sample rate,
which can be overridden on a case-by-case basis when sending an event (for
instance, you might choose to send errors at a 100% sample rate, but other
events at 1%).

=head1 METHODS

=head2 $stats->increment($metric, [$sample_rate])

Increment the named counter metric.

=head2 $stats->decrement($metric, [$sample_rate])

Decrement the named counter metric.

=head2 $stats->update($metric, $count, [$sample_rate])

Add C<$count> to the value of the named counter metric.

=head2 $stats->timing_ms($metric, $time, [$sample_rate])

Record an event of duration C<$time> milliseconds for the named timing metric.

=head2 $stats->timer($metric, [$sample_rate])

Returns a L<Net::Statsd::Client::Timer> object for the named timing metric.
The timer begins when you call this method, and ends when you call C<finish>
on the timer.
