package Anna::Model::Result::Users;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/ host password online_now /);
__PACKAGE__->add_columns(
	nick				=> { data_type => 'text' },
  last_seen   => { data_type => 'datetime' },
  last_active => { data_type => 'datetime' },
);
__PACKAGE__->set_primary_key('nick');

1;
