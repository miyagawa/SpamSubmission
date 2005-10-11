package MT::Plugin::BookmarkedTags;
# $Id$
use strict;
use MT;
use base qw( MT::Plugin );

our $VERSION = "0.10";

my $plugin = MT::Plugin::BookmarkedTags->new({
    name => "BookmarkedTags",
    version => $VERSION,
    description => "Tags to your entries tagged on social bookmarks like del.icio.us",
    author_name => 'Tatsuhiko Miyagawa',
    author_link => 'http://bulknews.typepad.com/blog/',
    config_template => 'bmtags_config.tmpl',
    settings => MT::PluginSettings->new([
        ['drivers', { Default => 'delicious,hatena' }],
        ['cache_ttl', { Default => 30*60 }],
        ['min_user', { Default => 2 }],
    ]),
});

MT->add_plugin($plugin);

sub apply_default_settings {
    my $plugin = shift;
    my($data, $scope) = @_;
    if ($scope ne 'system') {
        my $sys = $plugin->get_config_obj('system');
        my $sysdata = $sys->data();
        if ($plugin->{settings} && $sysdata) {
            foreach (keys %$sysdata) {
                $data->{$_} = $sysdata->{$_}
                    if (!exists $data->{$_}) || (!defined $data->{$_});
            }
        }
    } else {
        $plugin->SUPER::apply_default_settings(@_);
    }
}

# <MTEntryBMTags driver="delicious">
# <MTEntryBMTags driver="hatena">

# <MTEntryBMTags>
# <$MTEntryBMTagName$>
# <$MTEntryBMTagCount$>

1;
