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
  my ($self, $error) = @_;
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
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', last_active => 'now()', online_now => 't' });

    if( $message =~ /https:\/\/twitter.com\/\w+\/status(?:es)?\/(\d+)/ ) {
      my $status = $twitter->show_status($1);
      my $tweet = $status->{text};
      p $tweet;
      $tweet =~ s/\R+/\ /g;
      return $irc->write(PRIVMSG => $chan => "[Twitter] \@$status->{user}->{screen_name}: $tweet");
    }

    my $karma = $db->resultset('Karma');
    if($message =~ /\+{2}(\S+)|(\S+)\+{2}/) {
      return if ($1 && $1 =~ /$nick/i);
      return if ($2 && $2 =~ /$nick/i);
      $karma->create({ value => $1//$2, score => 1 });
    }

    if($message =~ /-{2}(\S+)|(\S+)-{2}/) {
      return if ($1 && $1 =~ /$nick/i);
      return if ($2 && $2 =~ /$nick/i);
      $karma->create({ value => $1//$2, score => '-1' });
    }

    my @cmds = split / /, $message;

    if ($cmds[0] =~ /^!(\w+)/) {
      my $match = $1;

      if ( $match =~ /^karma$/i ) {
        my $rs = $db->resultset('Karma')->get_totals($cmds[1]);
        return $c->write(PRIVMSG => $chan => "$cmds[1] has $rs->{tot} karma. (+$rs->{pos},-$rs->{neg})");
      }

      if ( $match =~ /^quote$/i ) {
        my $quote = $db->resultset('Quote');
        if (scalar @cmds == 1 ) {
          $quote = $quote->find_random;
        } else {
          $quote = $quote->search_random($cmds[1]);
        }
        return $irc->write(PRIVMSG => $chan => $quote->quote);
      }

      if ( $match =~ /^addquote$/i ) {
        shift @cmds;
        $db->resultset('Quote')->create({ added_by => $nick, quote => join ' ', @cmds });
        return;
      }

      if ( $match =~ /^top$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Top 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->highest(5) );
      }

      if ( $match =~ /^bottom$/i ) {
        return $irc->write(PRIVMSG => $chan => 'Bottom 5 - '. join '. ', map { $_->value.': '.$_->score } $karma->lowest(5) );
      }

      if ( $match =~ /^stats$/i ) {
        return $irc->write(PRIVMSG => $chan => "$nick: http://goatse.co.uk/irc/orgy.html");
      }

      if ( $match =~ /^seen$/i ) {
        return unless $cmds[1];
        my $user = $db->resultset('Users')->find({ nick => { ilike => $cmds[1] }});
        return $irc->write(PRIVMSG => $chan => "Are you fucking stupid or something?") if lc $cmds[1] eq lc $c->nick;
        return $irc->write(PRIVMSG => $chan => "$nick: I have never seen $cmds[1]") unless $user;
        return $irc->write(PRIVMSG => $chan => "Oh, fuck off.") if $user->nick =~ /$nick/i;
        my $duration;
        $user->online_now && $user->last_active ? $duration = DateTime->now - $user->last_active : $duration = DateTime->now - $user->last_seen;
        my @pattern;
        $duration->years == 1 ? push @pattern, '%Y year' : push @pattern, '%Y years' unless $duration->years == 0;
        $duration->months == 1 ? push @pattern, '%m month' : push @pattern, '%m months' unless $duration->months == 0;
        $duration->days == 1 ? push @pattern, '%e day' : push @pattern, '%e days' unless $duration->days == 0;
        $duration->hours == 1 ? push @pattern,'%H hour' : push @pattern, '%H hours' unless $duration->hours == 0;
        $duration->minutes == 1 ? push @pattern, '%M minute' : push @pattern, '%M minutes' unless $duration->minutes == 0;
        $duration->seconds == 1 ? push @pattern, '%S second' : push @pattern, '%S seconds' unless $duration->seconds == 0;
        my $dtf = DateTime::Format::Duration->new( pattern => join(', ', @pattern), normalize => 1 );
        if($user->online_now && $user->last_active) {
          return $irc->write(PRIVMSG => $chan => sprintf('%s: %s was last active %s ago', $nick, $user->nick, $dtf->format_duration($duration)));
        } else {
          return $irc->write(PRIVMSG => $chan => sprintf('%s: %s was last seen online %s ago', $nick, $user->nick, $dtf->format_duration($duration)));
        }
      }

      if ( $match =~ /^help$/i ) {
        return $irc->write(NOTICE => $nick => 'Help for Anna: !karma <text> to find karma for something, !top and !bottom for max and min karma, !quote for random quote, !quote <term> to search quotes, !addquote <text> to add a quote, !stats for channel statistics and !seen <nick>.');
      }
    }
});

$irc->on(irc_rpl_namreply => sub {
    my ($c,$raw) = @_;
    my @online = split / /, @{$raw->{params}}[3];
    s/[@\+&]// for @online;
    $db->resultset('Users')->find_or_create({ nick => { ilike => $_ }})->update({ last_seen => 'now()', online_now => 't' }) for @online;
  }
);

$irc->on(irc_join => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    return if lc $nick eq lc $c->nick;
    $db->resultset('Users')->find_or_create({ nick => { ilike => $nick }})->update({ last_seen => 'now()', online_now => 't' });
});

$irc->on(irc_part => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    $db->resultset('Users')->find_or_create({ nick => { ilike => $nick }})->update({ last_seen => 'now()', online_now => 'f' });
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
