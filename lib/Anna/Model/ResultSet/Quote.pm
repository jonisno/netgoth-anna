package Anna::Model::ResultSet::Quote;

use strict;
use warnings;
use base qw/DBIx::Class::ResultSet/;

sub find_random {
  my $self = shift;
  return $self->search(
    undef,
    { rows => 1, order_by => 'random()' }
  )->first;
}

sub search_random {
  my ($self, $item) = @_;
  return $self->search(
    { quote => {'ilike' => "%$item%" }},
    { rows => 1, order_by => 'random()' }
  )->first;
}

1;
