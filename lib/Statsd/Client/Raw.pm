package Statsd::Client::Raw;
use strict;
use warnings;

# ABSTRACT: Low-level StatsD UDP client
# VERSION
# AUTHORITY

use IO::Socket;
use Carp ();

my %CONN;

sub _socket {
  my ($host, $port) = @_;
  my $dest = "$host:$port";
  return $CONN{$dest}{SOCK} if $CONN{$dest}{SOCK};
  my $sock = IO::Socket::INET->new(
    Proto     => 'udp',
    PeerAddr  => $host,
    PeerPort  => $port,
  );
  if ($sock) {
    $CONN{$dest}{SOCK} = $sock;
    return $sock;
  } else {
    if (!$CONN{$dest}{CONNECT_ERROR} ++) {
      Carp::carp "Error connecting to $dest: $!";
      return;
    }
  }
}

sub send_raw {
  my ($host, $port, $message) = @_;
  $message .= "\x0a";
  my $socket = _socket($host, $port);
  my $sent = send($socket, $message, 0);
  if (!defined $sent) {
    if (!$CONN{"$host:$port"}{SEND_ERROR} ++) {
      Carp::carp "Error sending to $host:$port: $!";
    }
  }
  return $sent;
}

sub send {
  my ($host, $port, $message, $sample_rate) = @_;
  $sample_rate = 1 unless defined $sample_rate;
  if ($sample_rate == 1) {
    return send_raw($host, $port, $message);
  } else {
    if (rand() < $sample_rate) {
      $message = $message . '|@' . $sample_rate;
      return send_raw($host, $port, $message);
    }
  }
}

sub flush {
  1
}

1;
