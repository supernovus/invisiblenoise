package InvisibleNoise::PageTag;

## The <page> tag as used in earlier *Noise engines must be turned into
## something that can be usable directly in a web page.

use v5.12;
use Moo;

has engine => (is => 'ro', required => 1);

sub pre_process {
  my ($self, $page) = @_;
  if (exists $page->{xml} && $page->{xml}->nodeName == 'page') {
    $page->{xml}->setNodeName('div');
    $page->{xml}->setAttriute('id', 'page_content');
  }
}

1;
