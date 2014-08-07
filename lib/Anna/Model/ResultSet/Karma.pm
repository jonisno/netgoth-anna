package Anna::Model::ResultSet::Karma;

use strict;
use warnings;
use base qw/DBIx::Class::ResultSet/;

sub score_for {
  my ($self, $item) = @_;
  return $self->search({value => {ilike => $item}})->get_column('score')->sum
    || '0';
}

sub highest {
  my ($self, $num) = @_;
  return $self->search(
    undef,
    {
      select => [
        {'initcap' => 'value', -as => 'value'},
        {'sum'     => 'score', -as => 'score'}
      ],
      order_by => {-desc      => 'score'},
      group_by => [{'initcap' => 'value'}],
      rows     => $num
    }
  );
}

sub lowest {
  my ($self, $num) = @_;
  return $self->search(
    undef,
    {
      select => [
        {'initcap' => 'value', -as => 'value'},
        {'sum'     => 'score', -as => 'score'}
      ],
      order_by => {-asc       => 'score'},
      group_by => [{'initcap' => 'value'}],
      rows     => $num
    }
  );
}

1;
