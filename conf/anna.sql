--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: adult_logger; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE adult_logger (
    id_number integer NOT NULL,
    nickname text,
    url text,
    channel text,
    reported boolean DEFAULT false NOT NULL,
    domain character varying(255)
);


ALTER TABLE adult_logger OWNER TO anna;

--
-- Name: karma; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE karma (
    id integer NOT NULL,
    value text NOT NULL,
    score smallint,
    "time" timestamp without time zone DEFAULT now()
);


ALTER TABLE karma OWNER TO anna;

--
-- Name: bot_karma_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE bot_karma_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bot_karma_id_seq OWNER TO anna;

--
-- Name: bot_karma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE bot_karma_id_seq OWNED BY karma.id;


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE quotes (
    id integer NOT NULL,
    added_by character varying(100) DEFAULT 'Unknown'::character varying NOT NULL,
    quote text NOT NULL,
    added_on timestamp without time zone DEFAULT now()
);


ALTER TABLE quotes OWNER TO anna;

--
-- Name: bot_quote_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE bot_quote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bot_quote_id_seq OWNER TO anna;

--
-- Name: bot_quote_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE bot_quote_id_seq OWNED BY quotes.id;


--
-- Name: bot_url_log; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE bot_url_log (
    id integer NOT NULL,
    nickname character varying(100) DEFAULT 'Unknown'::character varying NOT NULL,
    url text NOT NULL,
    domain text NOT NULL,
    channel character varying(200),
    "time" timestamp without time zone DEFAULT now() NOT NULL,
    disabled boolean DEFAULT false
);


ALTER TABLE bot_url_log OWNER TO anna;

--
-- Name: bot_url_log_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE bot_url_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bot_url_log_id_seq OWNER TO anna;

--
-- Name: bot_url_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE bot_url_log_id_seq OWNED BY bot_url_log.id;


--
-- Name: irclog; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE irclog (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    said_at timestamp with time zone DEFAULT now(),
    nick text NOT NULL,
    message text NOT NULL
);


ALTER TABLE irclog OWNER TO anna;

--
-- Name: log_temp_id_number_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE log_temp_id_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE log_temp_id_number_seq OWNER TO anna;

--
-- Name: log_temp_id_number_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE log_temp_id_number_seq OWNED BY adult_logger.id_number;


--
-- Name: users; Type: TABLE; Schema: public; Owner: anna; Tablespace: 
--

CREATE TABLE users (
    nick text NOT NULL,
    id integer NOT NULL,
    last_seen timestamp with time zone
);


ALTER TABLE users OWNER TO anna;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: anna
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO anna;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: anna
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id_number; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY adult_logger ALTER COLUMN id_number SET DEFAULT nextval('log_temp_id_number_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY bot_url_log ALTER COLUMN id SET DEFAULT nextval('bot_url_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY karma ALTER COLUMN id SET DEFAULT nextval('bot_karma_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY quotes ALTER COLUMN id SET DEFAULT nextval('bot_quote_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: anna
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: bot_karma_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY karma
    ADD CONSTRAINT bot_karma_pkey PRIMARY KEY (id);


--
-- Name: bot_quote_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY quotes
    ADD CONSTRAINT bot_quote_pkey PRIMARY KEY (id);


--
-- Name: bot_url_log_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY bot_url_log
    ADD CONSTRAINT bot_url_log_pkey PRIMARY KEY (id);


--
-- Name: bot_url_log_url_key; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY bot_url_log
    ADD CONSTRAINT bot_url_log_url_key UNIQUE (url);


--
-- Name: irclog_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY irclog
    ADD CONSTRAINT irclog_pkey PRIMARY KEY (id);


--
-- Name: logger_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY adult_logger
    ADD CONSTRAINT logger_pkey PRIMARY KEY (id_number);


--
-- Name: url_must_be_unique; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY adult_logger
    ADD CONSTRAINT url_must_be_unique UNIQUE (url);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: anna; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (nick);


--
-- Name: users_lower_idx; Type: INDEX; Schema: public; Owner: anna; Tablespace: 
--

CREATE INDEX users_lower_idx ON users USING btree (lower(nick));


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

