package InvisibleNoise;
# ABSTRACT: Build static pages.

use v5.12;
use version 0.77;
our $VERSION = 'v1.0.0';

## We leverage several libraries.
use Moo;
use utf8::all;
use XML::LibXML;
use JSON 2.0;
use File::Path qw(make_path);
use File::Basename;
use UNIVERSAL::require;
use Perl6::Slurp;
use Webtoo::Template::TT;
use Encode;

has conffile => (is => 'ro',   required => 1);           ## The config file.
has conf     => (is => 'lazy');                          ## A hash of options.
has plugins  => (is => 'ro',   default  => sub { {} });  ## Loaded plugins.
has renderer => (is => 'lazy', handles  => ['render']);  ## A rendering engine.

## Build the default configuration.
sub _build_conf {
  my ($self) = @_;
  decode_json(encode("utf8", slurp($self->conffile)));
}

## Build the default renderer.
sub _build_renderer {
  my ($self) = @_;
  my $path = dirname($self->conf->{template});
  return Webtoo::Template::TT->new(path => $path);
}

## Load a configuration file.
## Replaces the existing ones.
sub load_config {
  my ($self, $file) = @_;
  $self->{conffile} = $file;
  $self->{conf} = decode_json(encode("utf8", slurp($file)));
}

## Spit out a file.
sub output_file {
  my ($self, $file, $content) = @_;
  open (my $fh, '>', $file);
  say $fh $content;
  close $fh;
  say STDERR " » Generated '$file'";
}

## Build a page.
sub build_page {
  my ($self, $file) = @_;

  my $page = $self->get_page($file);
  my $content = $self->parse_page($page);

  my $outdir = $self->conf->{output};
  if (! -d $outdir) {
    make_path($outdir);
  }

  my $ext = $self->conf->{extension} // '.html';

  my $outfile = $outdir . '/' . $page->{basename} . $ext;

  $self->output_file($outfile, $content);
}

## work around the DTD limitations of getElementById().
sub getById {
  my ($doc, $id) = @_;
  return ($doc->findnodes("//*[\@id = '$id']"))[0];
}

## Get a page given a specific filename.
sub get_page {
  my ($self, $file) = @_;

  my ($basename, $folder, $ext) = fileparse($file, qr/\.[^.]*/);

  my $page = {
    'file'     => $file,
    'basename' => $basename,
    'ext'      => $ext,
    'folder'   => $folder,
    'data'     => {},
  };

  if (-f $file) {
    my $ftype = lc($ext);
    if ($ftype eq '.xml' || $ftype eq '.html') {
      my $parser = XML::LibXML->new();
      my $xml = $parser->parse_file($file);
      my $metadata = {};
      my $node = getById($xml, 'metadata');
      if (defined $node) {
        my $nodetext = $node->textContent;
        if ($nodetext) {
          $metadata = decode_json($nodetext);
        }
        $node->unbindNode();
      }

      $page->{xml}  = $xml;
      $page->{data} = $metadata;
    }
    elsif ($ftype eq '.json') {
      $page->{data} = decode_json(encode("utf8", slurp($file)));
    }
    else {
      die "Sorry, unsupport page type: '$ftype'.";
    }
  }
  else {
    $page->{nofile} = 1;
  }
  return $page;
}

## Parse a page, and return the content.
sub parse_page {
  my ($self, $page) = @_;

  my @plugins;
  if (exists $self->conf->{plugins}) {
    push @plugins, @{$self->conf->{plugins}};
  }

  if (exists $page->{data}->{plugins}) {
    push @plugins, @{$page->{data}->{plugins}};
  }

  for my $module (@plugins) {
    my $plugin = $self->get_plugin($module);
    if ($plugin->can('pre_process'))
    {
      $plugin->pre_process($page);
    }
  }

  my $template = basename($self->conf->{template});

  my $parsedata = {
    'config'   => $self->conf,         ## The selected configuration.
    'page'     => $page->{data},       ## The page meta data.
    'pageinfo' => $page,               ## The page information object.
    'engine'   => $self,               ## This engine itself.
  };

  if (exists $page->{content})
  { ## We include a special template variable called 'pagecontent' that
    ## contains the HTML page content to be included, if applicable.
    $parsedata->{pagecontent} = $page->{content};
  }
  elsif (exists $page->{xml}) {
    ## If the XML is set, we render it into a string for use as the page
    ## content. This is only used if the 'content' is not set.
    $parsedata->{pagecontent} = $page->{xml}->toStringHTML();
  }

  my $output = $self->render($template, $parsedata); 

  for my $module (@plugins) {
    my $plugin = $self->get_plugin($module);
    if ($plugin->can('post_process')) {
      $output = $plugin->post_process($output);
    }
  }

  return $output;
}

## Get a plugin, handling loading and initialization automatically.
sub get_plugin {
  my ($self, $module) = @_;

  if (exists $self->plugins->{$module}) {
    return $self->plugins->{$module};
  }

  $module->require or die "Could not load plugin '$module': $@";

  my $plugin = $module->new( engine => $self )
    or die "Could not initialize plugin '$module': $@";

  $self->plugins->{$module} = $plugin;
  return $plugin;
}

1; ## The end.
