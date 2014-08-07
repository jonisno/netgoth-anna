package Anna::Model::Result::Karma;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('karma');
__PACKAGE__->add_columns(qw/id value score/);
__PACKAGE__->add_columns(
  time => { data_type => 'datetime' }
);
__PACKAGE__->set_primary_key('id');

1;
