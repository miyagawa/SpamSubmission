package MT::Plugin::PassThrough;
# $Id$
#
# Tatsuhiko Miyagawa <miyagawa@livedoor.jp>
# Livedoor, Co.,Ltd.
#

use strict;
use MT::Template::Context;

MT::Template::Context->add_container_tag(
    PassThrough => sub {
	my $ctx = shift;
	return $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'));
    },
);

1;

