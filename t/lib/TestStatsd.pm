package TestStatsd;

use Test::More;
use Exporter 'import';
our @EXPORT = qw(sends_ok);

sub sends_ok (&@) {
  my ($code, $client, $pattern, $desc) = @_;
  my $sent;

  my $ok = eval {
    no warnings 'redefine';
    local *Etsy::StatsD::_send_to_sock = sub {
      $sent .= $_[1];
    };
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

