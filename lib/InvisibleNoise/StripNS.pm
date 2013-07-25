package InvisibleNoise::Plus;

## GreyNoise/WhiteNoise used TAL templates, this strips the XML namespaces.

use v5.12;
use Moo;
use utf8::all;

has engine => (is => 'ro', required => 1);

sub post_process {
  my ($self, $content) = @_;
  $content =~ s/\s*xmlns\:\w+=".*?"//g;
  return $content;
}

1;
