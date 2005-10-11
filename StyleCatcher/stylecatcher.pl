package MT::Plugin::StyleCatcher;

use strict;
use base 'MT::Plugin';
use vars qw($VERSION);
$VERSION = '1.01';

my $plugin = MT::Plugin::StyleCatcher->new({
    name => "StyleCatcher",
    version => $VERSION,
    description => q{StyleCatcher lets you easily browse through styles and then apply them to your blog in just a few clicks. To find out more about Movable Type styles, or for new sources for styles, visit the <a href="http://www.sixapart.com/movabletype/styles">Movable Type styles</a> page.},
    doc_link => "http://www.sixapart.com/movabletype/styles/",
    config_link => "stylecatcher.cgi",
    author_name => "Nick O'Neil, Brad Choate",
    author_link => "http://www.authenticgeek.net/",
    config_template => \&configuration_template,
    settings => new MT::PluginSettings([
        ['webthemeroot'],
        ['themeroot'],
    ]),
});
MT->add_plugin($plugin);
MT->add_plugin_action('list_template', 'stylecatcher.cgi', 'Select a Design using StyleCatcher');
sub instance { $plugin }

sub configuration_template {
    my $plugin = shift;
    my ($param, $scope) = @_;

    my $intro;
    if ($scope eq 'system') {
        $param->{webthemeroot} ||= MT->instance->static_path;
        $param->{themeroot} ||= File::Spec->catdir(MT->instance->mt_dir, 'mt-static', 'themes');
        $intro = q{
You must define a global theme repository where themes can be stored locally.
If a particular blog has not been configured for it's own theme paths, it will
use these settings. If a blog has it's own theme paths, then the theme will
be copied to that location when applied to that weblog.};
    } else {
        if (my $blog = MT->instance->blog) {
            if (!$param->{webthemeroot}) {
                my $url = $blog->site_url;
                $url =~ s!/$!!;
                $url .= '/themes/';
                $param->{webthemeroot} = $url;
            }
            if (!$param->{themeroot}) {
                my $path = $blog->site_path;
                $path = File::Spec->catdir($path, 'themes');
                $param->{themeroot} = $path;
            }
        }
        $intro = q{Your theme URL and path can be customized for this
        weblog.};
    }

    return qq{
<p>
$intro
The paths defined here must physically exist and be
writable by the webserver.
</p>

<div class="setting">
<div class="label"><label for="stycat_webthemeroot">Theme Root URL:</label></div>
<div class="field">
<input type="text" name="webthemeroot" id="stycat_webthemeroot" value="<TMPL_VAR NAME=WEBTHEMEROOT ESCAPE=HTML>" style="width: 95%" />
</div>
</div>

<div class="setting">
<div class="label"><label for="stycat_themeroot">Theme Root Path:</label></div>
<div class="field">
<input type="text" name="themeroot" id="stycat_themeroot" value="<TMPL_VAR NAME=THEMEROOT ESCAPE=HTML>" style="width: 95%" />
</div>
</div>
    };
}

sub save_config {
    my $plugin = shift;
    my ($param, $scope) = @_;
    my $themeroot = $param->{themeroot};

    my $app = MT->instance;

    require MT::FileMgr;
    my $filemgr = MT::FileMgr->new('Local')
        or return $app->error(MT::FileMgr->errstr);

    my $base_weblog_path = File::Spec->catfile($plugin->{full_path},
                                               "base-weblog.css");
    my $base_weblog = $filemgr->get_data($base_weblog_path);
    $filemgr->mkpath($app->param('themeroot'))
        or die "Unable to create the theme root directory. Error: " . $filemgr->errstr;

    defined($filemgr->put_data($base_weblog,
        File::Spec->catfile($app->param('themeroot'), "base-weblog.css")))
        or die "Unable to write base-weblog.css to themeroot. File Manager gave the error: ".$filemgr->errstr.". Are you sure your theme root directory is web-server writable?";

    return $plugin->SUPER::save_config(@_);
}

1;