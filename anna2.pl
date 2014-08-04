#!/usr/bin/perl
use Mojo::Base -strict;
use 5.014;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Mojo::IRC;
use Mojo::IOLoop;
use Mojo::UserAgent;;
use Anna::Schema;
use Config::General;

use Data::Printer;

my %config = Config::General->new('./conf/anna.conf')->getall;

my $dbh = Anna::Schema->connect(
  $config{dburi},
  $config{dbuser},
  $config{dbpass},
  {
    pg_enable_utf8 => 1,
    RaiseError     => 1,
    PrintError     => 1,
    PrintWarn      => 1
  }
);

my $irc = Mojo::IRC->new(
  nick => $config{nick},
  user => $config{username},
  name => $config{displayname},
  server => "$config{server}:$config{port}",
);

sub on_connect {
  my ($c, $error) = @_;
  #Delay channel joins by two seconds.
  Mojo::IOLoop->timer(2 => sub {
    $irc->write(join => $config{chan});
  });
};

$irc->on(irc_privmsg => sub {
    my ($c, $raw) = @_;
    my ($nick, $host) = split /!/, $raw->{prefix};
    my ($chan,$message) = @{$raw->{params}};

    my $karma = $dbh->resultset('Karma');

    if($message =~ /\+{2}(\w+)|(\w+)\+{2}/) {
      $karma->create({
          value => $1//$2,
          score => 1
      });
    }

    if($message =~ /-{2}(\w+)|(\w+)-{2}/) {
      $karma->create({
          value => $1//$2,
          score => '-1'
      });
    }

    my @cmds = split / /, $message;

    if ($cmds[0] =~ /^!(\w+)/) {

      if ( $1 =~ /^karma$/i ) {
        my $score = $karma->search({
            value => { ilike => $cmds[1] },
          })->get_column('score')->sum;
        return $c->write(PRIVMSG => $chan => "$cmds[1] has ".($score?$score:'0'). ' karma');
      }

      if ( $1 =~ /^quote$/i ) {
        my $quote;
        if (scalar @cmds == 1 ) {
          $quote = $dbh->resultset('Quote')->search(undef, { order_by => 'random()', rows => 1 })->first;
        } else {
          $quote = $dbh->resultset('Quote')->search(
            { quote => { 'ilike' => "%$cmds[1]%" }},
            { order_by => 'random()', rows => 1 })->first;
        }
        return $irc->write(PRIVMSG => $chan => $quote->quote);
      }

      if ( $1 =~ /^addquote$/i ) {
        shift @cmds;
        $dbh->resultset('Quote')->create({
          added_by => $nick,
          quote => join ' ', @cmds
        });
        return;
      }

      if ( $1 =~ /^top$/i ) {
        my @res = $karma->search(undef,
          { select => [
              { 'initcap' => 'value', -as => 'value' },
              { 'sum' => 'score', -as => 'score' }],
            order_by => { -desc => 'score' },
            group_by => [{ 'initcap' => 'value'}],
            rows => 5 });
        return $irc->write(PRIVMSG => $chan => 'Top 5 - '. join '. ', map { $_->value.': '.$_->score } @res );
      }

      if ( $1 =~ /^bottom$/i ) {
        my @res = $karma->search(undef,
          { select => [
              { 'initcap' => 'value', -as => 'value' },
              { 'sum' => 'score', -as => 'score' }],
            order_by => { -asc => 'score' },
            group_by => [{ 'initcap' => 'value'}],
            rows => 5 });
        return $irc->write(PRIVMSG => $chan => 'Bottom 5 - '. join '. ', map { $_->value.': '.$_->score } @res );
      }
    }
});

$irc->on(irc_join => sub {
    my ($c, $msg) = @_;
});

$irc->on(error => sub {
    my ($c, $err) = @_;
    warn $err;
});

sub _reconnect_in {
  return 10 + int rand 30;
}

$irc->connect(\&on_connect);
Mojo::IOLoop->start;

1;
