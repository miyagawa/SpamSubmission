# mt-list
#
# Copyright 2002 Timothy Appnel.
# This code is released under the Artistic License.
#

package MT::Plugin::List;

my $VERSION='0.2';

use MT::Template::Context;

MT::Template::Context->add_container_tag(List => sub { &_hdlr_list; });
MT::Template::Context->add_tag(ListFile => sub { &_hdlr_list; });
MT::Template::Context->add_container_tag(ListLoop => sub { &_hdlr_loop; });
MT::Template::Context->add_tag(ListItem => sub { &_hdlr_item; });
MT::Template::Context->add_tag(ListItemIndex => sub { &_hdlr_item_index; });


sub debug {
    my ($ctx,$msg,$mode) = @_;
	$mode=$mode?$mode:1;
	warn "mt-list debugging: $msg\n" if ($mode <= $ctx->stash('mt-list_debug'));
	# 0=no debugging messages
	# 1=debugging messages on (default mode of debug subroutine)
	# 2=verbose debugging messages on
}

sub _hdlr_list {
	my($ctx,$args) = @_;
	my $tag = $ctx->stash('tag');
	my @list;
	my $out;
	$ctx->error("MT$tag requires a 'name' argument.") unless keys %$args && defined($args->{name});
	my $name='mt-list_' . $args->{name};
	$ctx->stash('mt-list_current',$name);
	# Store debugging info.
	$args->{debug}=0 unless ($args->{debug}); #default to no debugging messages if not specified
	$ctx->stash('mt-list_debug',$args->{debug});
	if ($tag eq 'ListFile') {
		$ctx->error("MTListFile requires a 'file' argument.") unless keys %$args && defined($args->{file});
		my $file = $args->{file};
		unless (File::Spec->file_name_is_absolute($file)) {
			my $blog = MT::Blog->load($ctx->stash('blog')->id);
	        $file = File::Spec->catfile($blog->site_path, $file);
		}
		debug($ctx,"Loading list from $file");
		if (-e $file) {
			require FileHandle;
			my $fh = new FileHandle;
			$fh->open("< $file") or return $ctx->error("$file could not be opened.");
			$out=join("",<$fh>);
			$fh->close;
		} else {
			return $ctx->error("$file does not exist.");
		}
	} else {
		debug($ctx,"Loading up list ".$args->{name}.' from template');
		my $builder = $ctx->stash('builder');
		my $tokens = $ctx->stash('tokens');
		defined($out = $builder->build($ctx,$tokens)) or return $ctx->error($ctx->errstr);
	}
	$out=~s/^\s+//mg;
	$out=~s/\r//sg;
	$out=~s/\n+/\n/sg;
	debug($ctx,"\nThe list:\n".$out,2);
	@list=split(/\n+/,$out);
	chomp(@list);
	$ctx->stash($name,\@list);
	return '';
}

sub _hdlr_loop {
	my($ctx,$args) = @_;
	my @range;
	my $out;
	$ctx->error("MTListLoop requires a 'name' argument.") unless keys %$args && defined($args->{name});
	my $name='mt-list_' . $args->{name};
	$ctx->stash('mt-list_current',$name);
	# Store debugging info.
	$args->{debug}=0 unless ($args->{debug}); #default to no debugging messages if not specified
	$ctx->stash('mt-list_debug',$args->{debug});
	my $count=$#{ $ctx->stash($name) };
	if (defined($args->{rnd}) && $args->{rnd} > 0) {
		debug($ctx,'Selecting random '.$args->{rnd}.' from '.$args->{name});
		my $i=0;
		while ($i < $args->{rnd}) {
			my $random = int(rand($count+1));
			my $match=0;
			foreach (@range) {
				if ($random==$_) {
					$match++;
					last;
				}
			}
			if (! $match) { push(@range, $random); $i++;}
		}
	} else {
		my $start = defined $args->{offset} ? $args->{offset}-1 : 0;
		my $end = defined $args->{count} ? $args->{count}+$start-1 : $count;
		debug($ctx,'Loop starts at '.$start.' and ends at '.$end);
		@range=$start..$end;	
	}
	if (defined $args->{sort}) {
		my @array;
		if ($args->{sort} eq 'ascending') {
			@array = sort { $a cmp $b} @{ $ctx->stash($name) };
		} elsif ($args->{sort} eq 'descending') {
			@array = sort { $b cmp $a} @{ $ctx->stash($name) };
		}
		$ctx->stash($name, \@array);
		debug($ctx,"The list sorted in ".$args->{sort}." order:\n".join("\n",@list),2);
	}
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	my $index=0;
	foreach (@range) {
		$index++;
		$ctx->stash('mt-list_current_item', ${ $ctx->stash($name) }[$_]);
		$ctx->stash('mt-list_current_item_index',$index);
		if (defined $out) {
			$out .= $builder->build($ctx,$tokens); }
		else {
			$out=$builder->build($ctx,$tokens); }
	}
	return $out
}

sub _hdlr_item { return $_[0]->stash('mt-list_current_item'); }

sub _hdlr_item_index { return $_[0]->stash('mt-list_current_item_index'); }

1;

__END__

=head1 NAME

mt-list - A MovableType plugin for working with simple lists in templates.

=head1 SYNOPSIS

	<MTListFile file="links.dat" name="links">

	<MTList name="foo">
		<MTEntries><$MTEntryTitle$></MTEntries>
	</MTList>

	<MTListLoop name="foo" rnd="5" sort="ascending">
	<$MTListItemIndex$>: <$MTListItem$>
	</MTListLoop>

	<MTListLoop name="links" sort="descending" count="5" offset="5">
	<a href="<$MTListItem$>"><$MTListItem$><br />
	</MTListLoop>

This template code would first load a list (links) from the file 'links.dat' in the blog's
root directory and then create another list (foo) from the last 10 entries titles. The template
would then randomly select 5 entries from the 'foo' list sorted in ascending textual order and
loop through the contained layout. The last section would loop through the contained layout
with 5 elements from 'links' list in descending order starting beginning with the 5 th element in
the sorted list.

=head1 DESCRIPTION

mt-list is a MoveableType plugin for creating simple lists (arrays) within a template or text file. 
Once defined, the list can be looped over, sorted or selected from randomly during  the template
generation. This plugin has designed to be easily integrated with other plugins requiring this type 
of list and looping functionality. The intention of the mt-list tag is not to insert static lists 
of data into templates, but rather capture information from MovableType data or an external file. 
Static lists in templates is not recommended as it breask the seperation of data and display.


=head1 INSTALLATION

Place this file inside of your plugins directory where MT is installed.  If
the directory does not exist, create the plugins directory. 

=head1 TAGS

=over 4

=item * MTList I<name="string">

A container tag for creating a simple list (or array) with the text contained within the tag using the key
specified by a required attribute of C<name>. A line break creates a new item. Any legal use of MovableType
template tags is allowed to generate a list.

=item * MTListFile I<name="string" file="string">

Like C<MTList> this tag creates a list using the key specified by the required attribute of C<name>, but from a
local file system. The file is specified by the required attribute of C<file> and can be a absolute path or
relative to the weblog's site path.

=item * MTListLoop I<name="string" [rnd="integer", count="integer", offset="integer", sort="ascending|descending"]>

A container tag that will loop through a list specified by the required attribute C<name>. An optional
attribute of C<rnd> specifies the loop count in which items will be randomly selected in a non-repeating
fashion from the list. C<count> is an optional C<attribute> that specifies the number of items (and loops) to
go through. The C<offset> attribute starts the loop at the item specified. C<count> and C<offset> will be ignored
if C<rnd> is used. The optional attribute of C<sort> defines the ordering of the items. The default operation
of C<MTListLoop> is to use all items with no offset or sort.

=item * MTListLoopItem

This tag inserts the current loop item.

=item * MTListLoopItemIndex

This tags inserts an integer representing the current list item index (or loop count).

=back

=head1 NOTES

The intention of the C<MTList> tag is not to insert static lists of data, but rather capture information
from other MovableType data. Placing data inside your template is bad design form because it cannot be
accessed from another template or operations. At a minimum static lists should be placed in a template
module and used with C<MTList> like so...

	<MTList name="foo"><$MTInclude module="data.mod"$></MTList>

Optionally you could store a static list in a file where aplications other then MT may also have
access to it and use C<MTListFile> instead.

=head1 INTEGRATING ANOTHER PLUGIN WITH MT-LIST

The mt-list plugin was designed to be integrated with other plugins requiring list and looping functionality. When inside the context of a C<MTListLoop> the following information is "stashed" in the MovableType template builder context.

=over 4

=item * mt-list_current

A string representing the key name of the C<MTListLoop> in context. This key can be used to perform another C<stash> to get an array reference to the list itself.

=item * mt-list_current_item

A string representing the value of the current C<MTListLoop> loop.

=item * mt-list_current_item_index

An integer representing the index of the current item.

=back

The following example is a simple example plugin that is designed to work within the context of an mt-list C<MTListLoop>.

	use MT::Template::Context;
	MT::Template::Context->add_tag(ListEcho => sub { &list_echo; });
	MT::Template::Context->add_tag(ListItemEcho => sub { &list_item_echo; });
	
	sub list_echo {
		my $ctx=shift;
		my $key = $ctx->stash('mt-list_current');
		my @array = @{ $ctx->stash($key) };
		return join("\n",@array);
	}
	
	sub list_item_echo {
		my $ctx=shift;
		return 'The current item is '.$ctx->stash('mt-list_current_item').
			' with an index of '.$ctx->stash('mt-list_current_item_index');
	}

In C<list_echo> subroutine we retreive the key for the MTListLoop that this plugin is in the context of 
represented as C<mt-list_current>. We then use that key to retreive the array reference containing the 
stashed list that we turn into a single string to insert. The C<list_item_echo> subroutine concatenates 
the current list item C<mt-list_current_item> and its index C<mt-list_current_item_index> into a string 
and inserts it.

=head1 CHANGELOG

Please see the file F<CHANGELOG> in the mt-rssfeed distribution.

=head1 LICENSE

The software is released under the Artistic License. The terms of the Artistic License are described at http://www.perl.com/language/misc/Artistic.html.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, mt-list is Copyright 2002, Timothy Appnel, tima@mplode.com. All rights reserved.

=cut
