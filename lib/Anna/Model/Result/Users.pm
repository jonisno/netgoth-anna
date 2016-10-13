package Anna::Model::Result::Users;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/nick/);
__PACKAGE__->add_columns(
  last_seen   => { data_type => 'datetime' },
);
__PACKAGE__->set_primary_key('nick');

1;
