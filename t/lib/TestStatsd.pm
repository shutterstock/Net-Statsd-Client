package TestStatsd::MockSocket;

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

package TestStatsd;

use Test::More;
use Exporter 'import';
our @EXPORT = qw(sends_ok);

sub sends_ok (&@) {
  my ($code, $client, $pattern, $desc) = @_;
  my $sent;

  my $ok = eval {
    local *MOCKET;
    tie *MOCKET, 'TestStatsd::MockSocket', \$sent;
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

