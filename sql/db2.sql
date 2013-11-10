create table if not exists bot_quote (
  id        serial,
  added_by  varchar(100) not null default 'Unknown',
  quote     text not null,
  added_on  timestamp default now(),
  primary key(id)
);

create table if not exists bot_url_log (
  id        serial,
  first_added_by  varchar(100) not null default 'Unknown',
  url       text unique not null unique,
  domain    text not null,
  channel   varchar(200),
  first_added_on  timestamp default now() not null,
  active    boolean default true not null,
  primary key(id)
);

drop table if exists bot_karma;

create table bot_karma (
  id          serial,
  value       text not null,
  score       smallint,
  voted_on    timestamp default now(),
  primary key(id)
);
