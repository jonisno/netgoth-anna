package Anna::Model::Result::Quote;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('quotes');
__PACKAGE__->add_columns(qw/id added_by quote/);
__PACKAGE__->add_columns(
  added_on => { data_type => 'datetime' }
);
__PACKAGE__->set_primary_key('id');

sub random {
  my $self = shift;
  return $self->search(undef, { rows => 1, order_by => 'random()' });
}

1;
