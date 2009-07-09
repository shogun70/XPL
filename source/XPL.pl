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

# resolve(href, baseHref)
# 1. create a file:// url from the working-directory -> pathUri
# 2. if baseHref is relative then create absolute-url using pathUri -> baseUri
# 3. if href is relative then create absolute-url using baseUri -> uri
# 4. if href is a file:// url then create a relative-url relative to pathUri -> relUri
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

# loadURL(uri)
# load an absolute-url
# 1. if already loaded (memCache) then return 
# 2. if command-line-options say it is cached on disk (diskCache) then resolve to file://...
# 3. fetch with HTTP::Request
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

# preprocess(href)
# load href and extract dependency info (requiredContexts)
sub preprocess() {
	my $self = shift;
	my $href = shift || $self->{href};
	my $file = $self->loadURL($href);
	my $parser = XML::LibXML->new();
	my $document = $parser->parse_string($file->content);
	my $context = $self->createContext($document, $href);
	$self->{contexts}->{$href} = $context;
	foreach my $requireHref (@{$context->{requiredContexts}}) {
		$self->preprocess($requireHref) unless $self->{contexts}->{$requireHref};
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
	
	my $head = $document->getElementsByTagName("head")->[0];

	NODE: for (my $node=$head->firstChild; $node; $node=$node->nextSibling) {
		(1 != $node->nodeType) and next;
		if ("meta" eq $node->localname) {
			my $name = $node->getAttribute("name");
			my $value = $self->expandParams($node->getAttribute("content"));
			push @{$context->{params}}, { name => $name, value => $value};
			next NODE;
		}
		if ("link" eq $node->localname) {
			my $rel = $node->getAttribute("rel");
			if ("prefetch" eq $rel) {
				my $prefetchHref = $self->expandParams($node->getAttribute("href"));
				my $prefetchUri = $self->resolve($prefetchHref, $documentURI);
				push @{$context->{prefetch}}, $prefetchUri;
				next NODE;
			}
			next NODE;
		}
		if ("script" eq $node->localname) {
			my $type = $node->getAttribute("type") || "";
			if ("text/html" eq $type or "application/xml+xhtml" eq $type) {
				my $requireHref = $self->expandParams($node->getAttribute("src"));
				(scalar @{$context->{scripts}}) and die "Script contexts must precede all scripts: src=$requireHref\n";
				my $requireUri = $self->resolve($requireHref, $documentURI);
				push @{$context->{requiredContexts}}, $requireUri;
				next NODE;
			};
			if ("text/javascript" eq $type or "" eq $type) {
				my $scriptSrc = $node->getAttribute("src");
				my $scriptUri = "";
				my $scriptText = $node->textContent . "\n";
				if ($scriptSrc) {
					$scriptText = "";
					my $scriptHref = $self->expandParams($scriptSrc);
					$scriptUri = $self->resolve($scriptHref, $documentURI);
				}
				push @{$context->{scripts}}, { src => $scriptUri, text => $scriptText };
				next NODE;
			};
			next NODE;
		}
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
