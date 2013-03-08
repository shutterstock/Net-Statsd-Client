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
  my $socket = _socket($host, $port);
  my $sent = send($socket, $message, 0);
  if (!defined $sent) {
    if (!$CONN{"$host:$port"}{SEND_ERROR} ++) {
      Carp::carp "Error sending to $host:$port: $!";
    }
  }
  return $sent;
}

sub send_buffered {
  my ($host, $port, $message) = @_;
  my $dest = "$host:$port";
  my $mtu = $CONN{$dest}{MTU};
  $message .= "\x0a";
  return send_raw($host, $port, $message) unless $mtu;
  my $len = length($message);
  if ($CONN{$dest}{QUEUE} && length($CONN{$dest}{QUEUE}) + $len > $mtu) {
    flush($host, $port);
  }
  if ($len > $mtu) {
    Carp::carp "Message over $mtu bytes may be dropped";
  }
  $CONN{$dest}{QUEUE} .= $message;
  return 1;
}

sub send {
  my ($host, $port, $message, $sample_rate) = @_;
  $sample_rate = 1 unless defined $sample_rate;
  if ($sample_rate == 1) {
    return send_buffered($host, $port, $message);
  } else {
    if (rand() < $sample_rate) {
      $message = $message . '|@' . $sample_rate;
      return send_buffered($host, $port, $message);
    }
  }
  return "0 but true";
}

sub flush {
  my ($host, $port) = @_;
  my $dest = "$host:$port";
  return unless defined $CONN{$dest}{QUEUE} && length $CONN{$dest}{QUEUE};
  my $ret = send_raw($host, $port, $CONN{$dest}{QUEUE});
  if ($ret) {
    $CONN{$dest}{QUEUE} = "";
  }
  return $ret;
}

sub set_mtu {
  my ($host, $port, $mtu) = @_;
  my $dest = "$host:$port";
  $CONN{$dest}{MTU} = $mtu;
}

1;
