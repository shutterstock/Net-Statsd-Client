#!perl
use strict;
use warnings;

package t::Mock::Socket;

sub TIEHANDLE {
  my ($class, $target) = @_;
  return bless { target => $target }, $class;
}

sub PRINT {
  my $self = shift;
  my $delim = defined($,) ? $, : "";
  my $terminator = defined($\) ? $\ : "";

  ${ $self->{target} } .= join($delim, @_) . $terminator;
}

package main;

use Test::More;

use_ok 'Net::Statsd::Client';

my $client = Net::Statsd::Client->new;

sub sends_ok (&@) {
  my ($code, $pattern, $desc) = @_;
  my $sent;

  my $ok = eval {
    local *MOCKET;
    tie *MOCKET, 't::Mock::Socket', \$sent;
    local $client->{statsd}{socket} = \*MOCKET;
    $code->();
    1;
  };
  if (!$ok) {
    diag "Died: $@";
    fail $desc;
    return;
  }
  like $sent, $pattern, $desc;
}

sends_ok { $client->increment("foo1") } qr/foo1:1\|c/, "increment";
sends_ok { $client->decrement("foo2") } qr/foo2:-1\|c/, "decrement";
sends_ok { $client->update("foo3", 42) } qr/foo3:42\|c/, "update";
sends_ok { $client->timing_ms("foo4", 1) } qr/foo4:1\|ms/, "timing";
sends_ok {
  my $timer = $client->timer("foo5");
  sleep 1;
  $timer->finish;
} qr/foo5:[\d\.]+\|ms/, "timer";

done_testing;
