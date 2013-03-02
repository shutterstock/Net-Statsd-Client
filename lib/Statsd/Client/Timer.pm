package Statsd::Client::Timer;
use Time::HiRes qw(gettimeofday tv_interval);

sub new {
  my ($class, %args) = @_;

  my $start = [gettimeofday];
  my (undef, $file, $line) = caller(1);

  my $self = {
    %args,
    start => $start,
    _file => $file,
    _line => $line,
    _pending => 1,
  };

  return bless $self, $class;
}

sub finish {
  my ($self) = @_;
  my $duration = tv_interval($self->{start});
  $self->{statsd}->timing(
    $self->{metric},
    $duration,
    $self->{sample_rate},
  );
  delete $self->{_pending};
}

sub cancel {
  my ($self) = @_;
  delete $self->{_pending};
}

sub DESTROY {
  my ($self) = @_;
  if ($self->{_pending}) {
    my $metric = $self->{metric};
    $metric = $self->{statsd}{prefix} . $metric if $self->{statsd} && $self->{statsd}{prefix};
    warn "Unfinished timer for stat $metric (created at $self->{_file} line $self->{_line})";
  }
}

1;

__END__

=head1 NAME

Shutterstock::Statsd::Timer - Measure event timings and send them to StatsD

=head1 SYNOPSIS

    use Shutterstock::Statsd;
    my $stats = Shutterstock::Statsd->new(prefix => "service.frobnitzer.");

    my $timer = $stats->timer("request_duration");
    # ... do something expensive ...
    $timer->finish;

=head1 METHODS

=head2 Shutterstock::Statsd::Timer->new(...)

To build a timer object, call L<Shutterstock::Statsd>'s C<timer> method,
instead of calling this constructor directly.

A timer has an associated statsd object, metric name, and sample rate, and
begins counting as soon as it's constructed.

=head2 $timer->finish

Stop timing, and send the elapsed time to the server.

=head2 $timer->cancel

Stop timing, but do not send the elapsed time to the server. A timer that
goes out of scope without having C<finish> or C<cancel> called on it will
generate a warning, since this probably points to bugs and lost timing
information.
