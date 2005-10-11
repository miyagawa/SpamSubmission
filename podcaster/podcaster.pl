
#!/usr/bin/perl -w
package MT::Plugin::Podcaster;

use lib './extlib/';

use strict;
use MT;
use MT::Template::Context;
use MT::Plugin;

my $plugin = MT::Plugin->new({
	name => 'Podcaster',
    description => q{A podcast manager for Movable Type.},
    ## doc_link => 'http://www.sixapart.com/pronet/2005/01/introduction_to.html',
    config_link => 'mt-podcaster.cgi'
});
MT->add_plugin($plugin);

MT::Template::Context->add_container_tag(PodcasterLoop => \&podcaster_loop);
MT::Template::Context->add_tag(PodcasterLoopURL => \&podcaster_loop_url);
MT::Template::Context->add_tag(PodcasterLoopLength => \&podcaster_loop_length);
MT::Template::Context->add_tag(PodcasterLoopType => \&podcaster_loop_type);
MT::Template::Context->add_tag(PodcasterEnclosureTitle => \&enclosure_title);
MT::Template::Context->add_tag(PodcasterEnclosureDescription => \&enclosure_description);
## MT::Template::Context->add_tag(PodcasterEnclosurePubDate => \&enclosure_pub_date);

sub podcaster_loop {
	require MT::ConfigMgr;
	require MT::PluginData;
	require MIME::Types;
	
	my $ctx = shift;
	my $args = shift;
	my $content = '';
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	my $blog_id = $ctx->stash('blogid');
	
	my @podcasts = MT::PluginData->load({ plugin => 'podcaster' }); # , key => '$blog_id'
	foreach my $enclosure (@podcasts) {
		my $file_name = $enclosure->key();
		my $data = $enclosure->data();
		my @tags = qw(title date artist album year comment genre tracknumber);
		foreach (@tags) {
			my $tag = "podcast_$_";
			$ctx->stash($tag, $data->{$tag});
		}
		my $out = $builder->build($ctx, $tokens);
		$content .= $out;
	}
	$content;
}
 
sub enclosure_url {
	my $ctx = shift;	
	return $ctx->stash('enclosure_url');
}

sub enclosure_length {
	my $ctx = shift;	
	return $ctx->stash('enclosure_length');
}

sub enclosure_type {
	my $ctx = shift;	
	return $ctx->stash('enclosure_type');
}

sub enclosure_title {
	my $ctx = shift;	
	return $ctx->stash('enclosure_title');
}

sub enclosure_description {
	my $ctx = shift;	
	return $ctx->stash('enclosure_description');
}

1;
