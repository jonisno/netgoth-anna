#!/usr/bin/perl
use Mojo::Base -strict;
use 5.014;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Mojo::IRC;
use Mojo::IOLoop;
use Mojo::UserAgent;;
use Anna::Model;
use Config::General;
use Net::Twitter::Lite::WithAPIv1_1;

use Data::Printer;

my %config = Config::General->new('./conf/anna.conf')->getall;

my $dbh = Anna::Model->connect(
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

my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $config{twitter_key},
  consumer_secret     => $config{twitter_secret},
  access_token        => $config{twitter_token},
  access_token_secret => $config{twitter_token_secret},
  ssl                 => 1
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

    if($message =~ /https:\/\/twitter.com\/\w+\/status(?:es)?\/(\d+)/) {
      my $status = $twitter->show_status($1);
      my $tweet = $status->{text};
      $tweet =~ s/\R+/\ /g;
      $irc->write(PRIVMSG => $chan => "\@$status->{user}->{screen_name}: $tweet");
    }

    my $karma = $dbh->resultset('Karma');

    if($message =~ /\+{2}(\w+)|(\w+)\+{2}/) {
      return if ($1 && $1 =~ /$nick/i);
      return if ($2 && $2 =~ /$nick/i);
      $karma->create({ value => $1//$2, score => 1 });
    }

    if($message =~ /-{2}(\w+)|(\w+)-{2}/) {
      return if ($1 && $1 =~ /$nick/i);
      return if ($2 && $2 =~ /$nick/i);
      $karma->create({ value => $1//$2, score => '-1' });
    }

    my @cmds = split / /, $message;

    if ($cmds[0] =~ /^!(\w+)/) {

      if ( $1 =~ /^karma$/i ) {
        return $c->write(PRIVMSG => $chan => "$cmds[1] has " . $karma->score_for($cmds[1]) .  ' karma');
      }

      if ( $1 =~ /^quote$/i ) {
        my $quote = $dbh->resultset('Quote');
        if (scalar @cmds == 1 ) {
          $quote = $quote->find_random;
        } else {
          $quote = $quote->search_random($cmds[1]);
        }
        return $irc->write(PRIVMSG => $chan => $quote->quote);
      }

      if ( $1 =~ /^addquote$/i ) {
        shift @cmds;
        $dbh->resultset('Quote')->create({ added_by => $nick, quote => join ' ', @cmds });
        return;
      }

      if ( $1 =~ /^top$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Top 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->highest(5) );
      }

      if ( $1 =~ /^bottom$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Bottom 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->lowest(5) );
      }
    }
});

$irc->on(irc_join => sub {
    my ($c, $msg) = @_;
    p $msg;
});

$irc->on(irc_part => sub {
    my ($c, $msg) = @_;
    p $msg;
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
