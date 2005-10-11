package MT::App::Podcaster;
use Class::Autouse qw(MT::PluginData MT::Permission MT::Blog);
use Symbol;
require MT::App;
@MT::App::Podcaster::ISA = 'MT::App';

sub init {
    my $app = shift;
    $app->SUPER::init (@_) or return; 
    $app->add_methods (
		list_blogs => \&list_blogs,
        list_podcasts => \&list_podcasts,
        edit_podcast => \&edit_podcast,
        save_podcast => \&save_podcast,
        upload_file => \&upload_file,
        upload_podcast => \&start_upload,
    );
    $app->{user_class} ||= 'MT::Author';
    $app->{default_mode} = 'list_blogs';
    $app->{template_dir} ||= 'cms';
    $app->{requires_login} = 1; 
	$app->add_breadcrumb('Podcaster', $app->uri);
    $app;   
}

sub list_blogs {
    my $app = shift;
    my (%param) = @_;
    my $author = $app->{author};
    
    require MT::Blog;
    require MT::Permission;

    ## Load blogs

    my @perms = MT::Permission->load({ author_id => $author->id });
    my %args;
    $args{join} = ['MT::Permission', 'blog_id', { author_id => $author->id }, undef ];
    my @blogs = MT::Blog->load(undef, \%args);
    my @blog_loop;
    for my $blog (@blogs) {
		my %b;
		$b{blog_id} = $blog->id;
		$b{blog_name} = $blog->name;
		my $podcasts = $app->_podcast_list($blog);
		$b{blog_num_podcasts} = @$podcasts + 0;
		push @blog_loop, \%b;
    }
    if ($#blog_loop >= 0) {
    	$param{blog_loop} = \@blog_loop;
    	$param{blogs} = 1;
    }    
    
    $app->build_page('default.tmpl', \%param);
}

sub list_podcasts {
    my $app = shift;
    my (%param) = @_;
    my $author = $app->{author};
    
    require MT::Permission;
    require MT::Blog;
    
    my $blog_id = $app->{query}->param('blog_id');
    $param{blog_id} = $blog_id;
    
    ## Load weblog data
    my $blog = MT::Blog->load({ id => $blog_id })
    	or die "This weblog doesn\'t exist";
    $app->add_breadcrumb( $blog->name );
    
    ## Check if author has blogs
    my @perms = MT::Permission->load({ author_id => $author->id, 
    	  							   blog_id => $blog_id });
    unless (@perms) {
    	$param{error} = 1;
    	$param{message} = 'You don\'t have permissions in this blog.';
    	return $app->build_page('list-podcasts.tmpl', \%param);
    }
    
    $param{blog_name} = $blog->name;

	my $limit = $app->{query}->param('limit') || 5;
    $param{"limit_" . $limit} = 1;
    $param{limit} = $limit;
	my $offset = $app->{query}->param('offset') || 0;
	
    ## Load podcast list
	my $files = $app->_podcast_list($blog);
	if (@$files >= 0) {
		if ($limit ne 'none' && @$files > $limit) {
			@$files = @$files[$offset..$offset + $limit];
			$param{next_offset} = 1;
			$param{next_offset_val} = $offset + $limit;
		} else {
			$param{next_offset} = 0;
	    }
		if ($offset > 0) {
			$param{prev_offset} = 1;
			$param{prev_offset_val} = $offset - $limit;
		} else {
			$param{prev_offset} = 0;
		}

		## Check limits and offset
		$param{podcasts} = 1;
		$param{podcast_loop} = $files;
	}
	
	$app->build_page('list-podcasts.tmpl', \%param);
}

sub edit_podcast {
    my $app = shift;
    my (%param) = @_;
    my $author = $app->{author};
    
    require MT::PluginData;
    require MT::Permission;
    require MT::Blog;

	## Load blog data
    my $blog_id = $app->{query}->param('blog_id');
    $param{blog_id} = $blog_id;
    my $blog = MT::Blog->load({ id => $blog_id })
    	or die('Blog doesn\'t exist');

    $app->add_breadcrumb( $blog->name.'\'s podcasts', $app->uri."?__mode=list_podcasts&blog_id=".$blog_id );
	$app->add_breadcrumb( 'Edit podcast' );
	
	## Load key and podcast data
	my $key = $app->{query}->param('file');
    my $data = MT::PluginData->load({ plugin => 'podcaster',
									  key    => $key });
	unless ($data) {
    	$param{error} = 1;
    	$param{message} = 'That file doesn\'t have any data.';
    	return $app->build_page('edit-podcast.tmpl', \%param);
	}
    
    ## Can edit?
=pod    
    my @perms = MT::Permission->load({ author_id => $author->id, 
    	  							   blog_id => $data->{podcast_blog_id} });
    unless (@perms) {
    	$param{error} = 1;
    	$param{message} = 'You don\'t have permissions in this blog.'.$data->{podcast_blog_id};
    	return $app->build_page('edit-podcast.tmpl', \%param);
    }
=cut

	## Fill template vars
	my $podcast = $data->data();
	foreach (keys %$podcast) {
		MT::log($_." : ".$podcast->{$_});
		$param{$_} = $podcast->{$_};
	}
    $app->build_page('edit-podcast.tmpl', \%param);
}

sub save_podcast {
    my $app = shift;
    my (%param) = @_;
    my $author = $app->{author};
    
    require MT::Permission;
    require MT::Blog;

	## Load blog data
    my $blog_id = $app->{query}->param('blog_id');
    $param{blog_id} = $blog_id;
    my $blog = MT::Blog->load({ id => $blog_id })
    	or die('Blog doesn\'t exist');

    $app->add_breadcrumb( $blog->name.'\'s podcasts', $app->uri."?__mode=list_podcasts&blog_id=".$blog_id );
	$app->add_breadcrumb( 'Edit podcast' );
	
	## Load key and podcast data
	my $key = $app->{query}->param('file');
    my $data = MT::PluginData->load({ plugin => 'podcaster',
									  key    => $key });
	unless ($data) {
    	$param{error} = 1;
    	$param{message} = 'That file doesn\'t have any data.';
    	return $app->build_page('edit-podcast.tmpl', \%param);
	}
    my $podcast = $data->data();
    
    $podcast->{podcast_alt_title} = $app->{query}->param('podcast_alt_title');
    $podcast->{podcast_alt_description} = $app->{query}->param('podcast_alt_description');
    $data->data($podcast);
    $data->save();

	## Fill template vars
	$podcast = $data->data();
	foreach (keys %$podcast) {
		MT::log($_." : ".$podcast->{$_});
		$param{$_} = $podcast->{$_};
	}
    
    $param{message} = 'Data saved';
    $app->build_page('edit-podcast.tmpl', \%param);

}

## Copy & Paste from MT::App::CMS
sub start_upload {
    my $app = shift;
    #my $perms = $app->{perms}
    #    or return $app->error($app->translate("No permissions"));
    #return $app->error($app->translate("Permission denied."))
    #    unless $perms->can_upload;
    my $blog_id = $app->{query}->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
    $app->add_breadcrumb($blog->name, $app->uri . '?__mode=list_podcasts&blog_id=' . $blog->id);
    $app->add_breadcrumb('Upload File');
    $app->build_page('upload.tmpl', {
    	blog_id => $blog->id,
        local_archive_path => $blog->archive_path,
        local_site_path => $blog->site_path,
    });
}

## Copy & Paste from MT::App::CMS
sub upload_file {
    my $app = shift;
    ##my $perms = $app->{perms}
    ##    or return $app->error($app->translate("No permissions"));
    ##return $app->error($app->translate("Permission denied."))
    ##    unless $perms->can_upload;
    $app->validate_magic() or return;

    my $q = $app->{query};
    my($fh, $no_upload);
    if ($ENV{MOD_PERL}) {
        my $up = $q->upload('file');
        $no_upload = !$up || !$up->size;
        $fh = $up->fh if $up;
    } else {
        ## Older versions of CGI.pm didn't have an 'upload' method.
        eval { $fh = $q->upload('file') };
        if ($@ && $@ =~ /^Undefined subroutine/) {
            $fh = $q->param('file');
        }
        $no_upload = !$fh;
    }
    my $has_overwrite = $q->param('overwrite_yes') || $q->param('overwrite_no');
    return $app->error($app->translate("You did not choose a file to upload."))
        if $no_upload && !$has_overwrite;
    my $fname = $q->param('file') || $q->param('fname');
    $fname =~ s!\\!/!g;   ## Change backslashes to forward slashes
    $fname =~ s!^.*/!!;   ## Get rid of full directory paths
    if ($fname =~ m!\.\.|\0|\|!) {
        return $app->error($app->translate("Invalid filename '[_1]'", $fname));
    }
    my $blog_id = $q->param('blog_id');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id, {cache_ok=>1});
    my $fmgr = $blog->file_mgr;

    ## Set up the full path to the local file; this path could start
    ## at either the Local Site Path or Local Archive Path, and could
    ## include an extra directory or two in the middle.
    my($base, $extra_path);
    if ($q->param('site_path')) {
        $base = $blog->site_path;
        $extra_path = $q->param('extra_path_site');
    } else {
        $base = $blog->archive_path;
        $extra_path = $q->param('extra_path_archive');
    }
    my $extra_path_save = $extra_path;
    my $path = $base;
    if ($extra_path) {
        if ($extra_path =~ m!\.\.|\0|\|!) {
            return $app->error($app->translate(
                "Invalid extra path '[_1]'", $extra_path));
        }
        $path = File::Spec->catdir($path, $extra_path);
        ## Untaint. We already checked for security holes in $extra_path.
        ($path) = $path =~ /(.+)/s;
        ## Build out the directory structure if it doesn't exist. DirUmask
        ## determines the permissions of the new directories.
        unless ($fmgr->exists($path)) {
            $fmgr->mkpath($path)
                or return $app->error($app->translate(
                    "Can't make path '[_1]': [_2]", $path, $fmgr->errstr));
        }
    }
    $extra_path = File::Spec->catfile($extra_path, $fname);
    my $local_file = File::Spec->catfile($path, $fname);

    ## Untaint. We have already tested $fname and $extra_path for security
    ## issues above, and we have to assume that we can trust the user's
    ## Local Archive Path setting. So we should be safe.
    ($local_file) = $local_file =~ /(.+)/s;

    ## If $local_file already exists, we try to write the upload to a
    ## tempfile, then ask for confirmation of the upload.
    if ($fmgr->exists($local_file)) {
        if ($has_overwrite) {
            my $tmp = $q->param('temp');
            if ($tmp =~ m!([^/]+)$!) {
                $tmp = $1;
            } else {
                return $app->error($app->translate(
                    "Invalid temp file name '[_1]'", $tmp));
            }
            my $tmp_file = File::Spec->catfile($app->{cfg}->TempDir, $tmp);
            if ($q->param('overwrite_yes')) {
                $fh = gensym();
                open $fh, $tmp_file
                    or return $app->error($app->translate(
                        "Error opening '[_1]': [_2]", $tmp_file, "$!"));
            } else {
                if (-e $tmp_file) {
                    unlink($tmp_file)
                        or return $app->error($app->translate(
                            "Error deleting '[_1]': [_2]", $tmp_file, "$!"));
                }
                return $app->start_upload;
            }
        } else {
            eval { require File::Temp };
            if ($@) {
                return $app->error($app->translate(
                    "File with name '[_1]' already exists. (Install " .
                    "File::Temp if you'd like to be able to overwrite " .
                    "existing uploaded files.)", $fname));
            }
            my($tmp_fh, $tmp_file);
            eval {
                ($tmp_fh, $tmp_file) =
                    File::Temp::tempfile(DIR => $app->{cfg}->TempDir);
            };
            if ($@) { #!$tmp_fh) {
                return $app->errtrans(
                    "Error creating temporary file; please check your TempDir ".
                    "setting in mt.cfg (currently '[_1]') " .
                    "this location should be writable.",
                    ($app->{cfg}->TempDir ? $app->{cfg}->TempDir : '['.$app->translate('unassigned').']'));
            }
            defined(_write_upload($fh, $tmp_fh))
                or return $app->error($app->translate(
                    "File with name '[_1]' already exists; Tried to write " .
                    "to tempfile, but open failed: [_2]", $fname, "$!"));
            my($vol, $path, $tmp) = File::Spec->splitpath($tmp_file);
            return $app->build_page('upload_confirm.tmpl', {
                temp => $tmp, extra_path => $extra_path_save,
                site_path => scalar $q->param('site_path'),
                fname => $fname });
        }
    }

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->{cfg}->UploadUmask;
    my $old = umask($umask);
    defined(my $bytes = $fmgr->put($fh, $local_file, 'upload'))
        or return $app->error($app->translate(
            "Error writing upload to '[_1]': [_2]", $local_file,
            $fmgr->errstr));
    umask($old);

    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error($app->translate(
        "Perl module Image::Size is required to determine " .
        "width and height of uploaded images.")) if $@;
    my($w, $h, $id) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    ## If we are overwriting the file, that means we still have a temp file
    ## lying around. Delete it.
    if ($q->param('overwrite_yes')) {
        my $tmp = $q->param('temp');
        if ($tmp =~ m!([^/]+)$!) {
            $tmp = $1;
        } else {
            return $app->error($app->translate(
                "Invalid temp file name '[_1]'", $tmp));
        }
        my $tmp_file = File::Spec->catfile($app->{cfg}->TempDir, $tmp);
        unlink($tmp_file)
            or return $app->error($app->translate(
                "Error deleting '[_1]': [_2]", $tmp_file, "$!"));
    }

    ## We are going to use $extra_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $extra_path =~ s!\\!/!g;
    $extra_path =~ s!^/!!;
    ## my %param = ( width => $w, height => $h, bytes => $bytes,
    ##              image_type => $id, fname => $extra_path,
    ##              site_path => scalar $q->param('site_path') );
    my %param = ( bytes => $bytes, image_type => $id, 
    			  fname => $extra_path, site_path => scalar $q->param('site_path') );
    my $url = $q->param('site_path') ? $blog->site_url : $blog->archive_url;
    $url .= '/' unless $url =~ m!/$!;
    $extra_path =~ s!^/!!;
    $url .= $extra_path;
    $param{url} = $url;
    ## $param{is_image} = defined($w) && defined($h);
    ## if ($param{is_image}) {
    ##     eval { require MT::Image; MT::Image->new or die; };
    ##     $param{do_thumb} = !$@ ? 1 : 0;
    ## }
    
    ## Burn podcast data
    my $podcast = $app->_audio_metadata($local_file);
    $podcast = $app->_podcast_burn($podcast, $blog);
    $param{message} = "File successfully uploaded";
    
    $app->build_page('upload_complete.tmpl', \%param);
}

## Copy & Paste from MT::App::CMS
sub _write_upload {
    my($upload_fh, $dest_fh) = @_;
    my $fh = gensym();
    if (ref($dest_fh) eq 'GLOB') {
        $fh = $dest_fh;
    } else {
        open $fh, ">$dest_fh" or return;
    }
    binmode $fh;
    binmode $upload_fh;
    my($bytes, $data) = (0);
    while (my $len = read $upload_fh, $data, 8192) {
        print $fh $data;
        $bytes += $len;
    }
    close $fh;
    $bytes;
}


sub _podcast_list {
	my $app = shift;
	my $blog = shift;

	## Read podcast from list
	my @podcasts;
	my $iter = MT::PluginData->load_iter({ plugin => 'podcaster' });
	while (my $data = $iter->()) {
		push @podcasts, $data->data if ($data->data->{podcast_blog_id} == $blog->id);
	}
	
	## Order by date
	my @ordered = sort { $b->{podcast_date} cmp $a->{podcast_date} } @podcasts;
	
	return \@ordered;
}

sub _podcast_reload_site_path {
	my $app = shift;
	my $blog = shift;

	require MT::PluginData;
	require MT::Util;

	my $data = MT::PluginData->new();
	$data->plugin('podcaster');
	    
	## Import new audio files stored in /site_path/podcasts/
	my @tags = qw(title date artist album year comment genre tracknumber);
	my $path = $blog->site_path;
    my @files = glob "$path/*";
    return unless (@files);

	## Read audio metadata
    my @podcasts;
	for my $file (@files) {
		my $podcast = $app->_audio_metadata($file, $blog);
		push @podcasts, $podcast;
	}
    return @podcasts;
}

sub _audio_metadata {
	my $app = shift;
	my $file = shift;

    require Ogg::Vorbis::Header::PurePerl;
    require File::Basename;
    require MIME::Types;
	require File::stat;
    require MP3::Info;

	my @tags = qw(title date artist album year comment genre tracknumber);
	my %podcast;
	
	## Read audio file metadata
	my $mime = MIME::Types->new->mimeTypeOf($file);
	$podcast{podcast_type} = $mime->type if ($mime);
	$podcast{podcast_file} = File::Basename::basename($file);
	$podcast{podcast_size} = sprintf("%0.1f", ((-s $file) / 1024 / 1000))." MB"; ## Convert to MB
	
	## Only import audio files
	next unless ($podcast{podcast_type} =~ /^audio/ || $podcast{podcast_type} eq 'application/ogg');
	
	## Read metadata from MP3 and Ogg
	if ($podcast{podcast_type} eq 'audio/mp3') {
		my $mp3 = new MP3::Info $file;
		foreach (@tags) {
			$podcast{"podcast_$_"} = $mp3->$_;
		}
	} elsif ($podcast{podcast_type} eq 'application/ogg') {
		my $ogg = Ogg::Vorbis::Header::PurePerl->new($file);
		foreach (@tags) {
			$podcast{"podcast_$_"} = join(' ', $ogg->comment($_));
			MT::log("$_: ".join(' ',$ogg->comment($_)));
		}
   	}

    ## Take the date from the file
   	unless ($podcast{podcast_date}) {
	   	my $sb = File::stat::stat($file);
   		my @ts = localtime $sb->mtime;
   		my $date = sprintf "%04d.%02d.%02d %02d:%02d:%02d", $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
		$podcast{podcast_date} = $date;
   	}
   	
   	return \%podcast;
}

sub _podcast_burn {
	my $app = shift;
	my $podcast = shift;
	my $blog = shift;

	require MT::PluginData;
	require MT::Util;
	
	$podcast->{podcast_blog_id} = $blog->id;
	$podcast->{podcast_key} = MT::Util::perl_sha1_digest_hex($podcast->{podcast_file});
		
	## Check stored data
    my $data = MT::PluginData->load({ plugin => 'podcaster',
                                      key    => $podcast->{podcast_key},
                                      blog_id => $blog->id });
	if ($data) {
		## Keep old data
		my $d = $data->data();
		foreach (keys %$d) {
			$podcast->{$_} = $d->{$_} unless (defined $podcast->{$_});
		}
	} else {
		## New podcast detected
		$data = MT::PluginData->new;
		$data->plugin('podcaster');
		$data->key($podcast->{podcast_key});
		$data->blog_id($blog->id);
	}
	
	## Update or save data
	$data->data($podcast);
	$data->save
		or die "Cannot save podcast: ".$data->errstr;
	
	return $data->data();
}
