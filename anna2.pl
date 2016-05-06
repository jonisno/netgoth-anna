#!/usr/bin/env perl
use Mojo::Base -strict;

use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Mojo::IRC;
use Mojo::IOLoop;
use Parse::IRC;
use Mojo::UserAgent;
use Anna::Model;
use Config::General;
use Net::Twitter::Lite::WithAPIv1_1;
use DateTime;
use DateTime::Format::Duration;
use DateTime::Format::ISO8601;

my %config = Config::General->new('./conf/anna.conf')->getall;

state $db = Anna::Model->connect(
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
state $irc = Mojo::IRC->new(
  nick => $config{nick},
  user => $config{username},
  name => $config{displayname},
  server => "$config{server}"
);
state $ua      = Mojo::UserAgent->new;
state $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
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

		# Just log all messages
		$db->resultset('Log')->create({ nick => $nick, message => $message });

		# The danger of uncommented code, this was probably for a good reason,
		# but I don't know why.
		if (lc $chan eq lc $c->nick || lc $nick eq lc $c->nick) {
      return;
    }

		# Update user record so we !seen works.
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', last_active => 'now()', online_now => 't' });

		# If twitter link, fetch data and show it.
		# Should probably be moved out of here.
    if( $message =~ /https:\/\/twitter.com\/\w+\/status(?:es)?\/(\d+)/ ) {
      my $status = $twitter->show_status($1);
      my $tweet = $status->{text};
      $tweet =~ s/\R+/\ /g;
      my @expandable = $status->{entities};
      $tweet =~ s/https?:\/\/t\.co\/\w+//g;
      for (@expandable) {
        $tweet .= sprintf(' %s', $_->{expanded_url}) for @{$_->{media}};
      }
      return $irc->write(PRIVMSG => $chan => "[Twitter] \@$status->{user}->{screen_name}: $tweet");
    }

		# Same as above, fetching data about youtube urls.
		if ($message =~ /(https?:\/\/(?:www\.)?(youtu\.be|youtube\.com).*)(?:\s|$)/i) {
			my $parselink = Mojo::URL->new($1);
			my $domain = $2;
			my $id;
			$id = $parselink->query->param('v') if $domain =~ /^youtube\.com$/i;
			($id = $parselink->path) =~ s/^\/// if $domain =~ /^youtu\.be$/i;
			my $url = sprintf(
				'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&key=%s&id=%s',
				$config{youtube_key},
				$id
			);
			my $json = $ua->get($url)->res->json;
			return unless $json;
			my $vid = shift @{$json->{items}};
			my ($h, $m) = ($vid->{contentDetails}{duration} =~ /(\d+)M(\d+)S/m);
			$h = sprintf('%02d', $h);
			$m = sprintf('%02d', $m);
			return $irc->write(PRIVMSG => $chan => "Title: $vid->{snippet}{title} [$h:$m]");
		}

		# Sort out karma, this feels a bit yolo, but it works for now.
    my $karma = $db->resultset('Karma');
    while($message =~ /(\+\+|--)([^\s\-+]+(?:[\-+][^\s\-+]+)*)|([^\s\-+]+(?:[\-+][^\s\-+]+)*)(\+\+|--)/g) {
        return if (defined $2 && $2 =~ /$nick/i);
        return if (defined $3 && $3 =~ /$nick/i);
        if ((defined $1 && $1 eq '++') || (defined $4 && $4 eq '++')) {
            $karma->create({ value => $3//$2, score => 1});
        } else {
            $karma->create({ value => $3//$2, score => '-1'});
        }
    }

    my @cmds = split / /, $message;

		# Here we deal with ! commands.
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
        return $irc->write(PRIVMSG => $chan => "I have no quote matching $cmds[1]") unless $quote;
        return $irc->write(PRIVMSG => $chan => $quote->quote);
      }

      if ( $match =~ /^addquote$/i && scalar @cmds > 1) {
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

			# !seen command with added sassiness
      if ( $match =~ /^seen$/i ) {
        return unless $cmds[1];
        my $user = $db->resultset('Users')->find({ nick => { ilike => $cmds[1] }});
        return $irc->write(PRIVMSG => $chan => "Are you fucking stupid or something?") if $cmds[1] eq $c->nick;
        return $irc->write(PRIVMSG => $chan => "$nick: I have never seen $cmds[1]") unless $user;
        return $irc->write(PRIVMSG => $chan => "Oh, fuck off.") if $user->nick =~ /$nick/i;

				# Holy shit motherfucker. Better sort this out.
        my $duration;
        $user->online_now && $user->last_active ? $duration = DateTime->now - $user->last_active : $duration = DateTime->now - $user->last_seen;
        my @pattern;
        $duration->years == 1 ? push @pattern, '%Y year' : push @pattern, '%Y years' unless $duration->years == 0;
        $duration->months == 1 ? push @pattern, '%m month' : push @pattern, '%m months' unless $duration->months == 0;
        $duration->weeks == 1 ? push @pattern, '%m week' : push @pattern, '%m weeks' unless $duration->weeks == 0;
        $duration->days == 1 ? push @pattern, '%e day' : push @pattern, '%e days' unless $duration->days == 0;
        $duration->hours == 1 ? push @pattern,'%H hour' : push @pattern, '%H hours' unless $duration->hours == 0;
        $duration->minutes == 1 ? push @pattern, '%M minute' : push @pattern, '%M minutes' unless $duration->minutes == 0;
        $duration->seconds == 1 ? push @pattern, '%S second' : push @pattern, '%S seconds' unless $duration->seconds == 0;
        my $dtf = DateTime::Format::Duration->new( pattern => join(', ', @pattern), normalize => 1 );
        return $irc->write(PRIVMSG => $chan => sprintf('%s: %s was seen %s ago', $nick, $user->nick, $dtf->format_duration($duration)));
      }

      if ( $match =~ /^help$/i ) {
        return $irc->write(NOTICE => $nick => 'Help for Anna: !karma <text> to find karma for something, !top and !bottom for max and min karma, !quote for random quote, !quote <term> to search quotes, !addquote <text> to add a quote, !stats for channel statistics and !seen <nick>.');
      }

      if ( $match =~ /^anna$/i ) {
        return $irc->write(PRIVMSG => $chan => 'https://www.youtube.com/watch?v=zf2wbRWb9xI');
      }

      if ( $match =~ /^source$/i ) {
        return $irc->write(PRIVMSG => $chan => 'My source is at https://github.com/jonisno/netgoth-anna and I\'m currently on the develop branch.');
      }

			# This is hairy af, should add a TODO to do something about it.
			#
			# TODO: sort this shit out.
      if ( $match =~ /^bing$/i ) {
				shift @cmds;
				my $searchstring = join ' ', @cmds;
				use Mojo::Util qw(b64_encode);
				(my $auth =  b64_encode "$config{bing_account}:$config{bing_account}") =~ s/\n//g;
				my $tx = $ua->get("https://api.datamarket.azure.com/Bing/Search/v1/Web" =>
					{ Authorization => "Basic $auth" } => form => {
						Query => "'$searchstring'",
						'$format' => 'JSON',
						Options => "'DisableLocationDetection'",
						WebSearchOptions => "'DisableQueryAlterations'",
						Adult => "'Off'"
					});
				my $results = $tx->res->json;
				return $irc->write(PRIVMSG => $chan => "No results for: $searchstring") unless $results;
				my $res = $results->{d}->{results}[0];
				return $irc->write(PRIVMSG => $chan => "$res->{Description} - $res->{Url}");
      }
    }
});

# Whenever we join a channel we get updated info about all the nicks there.
# Update the data and move on.
$irc->on(irc_rpl_namreply => sub {
    my ($c,$raw) = @_;
    my @online = split / /, @{$raw->{params}}[3];
    s/[@\+&]// for @online;
    $db->resultset('Users')->update_all({ online_now => 'f' });
    $db->resultset('Users')->find_or_create({ nick => $_ })->update({ nick => $_, last_seen => 'now()', online_now => 't' }) for @online;
  }
);

# Update user data whenever someone joins the channel.
$irc->on(irc_join => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    return if $nick eq $c->nick;
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', online_now => 't' });
});

# Update user data whenever someone parts the channel.
$irc->on(irc_part => sub {
    my ($c, $raw) = @_;
    my ($nick) = split /!/, $raw->{prefix};
    my ($chan) = @{$raw->{params}};
    $db->resultset('Users')->find_or_create({ nick => $nick })->update({ last_seen => 'now()', online_now => 'f' });
});


# I don't even.
$irc->on(error => sub {
    my ($c, $err) = @_;
    warn $err;
});

# Does what it says on the package, reconnect anywhere from 10-40 seconds after disconnect.
sub _reconnect_in {
  return 10 + int rand 30;
}

$irc->connect(\&on_connect);
Mojo::IOLoop->start;

1;
