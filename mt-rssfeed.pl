# mt-rssfeed.pl
#
# Copyright 2002 Timothy Appnel. This code cannot be redistributed without
# permission from the author. (tima@mplode.com)

package MT::Plugin::RSSFeed;

use vars qw( $VERSION );
my $VERSION = '1.02';

# START MT-RSSFEED CONFIGURATION VARIABLES

# Set this variable if you using MySQL or want your RSS files cache 
# somewhere other then the DBM directory. The value must end with a /.
my $RSSFEED_DATA_DIR = "./rssfeed/";

# If you are running in an enviroment that uses a proxy for web 
# access, set this variable with the URL of the proxy server the 
# mt-rssfeed virtual browser should use. Don't forget the port.
# my $RSSFEED_BROWSER_PROXY = 'http://my.proxy.server.domain.name:port/';

# Used in conjunction with $RSSFEED_BROWSER_PROXY sets a list (array)
# of domains where the mt-rssfeed will *not* use proxy.
# my $RSSFEED_BROWSER_PROXY_BYPASS = ['localhost','127.0.0.1'];

# Variable to change the time in seconds that the mt-rssfeed browser
# will wait for a response to a specific request before giving up.
# If not specified, the default is 10 seconds.
# my $RSSFEED_BROWSER_TIMEOUT=10;

# END MT-RSSFEED CONFIGURATION VARIABLES

use MT::Template::Context;
use MT::ConfigMgr;
use MT::Util qw{ format_ts dirify decode_xml remove_html};

MT::Template::Context->add_container_tag(RSSFeed => sub { &_feed; });
MT::Template::Context->add_container_tag(RSSFeedItems => sub { &_hdlr_items; });
MT::Template::Context->add_container_tag(RSSFeedItemsExist => sub { &_hdlr_items_exist; });
MT::Template::Context->add_tag(RSSFeedCacheDate => sub { &_hdlr_feed_ts; });
MT::Template::Context->add_tag(RSSFeedURL => sub { &_hdlr_feed_url; });
MT::Template::Context->add_tag(RSSFeedTitle => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedLink => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedDescription => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedLanguage => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedItemCount => sub { &_hdlr_item_count; });
MT::Template::Context->add_tag(RSSFeedItemTitle => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedItemLink => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedItemDescription => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedItemDescriptionEncoded => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_container_tag(RSSFeedTitleExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedLinkExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedDescriptionExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedDescriptionEncodedExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedLanguageExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedItemsExist => sub { &_hdlr_items_exist; });
MT::Template::Context->add_container_tag(RSSFeedItemTitleExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedItemLinkExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedItemDescriptionExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedItemDescriptionEncodedExists => sub { &_hdlr_mapped_element_exists; });

# Image tags.
MT::Template::Context->add_container_tag(RSSFeedImage => sub { &_hdlr_image; });
MT::Template::Context->add_container_tag(RSSFeedImageExists => sub { &_hdlr_image_exists; });
MT::Template::Context->add_tag(RSSFeedImageURL => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedImageLink => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedImageTitle => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedImageDescription => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedImageHeight => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_tag(RSSFeedImageWidth => sub { &_hdlr_mapped_element; });
MT::Template::Context->add_container_tag(RSSFeedImageURLExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedImageLinkExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedImageTitleExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedImageDescriptionExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedImageHeightExists => sub { &_hdlr_mapped_element_exists; });
MT::Template::Context->add_container_tag(RSSFeedImageWidthExists => sub { &_hdlr_mapped_element_exists; });

# "Catch All" tags.
MT::Template::Context->add_tag(RSSFeedElement => sub { &_hdlr_element; });
MT::Template::Context->add_container_tag(RSSFeedElementExists => sub { &_hdlr_element_exists; });
MT::Template::Context->add_tag(RSSFeedItemElement => sub { &_hdlr_element; });
MT::Template::Context->add_container_tag(RSSFeedItemElementExists => sub { &_hdlr_element_exists; });

# Depreciated tags.
MT::Template::Context->add_container_tag(RSSFeedIfTitle => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfLink => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfDescription => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfLanguage => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfItems => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfItemTitle => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfItemLink => sub { &_hdlr_depreciated; });
MT::Template::Context->add_container_tag(RSSFeedIfItemDescription => sub { &_hdlr_depreciated; });

sub debug {
    my ($ctx,$msg,$mode) = @_;
	$mode=$mode?$mode:1;
	warn "mt-rssfeed debugging: $msg\n" if ($mode <= $ctx->stash('mt-rssfeed_debug'));
	# 0=no debugging messages
	# 1=debugging messages on (default mode of debug subroutine)
	# 2=verbose debugging messages on
}

sub _feed { 
	my($ctx,$args) = @_;
	my $url;
	my $file;
	require XML::RSS::LP;
	my $rss = new XML::RSS::LP;
	$ctx->stash('mt-rssfeed_current',$rss);

	# Store debugging info.
	$ctx->stash('mt-rssfeed_debug',$args->{debug}?$args->{debug}:0); #default to no debugging messages if not specified

	# Resolve feed source . mt-list if not file arg? else throw error.
	if (defined ($ctx->stash('mt-list_current')||$ctx->stash('current_mt-list'))) { # 'current_mt-list' is to depreciated from older versions of mt-list.
		$url = $ctx->stash('mt-list_current_item')||$ctx->stash('mt-list_current-item'); # 'mt-list_current-item' is to depreciated from older versions of mt-list.
		debug($ctx,'In list '.($ctx->stash('mt-list_current')||$ctx->stash('current_mt-list'))); 
	} elsif ($args->{var}) {
		$url=$ctx->{__stash}{vars}{$args->{var}};
		debug($ctx,'Using the value of '.$args->{var});
	} else {
		$ctx->error("MTRSSFeed requires a 'file' or 'var' attribute or must be used in the context of an MTListLoop.") unless ($url = $args->{file});
	}
	$ctx->stash('mt-rssfeed_current_url',$url);
	# Determine cache file name.
	my $c = MT::ConfigMgr->instance;
	if (defined($RSSFEED_DATA_DIR)) { $file=$RSSFEED_DATA_DIR.'rss.'.dirify($url); }
	elsif ($c->ObjectDriver eq "DBM") {
		$file=$c->DataSource.'/rss.'.dirify($url); } 
	else { $ctx->error("mt-rssfeed: The RSS data directory has not been configured."); return ''; }
	$ctx->stash('mt-rssfeed_current_cache_file',$file);
	$ctx->stash('mt-rssfeed_cache_file_umask',oct $c->HTMLUmask);
	# To GET or not to GET? Then parse it.
	if ($url=~ /^http:/i) {
		if (my $content=_get_feed($ctx,$url)) { #'<rss><channel><title>hello world</title><item><title>foo</title></item></channel></rss>') {  
			debug($ctx,"fetched $url");
			if ($content) {
				debug($ctx,"parsing, then updating the cache with $url.");
				eval { $rss->parse($content); };
				if ($@) { warn 'mt-rssfeed: ' . $@ . $url; return ''; }
				_cache_file($ctx,$rss);
			} else { warn "mt-rssfeed: could not GET $url."; return '';}
		} else {
			debug($ctx,"Reading in $file and parsing");
			if (-e $file) {
				eval { $rss->parsefile($file); };
				if ($@) { warn $@ . 'mt-rssfeed cache file: ' . $file; return ''; }
			} else { return ''; }
		}
	} else { 
		$ctx->error("$url is an illegal file URL. Only the http:// protocol is supported.");
	}

	$ctx->stash('mt-rssfeed_current_default_namespace',$rss->expand_ns_prefix('#default'));
	
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	defined(my $out = $builder->build($ctx,$tokens)) or return '';
	return $out;
}

sub _hdlr_feed_ts {
	my ($ctx,$args) = @_;
	my @ts = (-e $ctx->stash('mt-rssfeed_current_cache_file')) ?
		localtime((stat($ctx->stash('mt-rssfeed_current_cache_file')))[9]):
		localtime(time);
	my $date = sprintf("%04d%02d%02d%02d%02d%02d",$ts[5]+1900,$ts[4]+1,$ts[3],$ts[2],$ts[1],$ts[0]);
	return format_ts($args->{format},$date,$ctx->{blog});
}

sub _hdlr_feed_url { return $ctx->stash('mt-rssfeed_current_url'); }

sub _hdlr_items {
	my($ctx,$args) = @_;
    my $rss = $ctx->stash('mt-rssfeed_current');
	defined($rss->{'items'}) || return '';
    my $items = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
	
	my $end = defined($args->{lastn}) && ($#{ $rss->{'items'} } > $args->{lastn}) ? $args->{lastn}-1 : $#{ $rss->{'items'} };
	#debug($ctx,"Displaying items 0 to $end.");
	foreach (0..$end) {
		$ctx->stash('mt-rssfeed_current_item',$rss->{'items'}->[$_]);
		defined(my $out = $builder->build($ctx, $tokens)) or return '';
        $items .= $out;
	}
	return $items;
}

sub _hdlr_items_exist {
	my($ctx,$args) = @_;
	my $state=defined($args->{state})?$args->{state}:1;

	# use _hdlr_item_count as a utility rather then tag handler
	if (($state && ! _hdlr_item_count($ctx)) || (!$state && _hdlr_item_count($ctx))) {
		debug($ctx,$ctx->stash('tag') . " does not exist.",2); 
		return ''; }
	else { 
		debug($ctx,$ctx->stash('tag') . " exists.",2);
		my $builder = $ctx->stash('builder');
		my $tokens = $ctx->stash('tokens');
		defined(my $out = $builder->build($ctx,$tokens)) or return '';
		return $out;
	} 
}

sub _hdlr_item_count { return defined($_[0]->stash('mt-rssfeed_current')->{'items'})?$#{ $_[0]->stash('mt-rssfeed_current')->{'items'} }+1:0; }

sub _hdlr_image {
	my $ctx=shift;
	# this tag is a placeholder and organizer.
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	defined(my $out = $builder->build($ctx,$tokens)) or return '';
	return $out;
}

sub _hdlr_image_exists {
	my($ctx,$args) = @_; ;
	my $state=defined($args->{state})?$args->{state}:1;
	my $value=$ctx->stash('mt-rssfeed_current')->{'image'};
	if (($state && ! defined($value)) || (!$state && defined($value))) { 
		debug($ctx,$ctx->stash('tag') . " does not exist.",2); 
		return '' }
	else {
		debug($ctx,$ctx->stash('tag') . " exists.",2);
		my $builder = $ctx->stash('builder');
		my $tokens = $ctx->stash('tokens');
		defined(my $out = $builder->build($ctx,$tokens)) or return '';
		return $out;
	} 
}

# This isn't much, but is necessary plumbing to support for other namespaces 
# and tag mappings are added in future versions.
{
	my %tag_map= ( 
		title=>['title'],
		'link'=>['link'],
		description=>['description'],
		descriptionencoded=>['content:encoded','description'],
		language=>['dc:language','language'], 
		itemtitle=>['title'], 
		itemlink=>['link'],
		itemdescription=>['description'],
		itemdescriptionencoded=>['content:encoded','description'],
		imagetitle=>['title'], 
		imagelink=>['link'],
		imagedescription=>['description'],
		imageurl=>['url'], 
		imageheight=>['height'],
		imagewidth=>['width'] );

	# Ordered newest to oldest. Always end in a /. The default namespace is 
	# determined on a feed by feed basis.
	my %prefix_table = ( 
		dc=>['http://purl.org/dc/elements/1.1/'],
		content=>['http://purl.org/rss/1.0/modules/content/']
	);

	sub _hdlr_mapped_element {
		my ($ctx,$args)=@_;
		my $ns;
		my ($ref,$tag)= _get_tag_ref($ctx);

		# resolve namespace. we're making some assumptions since this is 
		# entirely under our control.
		foreach (@{ $tag_map{$tag} }) {
			# not in default namespace
			if ($tag=~s/^([a-z_][a-z0-9.-_]*):([a-z_][a-z0-9.-_]*)$/$2/) {
				$ns=$prefix_table{$1}; 
				debug($ctx,"$tag in $ns namespace.",2); }
			# assume its in the default namespaceif defined.
			elsif (defined($ctx->stash('mt-rssfeed_current_default_namespace'))) { 
				$ns=$ctx->stash('mt-rssfeed_current_default_namespace'); 
				debug($ctx,"$tag in default namespace $ns.",2); }
			else { debug($ctx,"$tag is not in a namespace defined.",2); }
			if (defined($ref->{$ns.$tag})) {
				my $value=$ref->{$ns.$tag};
				require MT;
				if ($tag=~/^description/) {
					# entity encoding HTML is evil!!!
					# take our best shot at working with it.
					$value=($value=~/&amp;lt;/ && MT->VERSION<'2.50')?_decode_xml_fallback($value):decode_xml($value);						
					remove_html($value) unless ($tag=~/encoded$/)
				}
				# deal with 2.21's decode_xml bug
				return MT->VERSION<'2.50'?_decode_xml_fallback($value):decode_xml($value);
			}
		}
		return '';
	}

}

sub _hdlr_element {
	my($ctx,$args) = @_; 
	$ctx->error("MT".$ctx->stash('tag')." requires a 'name' argument.") unless keys %$args && defined($args->{name});
	my ($ref)=_get_tag_ref($ctx);
	return (defined($ref->{$args->{name}}) && length($ref->{$args->{name}})) ?$ref->{$args->{name}}:''; # name is namespace qualified element name
}

sub _hdlr_mapped_element_exists {
	my($ctx,$args) = @_; ;
	my $state=defined($args->{state})?$args->{state}:1;
	# use _hdlr_mapped_element as a utility rather then tag handler
	if (($state && ! _hdlr_mapped_element($ctx)) || (!$state && _hdlr_mapped_element($ctx))) {
		debug($ctx,$ctx->stash('tag') . " does not exist.",2); 
		return ''; }
	else { 
		debug($ctx,$ctx->stash('tag') . " exists.",2);
		my $builder = $ctx->stash('builder');
		my $tokens = $ctx->stash('tokens');
		defined(my $out = $builder->build($ctx,$tokens)) or return '';
		return $out;
	} 
}
	
sub _hdlr_element_exists { 
	my($ctx,$args) = @_; 
	$ctx->error("MT".$ctx->stash('tag')." requires a 'name' argument.") unless keys %$args && defined($args->{name});
	my $state=defined($args->{state})?$args->{state}:1;
	my ($ref)=_get_tag_ref($ctx); 
	if ($state && ! $ref->{$args->{name}} || (!$state && $ref->{$args->{name}})) { # name is namespace qualified element name
		debug($ctx,$ctx->stash('tag') . " does not exist.",2); 
		return ''; }
	else {
		debug($ctx,$ctx->stash('tag') . " exists.",2);
		my $builder = $ctx->stash('builder');
		my $tokens = $ctx->stash('tokens');
		defined(my $out = $builder->build($ctx,$tokens)) or return '';
		return $out;
	} 
}

sub _get_tag_ref {
	my $ctx=shift;
	$ctx->stash('tag')=~/RSSFeed(Item|Image)?((?:(?!Exist|Exists).)*)/x;
	my $group=lc(defined($1)?$1:'channel');
	my $name=lc($2);
	debug($ctx,"resolve tag name: ".$ctx->stash('tag')."-> $group, $name",2);
	if ($group eq 'image') {
		return $ctx->stash('mt-rssfeed_current')->{'image'},$name; }
	elsif ($group eq 'item') {
		return $ctx->stash('mt-rssfeed_current_item'),$name; }
	elsif ($group eq 'channel') {
		return $ctx->stash('mt-rssfeed_current')->{'channel'},$name; }	
	else { $ctx->error($ctx->stash('tag')." could not be resolved."); }
}


# Caching Utility Routines

sub _get_feed {
	my $ctx=shift;
	my $url=shift;
	require LWP::UserAgent;
	require HTTP::Request; 
	require HTTP::Response;
	require HTTP::Date;
    my $request = HTTP::Request->new(GET => $url);
	my $browser = LWP::UserAgent->new;
	$browser->agent("mt-rssfeed/$VERSION");
	$browser->timeout(defined($RSSFEED_BROWSER_TIMEOUT)?$RSSFEED_BROWSER_TIMEOUT:10);
	$browser->proxy(['http'], $RSSFEED_BROWSER_PROXY) if (defined $RSSFEED_BROWSER_PROXY);
    $browser->no_proxy( $RSSFEED_BROWSER_PROXY_BYPASS ) if (defined $RSSFEED_BROWSER_PROXY_BYPASS);
    $browser->env_proxy unless (defined($RSSFEED_BROWSER_PROXY) || defined($RSSFEED_BROWSER_PROXY_BYPASS));
	if (-e $ctx->stash('mt-rssfeed_current_cache_file')) {
		debug($ctx,"Cache file ".$ctx->stash('mt-rssfeed_current_cache_file')." was found and last modified".HTTP::Date::time2str($mtime));
		if(my($mtime) = (stat($ctx->stash('mt-rssfeed_current_cache_file')))[9]) {
			$request->header('If-Modified-Since' => HTTP::Date::time2str($mtime));
		}
	}
	debug($ctx,"\nREQUEST:\n\n".$request->as_string,2);
	my $response = $browser->request($request);
	debug($ctx,"\nRESPONSE:\n\n".$response->as_string,2);
	return $response->is_success?$response->content:undef;
}
	
sub _cache_file {
	my $ctx=shift;
	my $content=ref($_[0])?$_[0]->as_string():$_[0];
	my $file=$ctx->stash('mt-rssfeed_current_cache_file');
	debug($ctx,"Writing cache file $file");
	debug($ctx,"\nCaching the following content:\n\n$content",2);
	my $old=umask($ctx->stash('mt-rssfeed_cache_file_umask'));
    if (open (FH, "> $file")) {
		print FH $content;
		close FH;
		umask($old);
		return 1;
	} else {
		warn 'mt-rssfeed: ' . $ctx->stash('mt-rssfeed_current_url') . " could not be cached as $file.";
		umask($old);
		return 0;
	}
}


# Depreciated Tag Handling

sub _hdlr_depreciated {
	my $ctx=shift;
	my $newtag=$ctx->stash('tag');
	$newtag=~s/If(.*)/$1Exists/;
	warn "mt-rssfeed: " . $ctx->stash('tag') . " is depreciated. Try $newtag instead.";
	return '';
}

### Temporary fix to IE 5.5- inability to deal with the &apos; entity and 
### adding a facility to handle (evil) entity encoded HTML. Couldn't use the
### decode_xml routine in case version 2.21 is in use. Lifted from MT's Util.pm.
{
	my %Map = ('&' => '&amp;', '"' => '&quot;', '<' => '&lt;', '>' => '&gt;',
               '\'' => '&apos;');
    my %Map_Decode = reverse %Map;
    my $RE_D = join '|', keys %Map_Decode;

   sub _decode_xml_fallback {
       my($str) = @_;
       $str =~ s!($RE_D)!$Map_Decode{$1}!g;
       $str;
   }
}
###

1;

__END__

=head1 NAME

mt-rssfeed - A MovableType plugin for the insertion of RSS feed content into page layouts

=head1 SYNOPSIS

	<MTRSSFeed file="http://www.mplode.com/tima/xml/index.xml">
		<MTRSSFeedTitleExists>
			<MTRSSFeedLinkExists><a href="<$MTRSSFeedLink$>"></MTRSSFeedLinkExists>
			<$MTRSSFeedTitle$>
			<MTRSSFeedLinkExists></a></MTRSSFeedLinkExists><br />
		</MTRSSFeedTitleExists>
		<MTRSSFeedItemsExist>
		<ul>
		<MTRSSFeedItems lastn="5">
			<li><a href="<$MTRSSFeedItemLink$>">
				<MTRSSFeedItemTitleExists><$MTRSSFeedItemTitle$></MTRSSFeedItemTitleExists>
				<MTRSSFeedItemTitleExists state="0">
				<MTRSSFeedItemDescriptionExists>
					<$MTRSSFeedItemDescription$>
				</MTRSSFeedItemDescriptionExists>
				<MTRSSFeedItemDescriptionExists state="0">
					<$MTRSSFeedItemLink$>
				</MTRSSFeedItemDescriptionExists>
				</MTRSSFeedItemTitleExists>
			</a></li>
		</MTRSSFeedItems>
		</ul>
		</MTRSSFeedItemsExist>
		<MTRSSFeedTitleExists>Updated: <$MTRSSFeedCacheDate$></MTRSSFeedTitleExists>
		<br /><br />
	</MTRSSFeed>

=head1 DESCRIPTION

mt-rssfeed is a MovableType plugin that provides a series of tags for retrieving an RSS 
feed and inserting it into a MovableType template. RSS is an XML-based syntax for 
facilitating the exchange of resources in a lightweight fashion through the syndication 
of links to content. The RSSFeed plugin will automatically cache feeds and monitor their 
last modified status to improve performance and help reduce the load on the RSS feed host 
server.

The mt-rssfeed plugin utilizes a liberal RSS parser (I<XML::RSS::LP>) designed for use 
with this plugin. This parser is "liberal" in that it does not demand compliance to a 
specific RSS version and will attempt to store any tags it does not expect or understand. 
The parsers only requirement is that the file is well-formed XML and have some vague 
resemblance to the RSS format. I<XML::RSS::LP> will fall back on I<XML::Parser::Lite> if 
I<XML::Parser> cannot be found. This will help users who do not have I<XML::Parser> on 
their system and are unable to compile it. (I<XML::Parser::Lite> is a simple pure Perl 
module that does have limitations. Please consult the module's documentation for further 
information.)

We request you link back to the mt-rssfeed homepage to spread the news. Here is the HTML
for you:

	Syndicated using <a href="http://www.mplode.com/tima/files/mt-plugins/#mt-rssfeed">mt-rssfeed</a>

This software is provided free for personal or non-profit use. If you find this useful, 
it would be appreciated if you sent a donation for the amount which you feel the software 
is worth to you. http://www.mplode.com/tima/files/mt-plugins/#mt-rssfeed.

=head1 REQUIREMENTS

=over 4

=item * XML::RSS::LP (Included)
=item * XML::Parser (Recommended) or XML::Parser::Lite
=item * LWP::UserAgent
=item * HTTP::Request
=item * HTTP::Response
=item * HTTP::Date

=back

=head1 INSTALLATION

To install mt-rssfeed, simply place the I<mt-rssfeed.pl> file into your C<I<MovableTypeHome>/plugins/>
directory. If the plugins directory does not exist, you need to create it. 

The mt-rssfeed plugin uses the I<XML::RSS::LP> liberal RSS parser module. This module was 
developed specifically for use with the mt-rssfeed plugin. To install this module place 
the I<LP.pm> module in C<I<MovableTypeHome>/extlib/XML/RSS>. You may need to create some of
these directories during the installation process.

=head1 UPGRADING FROM VERSION 1.0

Version 1.01 of mt-rssfeed corrected a problem with the permission settings of cache file it
wrote. If you are going to use be using C<mt-rebuild-index.pl> you need to "flush" the cache.
To do this, first go to the directory that you defined in C<$RSSFEED_DATA_DIR> or the directory
where your BerkleyDB files are stored if a directory was not defined. Delete all C<rss.*> files.
B<BE SURE NOT TO DELETE ANY OTHER FILES. THEY COULD BE REALLY IMPORTANT -- LIKE YOUR MT DATABASE.>

No changes where made to I<XML::RSS::LP>.

=head1 CONFIGURATION

Depending on your system configuration you may need to configure one or more of the following configuration variables in the I<mt-rssfeed.pl> file.

=over 4

=item * $RSSFEED_DATA_DIR

Set this variable if you using MySQL or want your RSS files cache somewhere other then the DBM directory. (The value must end with a /.) If you are using the BerkeleyDB, by default the plugin will use the directory where MT writes its data. 

=item * $RSSFEED_BROWSER_PROXY

If you are running in an environment that uses a proxy for web access, set this variable with the URL of the proxy server the mt-rssfeed virtual browser should use. Don't forget the port.

=item * $RSSFEED_BROWSER_PROXY_BYPASS

Used in conjunction with C<$RSSFEED_BROWSER_PROXY> sets a list (array) of domains where the mt-rssfeed will B<not> use proxy.

=item * $RSSFEED_BROWSER_TIMEOUT

Variable to change the time in seconds that the mt-rssfeed browser will wait for a response to a specific request before giving up. If not specified, the default is 10 seconds.

=back

=head1 TAGS

The following tags are made available by the mt-rssfeed plugin.

=head2 Feed Tags

=over 4

=item * MTRSSFeed I<[file="url" var="MTvar_name" debug="0|1|2"]>

Container tag representing an RSS feed. All other mt-rssfeed plugin tags must be used inside this container. The C<file> attribute is required unless the tag set appears within the context of a MTListLoop tagset. C<debug> does not change the generation of the actual template, but will supply helpful debugging messages in the form of warnings during generation. The value of the C<debug> attribute may be 0 (messages off), 1 (messages on) or 2 (verbose messages on). The default is 0, messages off.

=item * MTRSSFeedCacheDate I<[format="mt-date-format"]>

Date the local cache file representing when the RSS feed was last updated. The C<format> attribute is optional using MovableType's date formatting syntax. Documentation can be found here: http://www.movabletype.org/docs/mtmanual_tags.html#date%20tag%20formats. If I<format> is not defined the plugin uses the default format configured by the MovableType weblog.

=item * MTRSSFeedURL

The URL of the RSS feed itself.

=item * MTRSSFeedTitle

The title of the RSS feed.

=item * MTRSSFeedTitleExists

A container tag that conditionally generates its contents based on the existence of the RSS feed's title. 

=item * MTRSSFeedLink

The URL of a web page associated to the RSS feed. 

=item * MTRSSFeedLinkExists

A container tag that conditionally generates its contents based on the existence of the RSS feed's associated URL. 

=item * MTRSSFeedDescription

An excerpt describing the producer and the contents of the RSS feed with all HTML stripped.

=item * MTRSSFeedDescriptionExists

A container tag that conditionally generates its contents based on the existence of the RSS feed's description. 

=item * MTRSSFeedDescriptionEncoded

An excerpt describing the producer and the contents of the RSS feed. Unlike C<MTRSSFeedDescription> HTML tags B<are not> stripped.

=item * MTRSSFeedDescriptionEncodedExists

A container tag that conditionally generates its contents based on the existence of the RSS feed's description. 

=item * MTRSSFeedLanguage

A value identifying the language of the content in the RSS feed. Values are defined by ISO 639 found here: http://www.oasis-open.org/cover/iso639a.html

=item * MTRSSFeedLanguageExists

A container tag that conditionally generates its contents based on the existence of the RSS feed's language. 

=back

=head2 Item Tags

=over 4

=item * MTRSSFeedItemsExist

A container tag that conditionally generates its contents based on the existence of any RSS feed items.

=item * MTRSSFeedItems I<[lastn="n"]>

A container tag that loops through an RSS feed's items and encapsulates other I<MTRSSFeedItemXXX> tags. The optional C<lastn> attribute indicates the maximum number of items, represented as a positive integer, to insert.  

=item * MTRSSFeedItemCount

The total number of items contained in the RSS feed.

=item * MTRSSFeedItemTitle 

The title of the current item of the RSS feed. The C<MTRSSFeedItemTitle> must be in the context of a C<MTRSSFeedItems> tagset. 

=item * MTRSSFeedItemTitleExists

A container tag that conditionally generates its contents based on the existence of a title in the current item of the RSS feed.

=item * MTRSSFeedItemLink 

The URL of the current item of the RSS feed. The C<MTRSSFeedItemLink> must be in the context of a C<MTRSSFeedItems> tagset. 

=item * MTRSSFeedItemLinkExists

A container tag that conditionally generates its contents based on the existence of a link in the current item of the RSS feed.

=item * MTRSSFeedItemDescription 

The description of the current item of the RSS feed with all HTML stripped. The C<MTRSSFeedDescription> must be in the context of a C<MTRSSFeedItems> tagset. 

=item * MTRSSFeedItemDescriptionExists

A container tag that conditionally generates its contents based on the existence of a description in the current item of the RSS feed.

=item * MTRSSFeedItemDescriptionEncoded 

The description of the current item of the RSS feed. Unlike C<MTRSSFeedDescription> HTML tags B<are not> stripped. The C<MTRSSFeedDescriptionEncoded> must be in the context of a C<MTRSSFeedItems> tagset. 

=item * MTRSSFeedItemDescriptionEncodedExists

A container tag that conditionally generates its contents based on the existence of a description in the current item of the RSS feed.

=back

=head2 Image Tags

=over 4

=item * MTRSSFeedImageExists

A container tag that conditionally generates its contents based on the existence of an image section in the RSS feed.

=item * MTRSSFeedImage

A container tag that encapsulates other I<MTRSSFeedItemXXX> tags. 

=item * MTRSSFeedImageURL

The URL of the image file for the RSS feed.

=item * MTRSSFeedImageURLExists

A container tag that conditionally generates its contents based on the existence of an image URL being defined in the RSS feed.

=item * MTRSSFeedImageHeight

The pixel height of the image for the RSS feed.

=item * MTRSSFeedImageHeightExists

A container tag that conditionally generates its contents based on the existence of an image height being defined in the RSS feed.

=item * MTRSSFeedImageWidth

The pixel width of the image for the RSS feed.

=item * MTRSSFeedImageURLExists

A container tag that conditionally generates its contents based on the existence of an image width being defined in the RSS feed.

=item * MTRSSFeedImageLink

A URL that a user should be sent to if they click on the image.

=item * MTRSSFeedImageLinkExists

A container tag that conditionally generates its contents based on the existence of an image link being defined in the RSS feed.

=item * MTRSSFeedImageTitle

A title for the image in the RSS feed.

=item * MTRSSFeedImageTitleExists

A container tag that conditionally generates its contents based on the existence of an image title being defined in the RSS feed.

=item * MTRSSFeedImageDescription

A description of the image file for the RSS feed.

=item * MTRSSFeedImageDescriptionExists

A container tag that conditionally generates its contents based on the existence of an image description being defined in the RSS feed.

=back

=head2 General Purpose Tags

=over

=item * MTRSSFeedElement I<name="namespace_qualified_tag_name">

A utility tag to access any data in the RSS feed C<channel> section that is not directly supported by the mt-rssfeed plugin tags. The required C<name> attribute identifies the RSS feed namespace qualified element to insert. For example C<name="http://purl.org/dc/elements/1.1/date"> would insert the date from the Dublin Core. mt-rssfeed assumes the default namespace if one has been omitted.

=item * MTRSSFeedElementExists I<name="namespace_qualified_tag_name">

A container tag that conditionally generates its contents based on the existence of a specific tag element. The required C<name> attribute identifies the RSS feed namespace qualified element to insert. For example C<name="http://purl.org/dc/elements/1.1/date"> would insert the date from the Dublin Core. mt-rssfeed assumes the default namespace if one has been omitted. This tagset will commonly be used in conjunction with C<MTRSSFeedElement>.

=item * MTRSSFeedItemElement I<name="namespace_qualified_tagname">

A utility tag to access any data in the current C<item> section of the RSS feed that is not directly supported by the mt-rssfeed plugin tags. The required C<name> attribute identifies the RSS feed namespace qualified element to insert. For example C<name="http://purl.org/rss/1.0/modules/slash/comments"> would insert the comment count from a feed using the mod_slash module. mt-rssfeed assumes the default namespace if one has been omitted.

=item * MTRSSFeedItemElementExists I<name="namespace_qualified_tag_name">

A container tag that conditionally generates its contents based on the existence of a specific tag element in the RSS feed's C<channel>. The required C<name> attribute identifies the RSS feed namespace qualified element to insert. For example C<name="http://purl.org/rss/1.0/modules/slash/comments"> would insert the comment count from a feed using the mod_slash module. mt-rssfeed assumes the default namespace if one has been omitted. This tagset will commonly be used in conjunction with C<MTRSSFeedItemElement>.

=back

=head2 Common Tag Attributes

=over 4

=item * state="0|1"

The C<state> is an optional attribute can be used with any tag ending in I<Exists>. It is a boolean value indicating whether the contained markup should be generated. Exists is 1. Does not exist is 0. The default is 1, exists.

=back

=head1 USING MT-RSSFEED WITH THE MT-LIST PLUGIN

In order to facilitate the display of multiple RSS feed sources using the same layout, mt-rssfeed has been 
designed to integrate with mt-list, a plugin for working with simple lists. The integration is made possible
by C<MTRSSFeed>'s awareness of being in a C<MTListLoop> context that it will use as a list of URLs to 
retrieve RSS feeds from. The following example illustrates the two plugins working in concert.

	<html><body>

	<MTList name="feeds">
	http://www.mplode.com/tima/xml/index.xml
	http://www.movabletype.org/index.xml
	</MTList>

	<MTListLoop name="feeds">
	<MTRSSFeed>
		<$MTRSSFeedTitle$><br/>
		<ul><MTRSSFeedItems lastn="5">
		<li><a href="<$MTRSSFeedItemLink$>"><$MTRSSFeedItemTitle$></a></li>
		</MTRSSFeedItems></ul>
	</MTRSSFeed>
	</MTListLoop>
	<p>Syndicated using <a href="http://www.mplode.com/tima/files/mt-plugins/#mt-rssfeed">mt-rssfeed</a></p>
	
	</body></html>

This simple template retrieves two RSS feeds and inserts their content using the same layout.

NOTE: Embedding list data directly in a template, while technical a valid operation, it is not a 
recommended practice. We are only doing it for clarity of the example. In order to maintain a separation 
of data and display and allow for reuse, list data should be stored in a separate text file or a MT module 
that is included in the C<MTList>. See the mt-list plugin documentation for more.

=head1 USING MT-RSSFEED WITH THE MT-SETVARBLOCK PLUGIN

Some RSS feeds are dynamically generated and allow you to past parameters in through the query string. As 
of version 1.02 you can use mt-rssfeed with mt-setvarblock to generate a URL using MovableType data. The 
following example illustrates the two plugins working in concert.

	<html><body>

	<MTSetVarBlock name="waypath">http://www.waypath.com/rwn.php?url=<$MTBlogURL encode_url='1'$>&format=rss&desc=n</MTSetVarBlock>

	<MTRSSFeed var="waypath">
		<$MTRSSFeedTitle$><br/>
		<ul><MTRSSFeedItems lastn="5">
		<li><a href="<$MTRSSFeedItemLink$>"><$MTRSSFeedItemTitle$></a></li>
		</MTRSSFeedItems></ul>
	</MTRSSFeed>
	
	<p>Syndicated using <a href="http://www.mplode.com/tima/files/mt-plugins/#mt-rssfeed">mt-rssfeed</a></p>
	</body></html>

NOTE: Be sure to not introduce any lines breaks into the variable. In other words, you'll save yourself some 
trouble if you create the variable in one line as I did in the above example.

=head1 RSS AUTHORING RESOURCES

B<RSS Validator Service> http://feeds.archive.org/validator/
This service checks RSS feeds for problems and generates friendly and instructive messages for fixing them. 

B<Raising the Bar on RSS Feed Quality> http://www.oreillynet.com/pub/a/webservices/2002/11/19/rssfeedquality.html
My O'Reilly Network article covering practical recommendations for improving an RSS feed's effectiveness.

=head1 CHANGELOG

Please see the file F<CHANGELOG> in the mt-rssfeed distribution.

=head1 LICENSE

Please see the file F<LICENSE> in the mt-rssfeed distribution.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, mt-rssfeed is Copyright 2002, Timothy Appnel, tima@mplode.com. All rights reserved.

=cut
