create table if not exists bot_quote (
  id        serial,
  added_by  varchar(100) not null default 'Unknown',
  quote     text not null,
  added_on  timestamp default now(),
  primary key(id)
);

drop table if exists bot_url_log;
create table bot_url_log (
  id        serial,
  nickname  varchar(100) not null default 'Unknown',
  url       text unique not null unique,
  domain    text not null,
  channel   varchar(200),
  time      timestamp default now() not null,
  disabled  boolean default false,
  primary key(id)
);

drop table if exists bot_karma;
create table bot_karma (
  id          serial,
  value       text not null,
  score       smallint,
  time        timestamp default now(),
  primary key(id)
);
