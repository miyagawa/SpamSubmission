# SpamLookup
# Original copyright (c) 2004-2005, Brad Choate and Tobias Hoellrich
#
# Modifications and integration Copyright 2005 Six Apart.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id: spamlookup.pl 16210 2005-08-15 18:00:45Z bchoate $

package MT::Plugin::SpamLookup;

use strict;
use MT;
use base qw(MT::Plugin);

use vars qw($VERSION);
sub BEGIN {
    $VERSION = '2.0';
    my $plugin;
    $plugin = new MT::Plugin::SpamLookup({
        name => 'SpamLookup - Lookups',
        version => $VERSION,
        description => 'SpamLookup module for using blacklist lookup services to filter feedback.',
        doc_link => 'http://www.spamlookup.com/wiki/LookupFilter',
        author_name => 'Six Apart, Ltd.',
        author_link => 'http://www.sixapart.com/',
        config_template => 'lookup_config.tmpl',
        settings => new MT::PluginSettings([
            ['ipbl_mode', { Default => 1 }],
            ['ipbl_weight', { Default => 1 }],
            ['ipbl_moderate', { Default => 0 }],
            ['ipbl_service', { Default => 'bsb.spamlookup.net, opm.blitzed.org' }],
            ['domainbl_mode', { Default => 1 }],
            ['domainbl_weight', { Default => 1 }],
            ['domainbl_service', { Default => 'bsb.spamlookup.net, sc.surbl.org' }],
            ['tborigin_mode', { Default => 1 }],
            ['tborigin_weight', { Default => 1 }],
            ['whitelist', { Default => q{# This list can contain IP addresses and domain names that you
# wish to exclude from the Lookup filters you've configured above.
# You may specify either a complete or partial IP address

# This matches all 192.168.*.* IP addresses.
192.168.

# This will match sixapart.com and any of its subdomains:
sixapart.com}}],
        ])
    });
    MT->add_plugin($plugin);
    MT->register_junk_filter([
        { code => sub { $plugin->runner('ipbl', @_) },
          plugin => $plugin,
          name => 'SpamLookup IP Lookup' },
        { code => sub { $plugin->runner('domainbl', @_) },
          plugin => $plugin,
          name => 'SpamLookup Domain Lookup' },
        { code => sub { $plugin->runner('tborigin', @_) },
          plugin => $plugin,
          name => 'SpamLookup TrackBack Origin' }
    ]);
}

sub apply_default_settings {
    my $plugin = shift;
    my ($data, $scope) = @_;
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

sub init_app {
    my $plugin = shift;
    $plugin->SUPER::init_app(@_);
    my ($app) = @_;

    return unless $app->isa('MT::App::CMS');
    #$app->add_itemset_action({type => 'blog',
    #                          key => "despam_comments",
    #                          label => "Despam Comments",
    #                          code => sub { $plugin->despam_comments(@_) },
    #                       });
    #$app->add_itemset_action({type => 'blog',
    #                          key => "despam_trackbacks",
    #                          label => "Despam TrackBacks",
    #                          code => sub { $plugin->despam_trackbacks(@_) },
    #                       });
    #$app->add_itemset_action({type => 'comment',
    #                          key => "despam_comments",
    #                          label => "Despam",
    #                          code => sub { $plugin->despam_comments(@_) },
    #                       });
    #$app->add_itemset_action({type => 'ping',
    #                          key => "despam_trackbacks",
    #                          label => "Despam",
    #                          code => sub { $plugin->despam_trackbacks(@_) },
    #                       });
    #$app->add_methods(
    #    spamlookup_despam => sub { $plugin->runner('despam', @_) },
    #);
}

sub runner {
    my $plugin = shift;
    my $method = shift;
    require spamlookup;
    return $_->($plugin, @_) if $_ = \&{"spamlookup::$method"};
    die "Failed to find spamlookup::$method";
}

sub despam_trackbacks {
    my $plugin = shift;
    my $app = shift;

}

sub despam_comments {
    my $plugin = shift;
    my $app = shift;

}

1;