package Net::Statsd::Client::Timer;
use Moo;
use Sub::Quote;
use Carp;

# ABSTRACT: Measure event timings and send them to StatsD
# VERSION
# AUTHORITY

use Time::HiRes qw(gettimeofday tv_interval);

has 'statsd' => (
  is => 'ro',
  required => 1,
);

has '_pending' => (
  is => 'rw',
  default => quote_sub q{1},
);

has ['metric', 'start', '_file', '_line', 'warning_callback'] => (
  is => 'rw',
);

sub BUILD {
  my ($self) = @_;
  my (undef, $file, $line) = caller(1);

  $self->start([gettimeofday]);
  $self->_file($file);
  $self->_line($line);
}

sub _send_timing {
  my ($self, $metric, $start, $end) = @_;
  my $duration = tv_interval($start, $end);
  $self->{statsd}->timing_ms(
    $metric,
    $duration * 1000,
    $self->{sample_rate},
  );
}

sub _time_since {
  my ($self, $metric, $now, $since) = @_;

  my $start;
  if ($since eq 'previous' && $self->{previous_checkpoint}) {
    $start = $self->{previous_checkpoint}
  } else {
    $start = $self->{start};
  }

  $self->_send_timing($metric, $start, $now);
}

sub finish {
  my ($self, %args) = @_;
  my $now = [gettimeofday];

  my $metric = exists $args{metric} ? $args{metric} : $self->{metric};
  croak "No metric name provided to either ->finish or ->timer" unless defined $metric;

  my $since = exists $args{since} ? $args{since} : 'previous';
  $self->_time_since($metric, $now, $since);

  delete $self->{_pending};
}

sub checkpoint {
  my ($self, %args) = @_;
  my $now = [gettimeofday];

  croak "Metric name is required" unless defined $args{metric};

  my $since = exists $args{since} ? $args{since} : 'previous';
  $self->_time_since($args{metric}, $now, $since);

  $self->{previous_checkpoint} = $now;
}

sub cancel {
  my ($self) = @_;
  delete $self->{_pending};
}

sub emit_warning {
  my $self = shift;
  if (defined $self->warning_callback) {
    $self->warning_callback->(@_);
  } else {
    warn(@_);
  }
}

sub DEMOLISH {
  my ($self) = @_;
  if ($self->{_pending}) {
    my $metric = $self->{metric};
    my $message = "";
    if (defined $metric) {
        $metric = $self->{statsd}{prefix} . $metric if $self->{statsd} && $self->{statsd}{prefix};
        $message = " for stat $metric";
    }
    $self->emit_warning("Unfinished timer $message(created at $self->{_file} line $self->{_line})");
  }
}

1;

__END__

=head1 SYNOPSIS

    use Net::Statsd::Client;
    my $stats = Net::Statsd::Client->new(prefix => "service.frobnitzer.");

    my $timer = $stats->timer("request_duration");
    # ... do something expensive ...
    $timer->finish;

=head1 METHODS

=head2 Net::Statsd::Client::Timer->new(...)

To build a timer object, call L<Net::Statsd::Client>'s C<timer> method,
instead of calling this constructor directly.

A timer has an associated statsd object, metric name, and sample rate, and
begins counting as soon as it's constructed.

=head2 $timer->finish([ metric => $metric ], [ since => $since ])

Stop timing, and send the elapsed time to the server. A metric name can
be provided, overriding any metric name provided when constructing the
timer. If a metric name wasn't provided on construction, then providing it
to C<finish> is mandatory.

=head2 $timer->checkpoint(metric => $metric, [ since => $since ])

Send an elapsed time to the server and create a new checkpoint. The timer is
not marked as finished.

=head2 $timer->cancel

Stop timing, but do not send the elapsed time to the server. A timer that
goes out of scope without having C<finish> or C<cancel> called on it will
generate a warning, since this probably points to bugs and lost timing
information.

=head2 $timer->metric($new)

Change the metric name of a timer on the fly. This is useful if you don't
know what kind of event you're timing until it's finished. Harebrained
example:


=head1 USING TIMERS AND CHECKPOINTS

C<Net::StatsD::Client> supports three basic workflows with timers, with the
goal of making timing as easy as possible.

=head2 Basic Timing

In the normal scenario, you declare a timer with a metric name before you do
some work, and finish it when you're done.

    my $timer = $statsd->timer("foo.bar");
    do_work();
    $timer->finish;

=head2 Setting Metric Later

In some situations, you might not know the metric you want to record until
after you've begun work. In these cases, you can override the metric name
with the C<metric> accessor or by providing it as an argument to finish.

Overriding:

    my $timer = $statsd->timer("item.fetch");
    my $item = $cache->get("blah");
    if ($item) {
        $timer->metric("item.fetch_from_cache");
    } else {
        $item = get_it_the_long_way();
    }
    $timer->finish;

Providing at the end:

    my $timer = $statsd->timer;
    my $animal = farm_animal();
    if ($animal->is_ungulate) {
        $animal->ruminate;
        $timer->finish(metric => "ruminate");
    } else {
        $animal->animate;
        $timer->finish(metric => "animate");
    }

=head2 Using Checkpoints

Checkpoints make it easier to break down a multi-step process by creating a
timer, calling C<checkpoint> zero or more times, and then C<finish> at the
end.

    my $timer = $statsd->timer;
    my $widget = Widget->new;
    $timer->checkpoint(metric => "widget.construct");
    $widget->rotate(degrees => 45);
    $timer->checkpoint(metric => "widget.rotate");
    $widget->scale(size => 2);
    $timer->finish(metric => "widget.scale");

C<checkpoint> and C<finish> default to C<< since => 'previous' >>, which
means to measure the time since the previous checkpoint (if there was one),
or the time since the timer started. If you specify C<< since => 'start' >>
instead, the measurement will always be the time since the timer started.
This gives you a basic form of overlapping timers, which is useful if you
want to break down a process into separate steps, but also record the total
time for all of the steps in another metric. We could change the last two
lines of the previous example to:

    $timer->checkpoint(metric => "widget.scale");
    $timer->finish(metric => "widget.total");

to record the total time as C<widget.total>.

=head2 If you don't know which step is the last

Call C<< $timer->checkpoint >> every time you want to record a timing, and
then call C<< $timer->cancel >> when you know you're done with all of the
steps, so that the destructor won't warn.
