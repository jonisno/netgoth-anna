package Anna::Model::Result::Log;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('irclog');
__PACKAGE__->add_columns(qw/ id nick message /);
__PACKAGE__->add_columns(
  said_at => { data_type => 'datetime' },
);
__PACKAGE__->set_primary_key('id');

1;
