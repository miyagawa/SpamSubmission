#!/usr/local/bin/perl -w
# MT Podcaster - Víctor R. Ruiz <victor@sixapart.com>
# $Id$

use strict;

my ($MT_DIR, $PLUGIN_DIR, $PLUGIN_ENVELOPE);
eval {
    require File::Basename; import File::Basename qw( dirname );
    require File::Spec;

    $MT_DIR = $ENV{PWD};
    $MT_DIR = dirname($0)
        if !$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR);
    $MT_DIR = dirname($ENV{SCRIPT_FILENAME}) 
        if ((!$MT_DIR || !File::Spec->file_name_is_absolute($MT_DIR)) 
            && $ENV{SCRIPT_FILENAME});
    unless ($MT_DIR && File::Spec->file_name_is_absolute($MT_DIR)) {
        die "Plugin couldn't find own location";
    }
};

if ($@) {
    print "Content-type: text/html\n\n$@"; 
    exit(0);
}

$PLUGIN_DIR = $MT_DIR;
($MT_DIR, $PLUGIN_ENVELOPE) = $MT_DIR =~ m|(.*[\\/])(plugins[\\/].*)$|i;

unshift @INC, $MT_DIR . 'lib';
unshift @INC, $MT_DIR . 'extlib';

unshift @INC, './lib';
#unshift @INC, './extlib';

package main;

eval {
	require MT::App::Podcaster;
    my $app = MT::App::Podcaster->new(
        Config => $MT_DIR . 'mt.cfg',
        Directory => $MT_DIR,
        plugin_template_path => File::Spec->catdir($PLUGIN_ENVELOPE, 'tmpl')
    ) or die MT::App::Podcaster->errstr;
    local $SIG{__WARN__} = sub { $app->trace ($_[0]) };
    $app->run;
};

if ($@) {
    print "Content-Type: text/html\n\n";
    print "An error occurred: $@";
}
