#!perl
use strict;
use warnings;
use Test::More;

use IO::Socket;
my $sock = IO::Socket::INET->new(
  LocalPort => 8125,
  Proto => "udp",
  Blocking => 0,
) or plan skip_all => "Can't listen UDP";

use_ok 'Net::Statsd::Client';

sub sends_ok (&@) {
  my ($code, $pattern, $desc) = @_;
  my $ok = eval {
    $code->();
    1;
  };
  if (!$ok) {
    diag "Died: $@";
    fail $desc;
    return;
  }
  my $buf;
  my $ret = recv $sock, $buf, 8192, 0;
  if (!defined $ret) {
    diag "recv failed with $!";
    fail $desc;
    return;
  }
  like $buf, $pattern, $desc;
}

my $client = Net::Statsd::Client->new;

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
