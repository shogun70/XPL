#!/usr/bin/perl

# FIXME Currently every source file must have a <script> element (even if empty)
# The script element is wrapped here, and called at run-time.
# Some source files just need to include other files and shouldn't need a script element.

use strict 'refs';
use warnings;

{
package XPLBuilder;

use URI;
use Cwd;

use LWP::UserAgent;
use HTTP::Request;
our $userAgent = LWP::UserAgent->new;
$userAgent->agent("XPL/0.1 ");

use XML::LibXML;


sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	$self->{path} = getcwd();
	$self->{contexts} = {};
	$self->{params} = {};
	$self->{diskCache} = {};
	$self->{memCache} = {};
	$self->{makeDepend} = 0;
	return $self;
}


sub resolve() {
	my $self = shift;
	my $href = shift;
	my $baseHref = shift;
	my $pathUri = URI->new("file://localhost" . $self->{path} . "/");
	my $baseUri = URI->new_abs($baseHref, $pathUri);
	my $uri = URI->new_abs($href, $baseUri);
	my $relUri = $uri->rel($pathUri);
	return $relUri->as_string;
}

sub loadURL() {
	my $self = shift;
	my $uri = shift;
	my $file = $self->{memCache}->{$uri};
	$file && return $file;
	my $directURI = $self->{diskCache}->{$uri} || $uri;
	my $fetchURI = URI->new_abs($directURI, "file://localhost" . $self->{path} . "/")->as_string;
	my $rq = HTTP::Request->new(GET => $fetchURI);
	$file = $userAgent->request($rq);
	($file->is_success) or die "Couldn't retrieve " . $uri . " --> " . $file->status_line, "\n";
	$self->{memCache}->{$uri} = $file;
	return $file;
}

sub preprocess() {
	my $self = shift;
	my $href = shift || $self->{href};
	my $file = $self->loadURL($href);
	my $parser = XML::LibXML->new();
	my $document = $parser->parse_string($file->content);
	my $context = $self->createContext($document, $href);
	$self->{contexts}->{$href} = $context;
	foreach my $requireHref (@{$context->{requiredContexts}}) {
		$self->{contexts}->{$requireHref} || $self->preprocess($requireHref);
	}
}

sub write() {
	my $self = shift;
	my $href = $self->{href};
	while (<main::DATA>) {
		print;
	}
	$self->process($href);
	print <<"";
Meeko.stuff.xplSystem.init();

}

sub process() {
	my $self = shift;
	my $href = shift || $self->{href};
	my $context = $self->{contexts}->{$href};
	$context->{written} && return;
	foreach my $requireUri (@{$context->{requiredContexts}}) {
		$self->process($requireUri);
	}
	$self->writeContext($context);
	$context->{written} = 1;
}

sub expandParams() {
	my $self = shift;
	my ($text) = @_;
	for my $name (keys %{$self->{params}}) {
		my $value = $self->{params}->{$name};
		$text =~ s/\{$name\}/$value/eg;
	}
	return $text;
}

sub createContext() {
	my $self = shift;
	my $document = shift;
	my $documentURI = shift;
	my $context = {
		documentURI => $documentURI,
		params => [],
		requiredContexts => [],
		prefetch => [],
		scripts => []
	};
	$context->{owner} = $document;
	
	my $node = $document->firstChild;
	while ($node) {
		(1 == $node->nodeType) and last;
		if (7 == $node->nodeType) {
			my $pi = XMLProcessingInstruction->new($node);
			($pi && $pi->target) or next;
			for ($pi->target) {
				/xpl-param/ && do {
					my $name = $pi->attributes->{name};
					my $value = $self->expandParams($pi->attributes->{value});
					push @{$context->{params}}, { name => $name, value => $value};
				};
				/xpl-require/ && do {
					my $requireHref = $self->expandParams($pi->attributes->{href});
					my $requireUri = $self->resolve($requireHref, $documentURI);
					push @{$context->{requiredContexts}}, $requireUri;
				};
				/xpl-prefetch/ && do {
					my $prefetchHref = $self->expandParams($pi->attributes->{href});
					my $prefetchUri = $self->resolve($prefetchHref, $documentURI);
					push @{$context->{prefetch}}, $prefetchUri;
				};
			}
		}
		$node = $node->nextSibling;
	}
	
	my $head = $document->getElementsByTagName("head")->[0];
	my $scriptElts = $head->getElementsByTagName("script");
	for my $script (@$scriptElts) {
		my $scriptSrc = $script->getAttribute("src");
		my $scriptUri = "";
		my $scriptText = $script->textContent . "\n";
		if ($scriptSrc) {
			$scriptText = "";
			my $scriptHref = $self->expandParams($scriptSrc);
			$scriptUri = $self->resolve($scriptHref, $documentURI);
		}
		push @{$context->{scripts}}, { src => $scriptUri, text => $scriptText };
	}
	
	return $context;
}

sub writeContext() {
	my $self = shift;
	my $context = shift;
	my $documentURI = $context->{documentURI};

print <<"";
Meeko.stuff.xplSystem.createContext("$documentURI");

	foreach my $prefetchUri (@{$context->{prefetch}}) {
		my $file = $self->loadURL($prefetchUri);
		$file && $file->{written} && next;
		my $text = $file->content;
		$text =~ s/\\/\\\\/g;
		$text =~ s/'/\\'/g;
		$text =~ s/\t/\\t/g;
		$text =~ s/\r/\\r/g;
		$text =~ s/\n/\\n/g;
		$file->{written} = 1;
		print <<"";
Meeko.stuff.xplSystem.prefetch["$prefetchUri"] = '$text';

	}
	my @requireList = ();
	foreach my $requireUri (@{$context->{requiredContexts}}) {
		push @requireList, "\t\"$requireUri\"";
	}
	my $requireText = join ",\n", @requireList;
	print <<"";
Meeko.stuff.xplSystem.contexts["$documentURI"].requiredContexts = [
$requireText
];

	my @paramsList = ();
	foreach my $param (@{$context->{params}}) {
		my $name = $param->{name};
		my $value = $param->{value};
		push @paramsList, "\t$name: \"$value\"";
	}
	my $paramsText = join ",\n", @paramsList;
	print <<"";
Meeko.stuff.xplSystem.contexts["$documentURI"].params = { 
$paramsText
};

	my $scriptText = "";
	foreach my $script (@{$context->{scripts}}) {
		my $scriptUri = $script->{src};
		if ($scriptUri) {
			my $file = $self->loadURL($scriptUri);
			$scriptText .= $file->content;
		}
		else {
			$scriptText .= $script->{text};
		}
	}
	print <<"";
Meeko.stuff.xplSystem.contexts['$documentURI'].wrappedScript = function() {
var xplSystem = Meeko.stuff.xplSystem;
var xplContext = xplSystem.contexts['$documentURI'];
var logger = xplContext.logger;
$scriptText;
}

}

} # end XPLBuilder package

{
	
package XMLProcessingInstruction;

sub new {
	my $class = shift;
	my $node = shift;
	($node && 7 == $node->nodeType) or die "Cannot create XMLProcessingInstruction interface";
	my $self = {};
	bless($self, $class);
	$self->{owner} = $node;
	return $self;
}


sub target { return $_[0]->{owner}->nodeName; }
sub data { return $_[0]->{owner}->getData; }
sub attributes {
	my $self = shift;
	my $data = $self->{owner}->getData;
	my %result = $data =~ /(\w+)="([^"]*)"/g;
	return \%result;
}

} # end XMLProcessingInstruction

my $usage = "xpl [--disk-cache uri fname] [--param name value] [--make-depend] file\n";
my $href;

my $xplBuilder = new XPLBuilder;
my $n = scalar @ARGV;

for (my $i=0; $i<$n; $i++) {
	my $arg = $ARGV[$i];
	if ("--help" eq $arg || "-?" eq $arg) {
		print STDERR $usage;
		exit 1;
	}
	elsif ("--param" eq $arg) {
		my $name = $ARGV[++$i];
		my $value = $ARGV[++$i];
		$xplBuilder->{params}->{$name} = $value;
		next;
	}
	elsif ("--disk-cache" eq $arg) {
		my $uri = $ARGV[++$i];
		my $fname = $ARGV[++$i];
		$xplBuilder->{diskCache}->{$uri} = $fname;
		next;
	}
	elsif ("--path" eq $arg) {
		my $uri = $ARGV[++$i];
		$xplBuilder->{path} = $uri;
		next;
	}
	elsif ("--make-depend" eq $arg) {
		$xplBuilder->{makeDepend} = 1;
	}
	elsif ($arg =~ /^-/) {
		print STDERR "Illegal option " . $arg . "\n" . "Usage:" . $usage;
		exit 1;
	}
	
	else {
		if (!$xplBuilder->{href}) { $xplBuilder->{href} = $arg; }
		else {
			print STDERR "Cannot process more than one file.\nUsage: " . $usage;
			quit();
		}
	}
}

$xplBuilder->preprocess();
if ($xplBuilder->{makeDepend}) { die "--make-depend option not supported"; }
else { $xplBuilder->write(); }

__DATA__
