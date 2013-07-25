package InvisibleNoise::Plus;

## Compatibility with GreyNoise, Blacknoise, etc.

use v5.12;
use Moo;
use utf8::all;

has engine => (is => 'ro', required => 1);

sub post_process {
  my ($self, $content) = @_;
  $content =~ s/\+TAB\+/&nbsp;&nbsp;&nbsp;&nbsp;/gsm;
  $content =~ s/\+\+(\w+)\+\+/&$1;/gsm;
  $content =~ s/\+\+(#\d+)\+\+/&$1;/gsm;
  return $content;
}

1;
