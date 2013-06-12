#!perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use TestStatsd;

use_ok 'Net::Statsd::Client';

my $client = Net::Statsd::Client->new;

sends_ok { $client->increment("foo1") } $client, qr/foo1:1\|c/, "increment";
sends_ok { $client->decrement("foo2") } $client, qr/foo2:-1\|c/, "decrement";
sends_ok { $client->update("foo3", 42) } $client, qr/foo3:42\|c/, "update";
sends_ok { $client->timing_ms("foo4", 1) } $client, qr/foo4:1\|ms/, "timing";
sends_ok {
  my $timer = $client->timer("foo5");
  sleep 1;
  $timer->finish;
} $client, qr/foo5:[\d\.]+\|ms/, "timer";

done_testing;
