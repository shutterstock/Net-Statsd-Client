package Shutterstock::Statsd;
use strict;
use warnings;

use Etsy::StatsD;
use Shutterstock::Statsd::Timer;
use Shutterstock::Config;

my ($statsd, $config);

sub _build_statsd {
  my $class = shift;
  $config ||= Shutterstock::Config->instance;

  my $host = $config->{statsd}{host};
  my $port = $config->{statsd}{port} || 8125;

  return Etsy::StatsD->new($host, $port);
}

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
  $config ||= Shutterstock::Config->instance;

  $self->{prefix} = $args{prefix} || "";
  my $site_mode = $config->{site_mode};
  if ($site_mode eq 'test') {
    $self->{prefix} = "dev.$self->{prefix}";
  } elsif ($site_mode eq 'qa') {
    $self->{prefix} = "qa.$self->{prefix}";
  }

  $self->{sample_rate} = defined $args{sample_rate} ? $args{sample_rate} : 1;
  $self->{statsd} = $class->instance;

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

sub timing {
  my ($self, $metric, $time, $sample_rate) = @_;
  $metric = "$self->{prefix}$metric";
  $self->{statsd}->timing($metric, $time, $sample_rate);
}

sub timer {
  my ($self, $metric, $sample_rate) = @_;

  return Shutterstock::Statsd::Timer->new(
    statsd => $self,
    metric => $metric,
    sample_rate => $sample_rate,
  );
}

1;

__END__

=head1 NAME

Shutterstock::Statsd - Send data to StatsD / Graphite

=head1 SYNOPSIS

    use Shutterstock::Statsd;
    my $stats = Shutterstock::Statsd->new(prefix => "service.frobnitzer.");
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

=head2 $stats->timing($metric, $time, [$sample_rate])

Record an event of duration C<$time> for the named timing metric.

=head2 $stats->timer($metric, [$sample_rate])

Returns a L<Shutterstock::Statsd::Timer> object for the named timing metric.
The timer begins when you call this method, and ends when you call C<finish>
on the timer.
