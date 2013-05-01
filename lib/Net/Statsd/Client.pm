package Net::Statsd::Client;
use strict;
use warnings;

# ABSTRACT: Send data to StatsD / Graphite
# VERSION
# AUTHORITY

use Etsy::StatsD;
use Net::Statsd::Client::Timer;

my $statsd;

sub instance {
  my $class = shift;
  unless (defined $statsd) {
    $statsd = $class->_build_statsd;
  }
  return $statsd;
}

sub new {
  my $class = shift;
  my %args = @_;
  my $self = {};

  $self->{prefix} = $args{prefix} || "";
  $self->{sample_rate} = defined $args{sample_rate} ? $args{sample_rate} : 1;
  $self->{host} = $args{host} || "localhost";
  $self->{port} = $args{port} || 8125;

  $self->{statsd} = Etsy::StatsD->new($self->{host}, $self->{port});

  return bless $self, $class;
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
