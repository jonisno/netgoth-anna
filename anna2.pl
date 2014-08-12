#!/usr/bin/perl
use Mojo::Base -strict;
use 5.014;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Mojo::IRC;
use Mojo::IOLoop;
use Parse::IRC;
use Mojo::UserAgent;;
use Anna::Model;
use Config::General;
use Net::Twitter::Lite::WithAPIv1_1;
use DateTime;
use DateTime::Format::Duration;
use Data::Printer;

my %config = Config::General->new('./conf/anna.conf')->getall;

my $db = Anna::Model->connect(
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
    if (lc $chan eq lc $c->nick || lc $nick eq lc $c->nick) {
      return;
    }
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_active => 'now()' });

    if( $message =~ /https:\/\/twitter.com\/\w+\/status(?:es)?\/(\d+)/ ) {
      my $status = $twitter->show_status($1);
      my $tweet = $status->{text};
      p $tweet;
      $tweet =~ s/\R+/\ /g;
      return $irc->write(PRIVMSG => $chan => "[Twitter] \@$status->{user}->{screen_name}: $tweet");
    }

    my $karma = $db->resultset('Karma');
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
        my $quote = $db->resultset('Quote');
        if (scalar @cmds == 1 ) {
          $quote = $quote->find_random;
        } else {
          $quote = $quote->search_random($cmds[1]);
        }
        return $irc->write(PRIVMSG => $chan => $quote->quote);
      }

      if ( $1 =~ /^addquote$/i ) {
        shift @cmds;
        $db->resultset('Quote')->create({ added_by => $nick, quote => join ' ', @cmds });
        return;
      }

      if ( $1 =~ /^top$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Top 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->highest(5) );
      }

      if ( $1 =~ /^bottom$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Bottom 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->lowest(5) );
      }

      if ( $1 =~ /^stats$/i ) {
        return $irc->write(PRIVMSG => $chan => "$nick: http://goatse.co.uk/irc/orgy.html");
      }

      if ( $1 =~ /^help$/i ) {
        return $irc->write(NOTICE => $nick => 'Help for Anna: !karma <text> to find karma for something, !top and !bottom for max and min karma, !quote for random quote, !quote <term> to search quotes, !addquote <text> to add a quote, !stats for channel statistics');
      }
    }
});

$irc->on(irc_rpl_namreply => sub {
    my ($c,$raw) = @_;
    my @online = split / /, @{$raw->{params}}[3];
    s/[@\+&]// for @online;
    $db->resultset('Users')->find_or_create({ nick => $_ })->update({ last_seen => 'now()', online_now => 't' }) for @online;
  }
);

$irc->on(irc_join => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    return if lc $nick eq lc $c->nick;
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', online_now => 't' });
});

$irc->on(irc_part => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', online_now => 'f' });
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
