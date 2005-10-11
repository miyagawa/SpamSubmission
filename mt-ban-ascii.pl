package MT::Plugin::BanASCII;
# mt-ban-ascii.pl
# - Junk or moderate ASCII or Latin-1 comment using MT3 JunkFilter API
#
# It requires Perl 5.8 or over.
#
# Author:  Tatsuhiko Miyagawa <miyagawa at bulknews.net>
# License: same as Perl
#

use strict;
our $VERSION = "0.92";

# 'deny' or 'moderate'
our $Method = "junk";

use MT;
use MT::JunkFilter qw(ABSTAIN);

use base qw( MT::Plugin );

my $plugin = MT::Plugin::BanASCII->new({
    name => "BanASCII",
    version => $VERSION,
    description => "Junk or moderate ASCII or Latin-1 comment",
});

MT->add_plugin($plugin);
MT->register_junk_filter({
    name => 'BanASCII',
    plugin => $plugin,
    code => sub { $plugin->handler(@_) },
});

sub handler {
    my($plugin, $obj) = @_;
    require Encode;
    my $charset = MT::ConfigMgr->instance->PublishCharset;
    my $text = Encode::decode($charset, $obj->all_text);
    if ($text =~ /^[\x00-\xff]+$/) {
        if ($Method eq 'junk') {
            return (-1, "ASCII or Latin-1 comment");
        } elsif ($Method eq 'moderate') {
            $obj->moderate;
            return (0, "Moderated ASCII or Latin-1 comment");
        }
    }
    return ABSTAIN;
}

1;
