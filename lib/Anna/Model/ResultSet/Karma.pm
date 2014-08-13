package Anna::Model::ResultSet::Karma;

use strict;
use warnings;
use base qw/DBIx::Class::ResultSet/;

sub get_totals {
  my ($self, $item) = @_;
  my $positive = $self->search({ value => { ilike => $item }, score => 1 })->count;
  my $negative = $self->search({ value => { ilike => $item }, score => '-1' })->count;
  return {
    pos => $positive // 0,
    neg => $negative // 0,
    tot => ($positive - $negative) // 0,
  };
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
