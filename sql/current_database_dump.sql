--
-- PostgreSQL database dump
--

\restrict qZzUMxachcmbAyLQFlY8wV7KGkWAWHIFl1VxRbZ5pUbRlkHmPeRqMR9aP2awNJb

-- Dumped from database version 16.11 (Homebrew)
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.room DROP CONSTRAINT IF EXISTS room_hotel_id_fkey;
ALTER TABLE IF EXISTS ONLY public.renting DROP CONSTRAINT IF EXISTS renting_source_booking_id_fkey;
ALTER TABLE IF EXISTS ONLY public.renting DROP CONSTRAINT IF EXISTS renting_room_id_fkey;
ALTER TABLE IF EXISTS ONLY public.renting DROP CONSTRAINT IF EXISTS renting_employee_id_fkey;
ALTER TABLE IF EXISTS ONLY public.renting DROP CONSTRAINT IF EXISTS renting_customer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.payment DROP CONSTRAINT IF EXISTS payment_renting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.payment DROP CONSTRAINT IF EXISTS payment_employee_id_fkey;
ALTER TABLE IF EXISTS ONLY public.hotel DROP CONSTRAINT IF EXISTS hotel_chain_id_fkey;
ALTER TABLE IF EXISTS ONLY public.employee DROP CONSTRAINT IF EXISTS employee_person_id_fkey;
ALTER TABLE IF EXISTS ONLY public.employee DROP CONSTRAINT IF EXISTS employee_hotel_id_fkey;
ALTER TABLE IF EXISTS ONLY public.customer DROP CONSTRAINT IF EXISTS customer_person_id_fkey;
ALTER TABLE IF EXISTS ONLY public.booking DROP CONSTRAINT IF EXISTS booking_room_id_fkey;
ALTER TABLE IF EXISTS ONLY public.booking DROP CONSTRAINT IF EXISTS booking_customer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.booking DROP CONSTRAINT IF EXISTS booking_created_by_employee_id_fkey;
DROP TRIGGER IF EXISTS trg_renting_validate ON public.renting;
DROP TRIGGER IF EXISTS trg_renting_status_sync ON public.renting;
DROP TRIGGER IF EXISTS trg_booking_validate ON public.booking;
DROP TRIGGER IF EXISTS trg_booking_status_sync ON public.booking;
DROP TRIGGER IF EXISTS trg_archive_renting ON public.renting;
DROP TRIGGER IF EXISTS trg_archive_booking ON public.booking;
DROP INDEX IF EXISTS public.idx_room_capacity_price_status;
DROP INDEX IF EXISTS public.idx_renting_room_dates;
DROP INDEX IF EXISTS public.idx_hotel_filtering;
DROP INDEX IF EXISTS public.idx_booking_room_dates;
ALTER TABLE IF EXISTS ONLY public.room DROP CONSTRAINT IF EXISTS room_pkey;
ALTER TABLE IF EXISTS ONLY public.room DROP CONSTRAINT IF EXISTS room_hotel_id_room_number_key;
ALTER TABLE IF EXISTS ONLY public.renting DROP CONSTRAINT IF EXISTS renting_pkey;
ALTER TABLE IF EXISTS ONLY public.person DROP CONSTRAINT IF EXISTS person_pkey;
ALTER TABLE IF EXISTS ONLY public.person DROP CONSTRAINT IF EXISTS person_legal_id_key;
ALTER TABLE IF EXISTS ONLY public.person DROP CONSTRAINT IF EXISTS person_email_key;
ALTER TABLE IF EXISTS ONLY public.payment DROP CONSTRAINT IF EXISTS payment_pkey;
ALTER TABLE IF EXISTS ONLY public.hotel DROP CONSTRAINT IF EXISTS hotel_pkey;
ALTER TABLE IF EXISTS ONLY public.hotel_chain DROP CONSTRAINT IF EXISTS hotel_chain_pkey;
ALTER TABLE IF EXISTS ONLY public.hotel DROP CONSTRAINT IF EXISTS hotel_chain_id_hotel_name_key;
ALTER TABLE IF EXISTS ONLY public.hotel_chain DROP CONSTRAINT IF EXISTS hotel_chain_chain_name_key;
ALTER TABLE IF EXISTS ONLY public.employee DROP CONSTRAINT IF EXISTS employee_pkey;
ALTER TABLE IF EXISTS ONLY public.employee DROP CONSTRAINT IF EXISTS employee_person_id_key;
ALTER TABLE IF EXISTS ONLY public.customer DROP CONSTRAINT IF EXISTS customer_pkey;
ALTER TABLE IF EXISTS ONLY public.customer DROP CONSTRAINT IF EXISTS customer_person_id_key;
ALTER TABLE IF EXISTS ONLY public.booking DROP CONSTRAINT IF EXISTS booking_pkey;
ALTER TABLE IF EXISTS ONLY public.archive DROP CONSTRAINT IF EXISTS archive_pkey;
ALTER TABLE IF EXISTS public.room ALTER COLUMN room_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.renting ALTER COLUMN renting_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.person ALTER COLUMN person_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.payment ALTER COLUMN payment_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.hotel_chain ALTER COLUMN chain_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.hotel ALTER COLUMN hotel_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.employee ALTER COLUMN employee_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.customer ALTER COLUMN customer_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.booking ALTER COLUMN booking_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.archive ALTER COLUMN archive_id DROP DEFAULT;
DROP VIEW IF EXISTS public.v_hotel_capacity_aggregate;
DROP VIEW IF EXISTS public.v_available_rooms_per_area;
DROP SEQUENCE IF EXISTS public.room_room_id_seq;
DROP TABLE IF EXISTS public.room;
DROP SEQUENCE IF EXISTS public.renting_renting_id_seq;
DROP TABLE IF EXISTS public.renting;
DROP SEQUENCE IF EXISTS public.person_person_id_seq;
DROP TABLE IF EXISTS public.person;
DROP SEQUENCE IF EXISTS public.payment_payment_id_seq;
DROP TABLE IF EXISTS public.payment;
DROP SEQUENCE IF EXISTS public.hotel_hotel_id_seq;
DROP SEQUENCE IF EXISTS public.hotel_chain_chain_id_seq;
DROP TABLE IF EXISTS public.hotel_chain;
DROP TABLE IF EXISTS public.hotel;
DROP SEQUENCE IF EXISTS public.employee_employee_id_seq;
DROP TABLE IF EXISTS public.employee;
DROP SEQUENCE IF EXISTS public.customer_customer_id_seq;
DROP TABLE IF EXISTS public.customer;
DROP SEQUENCE IF EXISTS public.booking_booking_id_seq;
DROP TABLE IF EXISTS public.booking;
DROP SEQUENCE IF EXISTS public.archive_archive_id_seq;
DROP TABLE IF EXISTS public.archive;
DROP FUNCTION IF EXISTS public.fn_validate_room_availability();
DROP FUNCTION IF EXISTS public.fn_sync_room_status(target_room_id integer);
DROP FUNCTION IF EXISTS public.fn_archive_renting();
DROP FUNCTION IF EXISTS public.fn_archive_booking();
DROP FUNCTION IF EXISTS public.fn_after_renting_change();
DROP FUNCTION IF EXISTS public.fn_after_booking_change();
--
-- Name: fn_after_booking_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_after_booking_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM fn_sync_room_status(COALESCE(NEW.room_id, OLD.room_id));
  RETURN NULL;
END;
$$;


--
-- Name: fn_after_renting_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_after_renting_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM fn_sync_room_status(COALESCE(NEW.room_id, OLD.room_id));
  RETURN NULL;
END;
$$;


--
-- Name: fn_archive_booking(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_archive_booking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled') THEN
    INSERT INTO archive (
      record_type,
      source_booking_id,
      source_renting_id,
      chain_name,
      hotel_name,
      room_number,
      customer_full_name,
      customer_legal_id,
      start_date,
      end_date,
      final_status
    )
    SELECT
      'booking',
      NEW.booking_id,
      NULL,
      hc.chain_name,
      h.hotel_name,
      rm.room_number,
      p.first_name || ' ' || p.last_name,
      p.legal_id,
      NEW.start_date,
      NEW.end_date,
      NEW.status
    FROM room rm
    JOIN hotel h ON h.hotel_id = rm.hotel_id
    JOIN hotel_chain hc ON hc.chain_id = h.chain_id
    JOIN customer c ON c.customer_id = NEW.customer_id
    JOIN person p ON p.person_id = c.person_id
    WHERE rm.room_id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fn_archive_renting(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_archive_renting() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  total_paid NUMERIC(10,2);
BEGIN
  IF NEW.status IN ('completed', 'cancelled') THEN
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM payment
    WHERE renting_id = NEW.renting_id;

    INSERT INTO archive (
      record_type,
      source_booking_id,
      source_renting_id,
      chain_name,
      hotel_name,
      room_number,
      customer_full_name,
      customer_legal_id,
      start_date,
      end_date,
      final_status,
      amount_paid
    )
    SELECT
      'renting',
      NEW.source_booking_id,
      NEW.renting_id,
      hc.chain_name,
      h.hotel_name,
      rm.room_number,
      p.first_name || ' ' || p.last_name,
      p.legal_id,
      NEW.start_date,
      NEW.end_date,
      NEW.status,
      total_paid
    FROM room rm
    JOIN hotel h ON h.hotel_id = rm.hotel_id
    JOIN hotel_chain hc ON hc.chain_id = h.chain_id
    JOIN customer c ON c.customer_id = NEW.customer_id
    JOIN person p ON p.person_id = c.person_id
    WHERE rm.room_id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fn_sync_room_status(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_sync_room_status(target_room_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  has_renting BOOLEAN;
  has_booking BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM renting r
    WHERE r.room_id = target_room_id
      AND r.status = 'active'
      AND daterange(r.start_date, r.end_date, '[]') && daterange(CURRENT_DATE, CURRENT_DATE, '[]')
  ) INTO has_renting;

  SELECT EXISTS (
    SELECT 1 FROM booking b
    WHERE b.room_id = target_room_id
      AND b.status IN ('reserved', 'checked_in')
      AND daterange(b.start_date, b.end_date, '[]') && daterange(CURRENT_DATE, CURRENT_DATE, '[]')
  ) INTO has_booking;

  UPDATE room
  SET current_status = CASE
    WHEN has_renting THEN 'rented'
    WHEN has_booking THEN 'booked'
    ELSE 'available'
  END
  WHERE room_id = target_room_id
    AND current_status <> 'maintenance';
END;
$$;


--
-- Name: fn_validate_room_availability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validate_room_availability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  overlap_count INT;
BEGIN
  IF TG_TABLE_NAME = 'booking' THEN
    IF NEW.status IN ('reserved', 'checked_in') THEN
      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.room_id = NEW.room_id
        AND b.status IN ('reserved', 'checked_in')
        AND b.booking_id <> COALESCE(NEW.booking_id, -1)
        AND daterange(b.start_date, b.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping booking', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.room_id = NEW.room_id
        AND r.status = 'active'
        AND daterange(r.start_date, r.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping renting', NEW.room_id;
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'renting' THEN
    IF NEW.status = 'active' THEN
      SELECT COUNT(*) INTO overlap_count
      FROM renting r
      WHERE r.room_id = NEW.room_id
        AND r.status = 'active'
        AND r.renting_id <> COALESCE(NEW.renting_id, -1)
        AND daterange(r.start_date, r.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping renting', NEW.room_id;
      END IF;

      SELECT COUNT(*) INTO overlap_count
      FROM booking b
      WHERE b.room_id = NEW.room_id
        AND b.status IN ('reserved', 'checked_in')
        AND (NEW.source_booking_id IS NULL OR b.booking_id <> NEW.source_booking_id)
        AND daterange(b.start_date, b.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]');

      IF overlap_count > 0 THEN
        RAISE EXCEPTION 'Room % already has an overlapping booking', NEW.room_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.archive (
    archive_id integer NOT NULL,
    record_type character varying(20) NOT NULL,
    source_booking_id integer,
    source_renting_id integer,
    chain_name character varying(120) NOT NULL,
    hotel_name character varying(140) NOT NULL,
    room_number character varying(10) NOT NULL,
    customer_full_name character varying(180) NOT NULL,
    customer_legal_id character varying(30) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    final_status character varying(20) NOT NULL,
    amount_paid numeric(10,2),
    archived_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT archive_record_type_check CHECK (((record_type)::text = ANY ((ARRAY['booking'::character varying, 'renting'::character varying])::text[])))
);


--
-- Name: archive_archive_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.archive_archive_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: archive_archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.archive_archive_id_seq OWNED BY public.archive.archive_id;


--
-- Name: booking; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking (
    booking_id integer NOT NULL,
    room_id integer NOT NULL,
    customer_id integer NOT NULL,
    created_by_employee_id integer,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status character varying(20) DEFAULT 'reserved'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT booking_check CHECK ((end_date > start_date)),
    CONSTRAINT booking_status_check CHECK (((status)::text = ANY ((ARRAY['reserved'::character varying, 'checked_in'::character varying, 'cancelled'::character varying, 'completed'::character varying])::text[])))
);


--
-- Name: booking_booking_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.booking_booking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: booking_booking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.booking_booking_id_seq OWNED BY public.booking.booking_id;


--
-- Name: customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer (
    customer_id integer NOT NULL,
    person_id integer NOT NULL,
    registration_date date DEFAULT CURRENT_DATE NOT NULL
);


--
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customer_customer_id_seq OWNED BY public.customer.customer_id;


--
-- Name: employee; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee (
    employee_id integer NOT NULL,
    person_id integer NOT NULL,
    hotel_id integer NOT NULL,
    role_title character varying(80) NOT NULL,
    hired_on date DEFAULT CURRENT_DATE NOT NULL,
    is_manager boolean DEFAULT false NOT NULL
);


--
-- Name: employee_employee_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_employee_id_seq OWNED BY public.employee.employee_id;


--
-- Name: hotel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hotel (
    hotel_id integer NOT NULL,
    chain_id integer NOT NULL,
    hotel_name character varying(140) NOT NULL,
    category smallint NOT NULL,
    total_rooms integer NOT NULL,
    address_line character varying(255) NOT NULL,
    city character varying(100) NOT NULL,
    state_province character varying(100) NOT NULL,
    country character varying(80) NOT NULL,
    postal_code character varying(20) NOT NULL,
    contact_email character varying(120) NOT NULL,
    contact_phone character varying(30) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT hotel_category_check CHECK (((category >= 1) AND (category <= 5))),
    CONSTRAINT hotel_total_rooms_check CHECK ((total_rooms >= 1))
);


--
-- Name: hotel_chain; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hotel_chain (
    chain_id integer NOT NULL,
    chain_name character varying(120) NOT NULL,
    central_office_address character varying(255) NOT NULL,
    contact_email character varying(120) NOT NULL,
    contact_phone character varying(30) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: hotel_chain_chain_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hotel_chain_chain_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hotel_chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hotel_chain_chain_id_seq OWNED BY public.hotel_chain.chain_id;


--
-- Name: hotel_hotel_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hotel_hotel_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hotel_hotel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hotel_hotel_id_seq OWNED BY public.hotel.hotel_id;


--
-- Name: payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment (
    payment_id integer NOT NULL,
    renting_id integer NOT NULL,
    employee_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    method character varying(20) NOT NULL,
    paid_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT payment_method_check CHECK (((method)::text = ANY ((ARRAY['cash'::character varying, 'credit'::character varying, 'debit'::character varying, 'online'::character varying])::text[])))
);


--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_payment_id_seq OWNED BY public.payment.payment_id;


--
-- Name: person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person (
    person_id integer NOT NULL,
    legal_id character varying(30) NOT NULL,
    id_type character varying(20) NOT NULL,
    first_name character varying(80) NOT NULL,
    last_name character varying(80) NOT NULL,
    email character varying(120) NOT NULL,
    phone character varying(30) NOT NULL,
    address_line character varying(255) NOT NULL,
    CONSTRAINT person_id_type_check CHECK (((id_type)::text = ANY ((ARRAY['SIN'::character varying, 'SSN'::character varying, 'DL'::character varying, 'PASSPORT'::character varying])::text[])))
);


--
-- Name: person_person_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.person_person_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.person_person_id_seq OWNED BY public.person.person_id;


--
-- Name: renting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.renting (
    renting_id integer NOT NULL,
    room_id integer NOT NULL,
    customer_id integer NOT NULL,
    employee_id integer NOT NULL,
    source_booking_id integer,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT renting_check CHECK ((end_date > start_date)),
    CONSTRAINT renting_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: renting_renting_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.renting_renting_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: renting_renting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.renting_renting_id_seq OWNED BY public.renting.renting_id;


--
-- Name: room; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.room (
    room_id integer NOT NULL,
    hotel_id integer NOT NULL,
    room_number character varying(10) NOT NULL,
    capacity character varying(20) NOT NULL,
    base_price numeric(10,2) NOT NULL,
    has_sea_view boolean DEFAULT false NOT NULL,
    has_mountain_view boolean DEFAULT false NOT NULL,
    is_extendable boolean DEFAULT false NOT NULL,
    amenities text NOT NULL,
    issues text,
    current_status character varying(20) DEFAULT 'available'::character varying NOT NULL,
    CONSTRAINT room_base_price_check CHECK ((base_price > (0)::numeric)),
    CONSTRAINT room_capacity_check CHECK (((capacity)::text = ANY ((ARRAY['single'::character varying, 'double'::character varying, 'suite'::character varying, 'family'::character varying])::text[]))),
    CONSTRAINT room_current_status_check CHECK (((current_status)::text = ANY ((ARRAY['available'::character varying, 'booked'::character varying, 'rented'::character varying, 'maintenance'::character varying])::text[])))
);


--
-- Name: room_room_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.room_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: room_room_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.room_room_id_seq OWNED BY public.room.room_id;


--
-- Name: v_available_rooms_per_area; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_available_rooms_per_area AS
 SELECT h.city AS area,
    (count(*))::integer AS available_rooms
   FROM (public.room r
     JOIN public.hotel h ON ((h.hotel_id = r.hotel_id)))
  WHERE ((r.current_status)::text = 'available'::text)
  GROUP BY h.city
  ORDER BY h.city;


--
-- Name: v_hotel_capacity_aggregate; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_hotel_capacity_aggregate AS
 SELECT h.hotel_id,
    h.hotel_name,
    h.city,
    (sum(
        CASE r.capacity
            WHEN 'single'::text THEN 1
            WHEN 'double'::text THEN 2
            WHEN 'suite'::text THEN 3
            WHEN 'family'::text THEN 4
            ELSE 0
        END))::integer AS aggregated_capacity
   FROM (public.hotel h
     JOIN public.room r ON ((r.hotel_id = h.hotel_id)))
  GROUP BY h.hotel_id, h.hotel_name, h.city
  ORDER BY h.hotel_id;


--
-- Name: archive archive_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive ALTER COLUMN archive_id SET DEFAULT nextval('public.archive_archive_id_seq'::regclass);


--
-- Name: booking booking_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking ALTER COLUMN booking_id SET DEFAULT nextval('public.booking_booking_id_seq'::regclass);


--
-- Name: customer customer_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer ALTER COLUMN customer_id SET DEFAULT nextval('public.customer_customer_id_seq'::regclass);


--
-- Name: employee employee_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee ALTER COLUMN employee_id SET DEFAULT nextval('public.employee_employee_id_seq'::regclass);


--
-- Name: hotel hotel_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel ALTER COLUMN hotel_id SET DEFAULT nextval('public.hotel_hotel_id_seq'::regclass);


--
-- Name: hotel_chain chain_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel_chain ALTER COLUMN chain_id SET DEFAULT nextval('public.hotel_chain_chain_id_seq'::regclass);


--
-- Name: payment payment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ALTER COLUMN payment_id SET DEFAULT nextval('public.payment_payment_id_seq'::regclass);


--
-- Name: person person_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person ALTER COLUMN person_id SET DEFAULT nextval('public.person_person_id_seq'::regclass);


--
-- Name: renting renting_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting ALTER COLUMN renting_id SET DEFAULT nextval('public.renting_renting_id_seq'::regclass);


--
-- Name: room room_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room ALTER COLUMN room_id SET DEFAULT nextval('public.room_room_id_seq'::regclass);


--
-- Data for Name: archive; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.archive (archive_id, record_type, source_booking_id, source_renting_id, chain_name, hotel_name, room_number, customer_full_name, customer_legal_id, start_date, end_date, final_status, amount_paid, archived_at) VALUES (1, 'booking', 1, NULL, 'Aurora Stays', 'Hotel 1', '101', 'CustomerFirst1 CustomerLast1', 'CUST00001', '2026-03-12', '2026-03-14', 'completed', NULL, '2026-03-11 16:12:29.222032');
INSERT INTO public.archive (archive_id, record_type, source_booking_id, source_renting_id, chain_name, hotel_name, room_number, customer_full_name, customer_legal_id, start_date, end_date, final_status, amount_paid, archived_at) VALUES (2, 'booking', 2, NULL, 'Aurora Stays', 'Hotel 2', '101', 'CustomerFirst2 CustomerLast2', 'CUST00002', '2026-03-13', '2026-03-15', 'completed', NULL, '2026-03-11 16:12:29.222032');
INSERT INTO public.archive (archive_id, record_type, source_booking_id, source_renting_id, chain_name, hotel_name, room_number, customer_full_name, customer_legal_id, start_date, end_date, final_status, amount_paid, archived_at) VALUES (3, 'renting', NULL, 1, 'Harborline Suites', 'Hotel 31', '101', 'CustomerFirst21 CustomerLast21', 'CUST00021', '2026-03-10', '2026-03-13', 'completed', 135.00, '2026-03-11 16:12:29.222032');
INSERT INTO public.archive (archive_id, record_type, source_booking_id, source_renting_id, chain_name, hotel_name, room_number, customer_full_name, customer_legal_id, start_date, end_date, final_status, amount_paid, archived_at) VALUES (4, 'renting', NULL, 2, 'Harborline Suites', 'Hotel 32', '101', 'CustomerFirst22 CustomerLast22', 'CUST00022', '2026-03-10', '2026-03-13', 'completed', 150.00, '2026-03-11 16:12:29.222032');


--
-- Data for Name: booking; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (3, 3, 3, 3, '2026-03-14', '2026-03-16', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (4, 4, 4, 4, '2026-03-15', '2026-03-17', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (5, 5, 5, 5, '2026-03-16', '2026-03-18', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (6, 6, 6, 6, '2026-03-17', '2026-03-19', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (7, 7, 7, 7, '2026-03-18', '2026-03-20', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (8, 8, 8, 8, '2026-03-19', '2026-03-21', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (9, 9, 9, 9, '2026-03-20', '2026-03-22', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (10, 10, 10, 10, '2026-03-21', '2026-03-23', 'reserved', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (11, 11, 11, 11, '2026-03-22', '2026-03-24', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (12, 12, 12, 12, '2026-03-23', '2026-03-25', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (13, 13, 13, 13, '2026-03-24', '2026-03-26', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (14, 14, 14, 14, '2026-03-25', '2026-03-27', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (15, 15, 15, 15, '2026-03-26', '2026-03-28', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (16, 16, 16, 16, '2026-03-27', '2026-03-29', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (17, 17, 17, 17, '2026-03-28', '2026-03-30', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (18, 18, 18, 18, '2026-03-29', '2026-03-31', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (19, 19, 19, 19, '2026-03-30', '2026-04-01', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (20, 20, 20, 20, '2026-03-31', '2026-04-02', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (1, 1, 1, 1, '2026-03-12', '2026-03-14', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.booking (booking_id, room_id, customer_id, created_by_employee_id, start_date, end_date, status, created_at) VALUES (2, 2, 2, 2, '2026-03-13', '2026-03-15', 'completed', '2026-03-11 16:12:29.222032');


--
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (1, 1, '2026-03-10');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (2, 2, '2026-03-09');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (3, 3, '2026-03-08');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (4, 4, '2026-03-07');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (5, 5, '2026-03-06');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (6, 6, '2026-03-05');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (7, 7, '2026-03-04');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (8, 8, '2026-03-03');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (9, 9, '2026-03-02');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (10, 10, '2026-03-01');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (11, 11, '2026-02-28');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (12, 12, '2026-02-27');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (13, 13, '2026-02-26');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (14, 14, '2026-02-25');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (15, 15, '2026-02-24');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (16, 16, '2026-02-23');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (17, 17, '2026-02-22');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (18, 18, '2026-02-21');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (19, 19, '2026-02-20');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (20, 20, '2026-02-19');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (21, 21, '2026-02-18');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (22, 22, '2026-02-17');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (23, 23, '2026-02-16');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (24, 24, '2026-02-15');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (25, 25, '2026-02-14');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (26, 26, '2026-02-13');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (27, 27, '2026-02-12');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (28, 28, '2026-02-11');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (29, 29, '2026-02-10');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (30, 30, '2026-02-09');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (31, 31, '2026-02-08');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (32, 32, '2026-02-07');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (33, 33, '2026-02-06');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (34, 34, '2026-02-05');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (35, 35, '2026-02-04');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (36, 36, '2026-02-03');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (37, 37, '2026-02-02');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (38, 38, '2026-02-01');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (39, 39, '2026-01-31');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (40, 40, '2026-01-30');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (41, 41, '2026-01-29');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (42, 42, '2026-01-28');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (43, 43, '2026-01-27');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (44, 44, '2026-01-26');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (45, 45, '2026-01-25');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (46, 46, '2026-01-24');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (47, 47, '2026-01-23');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (48, 48, '2026-01-22');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (49, 49, '2026-01-21');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (50, 50, '2026-01-20');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (51, 51, '2026-01-19');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (52, 52, '2026-01-18');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (53, 53, '2026-01-17');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (54, 54, '2026-01-16');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (55, 55, '2026-01-15');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (56, 56, '2026-01-14');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (57, 57, '2026-01-13');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (58, 58, '2026-01-12');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (59, 59, '2026-01-11');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (60, 60, '2026-01-10');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (61, 61, '2026-01-09');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (62, 62, '2026-01-08');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (63, 63, '2026-01-07');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (64, 64, '2026-01-06');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (65, 65, '2026-01-05');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (66, 66, '2026-01-04');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (67, 67, '2026-01-03');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (68, 68, '2026-01-02');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (69, 69, '2026-01-01');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (70, 70, '2025-12-31');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (71, 71, '2025-12-30');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (72, 72, '2025-12-29');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (73, 73, '2025-12-28');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (74, 74, '2025-12-27');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (75, 75, '2025-12-26');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (76, 76, '2025-12-25');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (77, 77, '2025-12-24');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (78, 78, '2025-12-23');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (79, 79, '2025-12-22');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (80, 80, '2025-12-21');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (81, 81, '2025-12-20');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (82, 82, '2025-12-19');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (83, 83, '2025-12-18');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (84, 84, '2025-12-17');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (85, 85, '2025-12-16');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (86, 86, '2025-12-15');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (87, 87, '2025-12-14');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (88, 88, '2025-12-13');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (89, 89, '2025-12-12');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (90, 90, '2025-12-11');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (91, 91, '2025-12-10');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (92, 92, '2025-12-09');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (93, 93, '2025-12-08');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (94, 94, '2025-12-07');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (95, 95, '2025-12-06');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (96, 96, '2025-12-05');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (97, 97, '2025-12-04');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (98, 98, '2025-12-03');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (99, 99, '2025-12-02');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (100, 100, '2025-12-01');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (101, 101, '2025-11-30');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (102, 102, '2025-11-29');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (103, 103, '2025-11-28');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (104, 104, '2025-11-27');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (105, 105, '2025-11-26');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (106, 106, '2025-11-25');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (107, 107, '2025-11-24');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (108, 108, '2025-11-23');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (109, 109, '2025-11-22');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (110, 110, '2025-11-21');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (111, 111, '2025-11-20');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (112, 112, '2025-11-19');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (113, 113, '2025-11-18');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (114, 114, '2025-11-17');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (115, 115, '2025-11-16');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (116, 116, '2025-11-15');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (117, 117, '2025-11-14');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (118, 118, '2025-11-13');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (119, 119, '2025-11-12');
INSERT INTO public.customer (customer_id, person_id, registration_date) VALUES (120, 120, '2025-11-11');


--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (1, 121, 1, 'Manager', '2026-03-10', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (2, 122, 1, 'Front Desk Agent', '2026-03-09', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (3, 123, 2, 'Manager', '2026-03-08', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (4, 124, 2, 'Front Desk Agent', '2026-03-07', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (5, 125, 3, 'Manager', '2026-03-06', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (6, 126, 3, 'Front Desk Agent', '2026-03-05', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (7, 127, 4, 'Manager', '2026-03-04', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (8, 128, 4, 'Front Desk Agent', '2026-03-03', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (9, 129, 5, 'Manager', '2026-03-02', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (10, 130, 5, 'Front Desk Agent', '2026-03-01', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (11, 131, 6, 'Manager', '2026-02-28', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (12, 132, 6, 'Front Desk Agent', '2026-02-27', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (13, 133, 7, 'Manager', '2026-02-26', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (14, 134, 7, 'Front Desk Agent', '2026-02-25', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (15, 135, 8, 'Manager', '2026-02-24', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (16, 136, 8, 'Front Desk Agent', '2026-02-23', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (17, 137, 9, 'Manager', '2026-02-22', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (18, 138, 9, 'Front Desk Agent', '2026-02-21', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (19, 139, 10, 'Manager', '2026-02-20', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (20, 140, 10, 'Front Desk Agent', '2026-02-19', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (21, 141, 11, 'Manager', '2026-02-18', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (22, 142, 11, 'Front Desk Agent', '2026-02-17', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (23, 143, 12, 'Manager', '2026-02-16', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (24, 144, 12, 'Front Desk Agent', '2026-02-15', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (25, 145, 13, 'Manager', '2026-02-14', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (26, 146, 13, 'Front Desk Agent', '2026-02-13', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (27, 147, 14, 'Manager', '2026-02-12', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (28, 148, 14, 'Front Desk Agent', '2026-02-11', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (29, 149, 15, 'Manager', '2026-02-10', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (30, 150, 15, 'Front Desk Agent', '2026-02-09', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (31, 151, 16, 'Manager', '2026-02-08', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (32, 152, 16, 'Front Desk Agent', '2026-02-07', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (33, 153, 17, 'Manager', '2026-02-06', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (34, 154, 17, 'Front Desk Agent', '2026-02-05', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (35, 155, 18, 'Manager', '2026-02-04', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (36, 156, 18, 'Front Desk Agent', '2026-02-03', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (37, 157, 19, 'Manager', '2026-02-02', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (38, 158, 19, 'Front Desk Agent', '2026-02-01', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (39, 159, 20, 'Manager', '2026-01-31', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (40, 160, 20, 'Front Desk Agent', '2026-01-30', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (41, 161, 21, 'Manager', '2026-01-29', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (42, 162, 21, 'Front Desk Agent', '2026-01-28', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (43, 163, 22, 'Manager', '2026-01-27', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (44, 164, 22, 'Front Desk Agent', '2026-01-26', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (45, 165, 23, 'Manager', '2026-01-25', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (46, 166, 23, 'Front Desk Agent', '2026-01-24', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (47, 167, 24, 'Manager', '2026-01-23', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (48, 168, 24, 'Front Desk Agent', '2026-01-22', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (49, 169, 25, 'Manager', '2026-01-21', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (50, 170, 25, 'Front Desk Agent', '2026-01-20', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (51, 171, 26, 'Manager', '2026-01-19', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (52, 172, 26, 'Front Desk Agent', '2026-01-18', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (53, 173, 27, 'Manager', '2026-01-17', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (54, 174, 27, 'Front Desk Agent', '2026-01-16', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (55, 175, 28, 'Manager', '2026-01-15', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (56, 176, 28, 'Front Desk Agent', '2026-01-14', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (57, 177, 29, 'Manager', '2026-01-13', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (58, 178, 29, 'Front Desk Agent', '2026-01-12', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (59, 179, 30, 'Manager', '2026-01-11', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (60, 180, 30, 'Front Desk Agent', '2026-01-10', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (61, 181, 31, 'Manager', '2026-01-09', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (62, 182, 31, 'Front Desk Agent', '2026-01-08', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (63, 183, 32, 'Manager', '2026-01-07', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (64, 184, 32, 'Front Desk Agent', '2026-01-06', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (65, 185, 33, 'Manager', '2026-01-05', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (66, 186, 33, 'Front Desk Agent', '2026-01-04', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (67, 187, 34, 'Manager', '2026-01-03', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (68, 188, 34, 'Front Desk Agent', '2026-01-02', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (69, 189, 35, 'Manager', '2026-01-01', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (70, 190, 35, 'Front Desk Agent', '2025-12-31', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (71, 191, 36, 'Manager', '2025-12-30', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (72, 192, 36, 'Front Desk Agent', '2025-12-29', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (73, 193, 37, 'Manager', '2025-12-28', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (74, 194, 37, 'Front Desk Agent', '2025-12-27', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (75, 195, 38, 'Manager', '2025-12-26', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (76, 196, 38, 'Front Desk Agent', '2025-12-25', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (77, 197, 39, 'Manager', '2025-12-24', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (78, 198, 39, 'Front Desk Agent', '2025-12-23', false);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (79, 199, 40, 'Manager', '2025-12-22', true);
INSERT INTO public.employee (employee_id, person_id, hotel_id, role_title, hired_on, is_manager) VALUES (80, 200, 40, 'Front Desk Agent', '2025-12-21', false);


--
-- Data for Name: hotel; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (1, 1, 'Hotel 1', 1, 21, '101 Main Avenue', 'Toronto', 'USA', 'Canada', 'A1001', 'hotel1@ehotelsdemo.com', '+1-555-2001', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (2, 1, 'Hotel 2', 2, 22, '102 Main Avenue', 'Ottawa', 'ON', 'Canada', 'A1002', 'hotel2@ehotelsdemo.com', '+1-555-2002', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (3, 1, 'Hotel 3', 3, 23, '103 Main Avenue', 'Montreal', 'QC', 'Canada', 'A1003', 'hotel3@ehotelsdemo.com', '+1-555-2003', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (4, 1, 'Hotel 4', 4, 24, '104 Main Avenue', 'Vancouver', 'ON', 'USA', 'A1004', 'hotel4@ehotelsdemo.com', '+1-555-2004', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (5, 1, 'Hotel 5', 5, 25, '105 Main Avenue', 'Calgary', 'BC', 'Canada', 'A1005', 'hotel5@ehotelsdemo.com', '+1-555-2005', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (6, 1, 'Hotel 6', 1, 26, '106 Main Avenue', 'Edmonton', 'ON', 'Canada', 'A1006', 'hotel6@ehotelsdemo.com', '+1-555-2006', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (7, 1, 'Hotel 7', 2, 27, '107 Main Avenue', 'Winnipeg', 'USA', 'Canada', 'A1007', 'hotel7@ehotelsdemo.com', '+1-555-2007', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (8, 1, 'Hotel 8', 3, 28, '108 Main Avenue', 'Halifax', 'ON', 'USA', 'A1008', 'hotel8@ehotelsdemo.com', '+1-555-2008', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (9, 2, 'Hotel 9', 4, 29, '109 Main Avenue', 'Boston', 'QC', 'Canada', 'A1009', 'hotel9@ehotelsdemo.com', '+1-555-2009', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (10, 2, 'Hotel 10', 5, 30, '110 Main Avenue', 'New York', 'ON', 'Canada', 'A1010', 'hotel10@ehotelsdemo.com', '+1-555-2010', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (11, 2, 'Hotel 11', 1, 20, '111 Main Avenue', 'Chicago', 'USA', 'Canada', 'A1011', 'hotel11@ehotelsdemo.com', '+1-555-2011', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (12, 2, 'Hotel 12', 2, 21, '112 Main Avenue', 'Seattle', 'ON', 'USA', 'A1012', 'hotel12@ehotelsdemo.com', '+1-555-2012', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (13, 2, 'Hotel 13', 3, 22, '113 Main Avenue', 'San Francisco', 'USA', 'Canada', 'A1013', 'hotel13@ehotelsdemo.com', '+1-555-2013', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (14, 2, 'Hotel 14', 4, 23, '114 Main Avenue', 'Los Angeles', 'ON', 'Canada', 'A1014', 'hotel14@ehotelsdemo.com', '+1-555-2014', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (15, 2, 'Hotel 15', 5, 24, '115 Main Avenue', 'Toronto', 'QC', 'Canada', 'A1015', 'hotel15@ehotelsdemo.com', '+1-555-2015', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (16, 2, 'Hotel 16', 1, 25, '116 Main Avenue', 'Ottawa', 'ON', 'USA', 'A1016', 'hotel16@ehotelsdemo.com', '+1-555-2016', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (17, 3, 'Hotel 17', 2, 26, '117 Main Avenue', 'Montreal', 'USA', 'Canada', 'A1017', 'hotel17@ehotelsdemo.com', '+1-555-2017', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (18, 3, 'Hotel 18', 3, 27, '118 Main Avenue', 'Vancouver', 'ON', 'Canada', 'A1018', 'hotel18@ehotelsdemo.com', '+1-555-2018', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (19, 3, 'Hotel 19', 4, 28, '119 Main Avenue', 'Calgary', 'USA', 'Canada', 'A1019', 'hotel19@ehotelsdemo.com', '+1-555-2019', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (20, 3, 'Hotel 20', 5, 29, '120 Main Avenue', 'Edmonton', 'ON', 'USA', 'A1020', 'hotel20@ehotelsdemo.com', '+1-555-2020', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (21, 3, 'Hotel 21', 1, 30, '121 Main Avenue', 'Winnipeg', 'QC', 'Canada', 'A1021', 'hotel21@ehotelsdemo.com', '+1-555-2021', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (22, 3, 'Hotel 22', 2, 20, '122 Main Avenue', 'Halifax', 'ON', 'Canada', 'A1022', 'hotel22@ehotelsdemo.com', '+1-555-2022', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (23, 3, 'Hotel 23', 3, 21, '123 Main Avenue', 'Boston', 'USA', 'Canada', 'A1023', 'hotel23@ehotelsdemo.com', '+1-555-2023', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (24, 3, 'Hotel 24', 4, 22, '124 Main Avenue', 'New York', 'ON', 'USA', 'A1024', 'hotel24@ehotelsdemo.com', '+1-555-2024', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (25, 4, 'Hotel 25', 5, 23, '125 Main Avenue', 'Chicago', 'BC', 'Canada', 'A1025', 'hotel25@ehotelsdemo.com', '+1-555-2025', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (26, 4, 'Hotel 26', 1, 24, '126 Main Avenue', 'Seattle', 'ON', 'Canada', 'A1026', 'hotel26@ehotelsdemo.com', '+1-555-2026', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (27, 4, 'Hotel 27', 2, 25, '127 Main Avenue', 'San Francisco', 'QC', 'Canada', 'A1027', 'hotel27@ehotelsdemo.com', '+1-555-2027', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (28, 4, 'Hotel 28', 3, 26, '128 Main Avenue', 'Los Angeles', 'ON', 'USA', 'A1028', 'hotel28@ehotelsdemo.com', '+1-555-2028', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (29, 4, 'Hotel 29', 4, 27, '129 Main Avenue', 'Toronto', 'USA', 'Canada', 'A1029', 'hotel29@ehotelsdemo.com', '+1-555-2029', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (30, 4, 'Hotel 30', 5, 28, '130 Main Avenue', 'Ottawa', 'ON', 'Canada', 'A1030', 'hotel30@ehotelsdemo.com', '+1-555-2030', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (31, 4, 'Hotel 31', 1, 29, '131 Main Avenue', 'Montreal', 'USA', 'Canada', 'A1031', 'hotel31@ehotelsdemo.com', '+1-555-2031', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (32, 4, 'Hotel 32', 2, 30, '132 Main Avenue', 'Vancouver', 'ON', 'USA', 'A1032', 'hotel32@ehotelsdemo.com', '+1-555-2032', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (33, 5, 'Hotel 33', 3, 20, '133 Main Avenue', 'Calgary', 'QC', 'Canada', 'A1033', 'hotel33@ehotelsdemo.com', '+1-555-2033', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (34, 5, 'Hotel 34', 4, 21, '134 Main Avenue', 'Edmonton', 'ON', 'Canada', 'A1034', 'hotel34@ehotelsdemo.com', '+1-555-2034', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (35, 5, 'Hotel 35', 5, 22, '135 Main Avenue', 'Winnipeg', 'BC', 'Canada', 'A1035', 'hotel35@ehotelsdemo.com', '+1-555-2035', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (36, 5, 'Hotel 36', 1, 23, '136 Main Avenue', 'Halifax', 'ON', 'USA', 'A1036', 'hotel36@ehotelsdemo.com', '+1-555-2036', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (37, 5, 'Hotel 37', 2, 24, '137 Main Avenue', 'Boston', 'USA', 'Canada', 'A1037', 'hotel37@ehotelsdemo.com', '+1-555-2037', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (38, 5, 'Hotel 38', 3, 25, '138 Main Avenue', 'New York', 'ON', 'Canada', 'A1038', 'hotel38@ehotelsdemo.com', '+1-555-2038', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (39, 5, 'Hotel 39', 4, 26, '139 Main Avenue', 'Chicago', 'QC', 'Canada', 'A1039', 'hotel39@ehotelsdemo.com', '+1-555-2039', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel (hotel_id, chain_id, hotel_name, category, total_rooms, address_line, city, state_province, country, postal_code, contact_email, contact_phone, created_at) VALUES (40, 5, 'Hotel 40', 5, 27, '140 Main Avenue', 'Seattle', 'ON', 'USA', 'A1040', 'hotel40@ehotelsdemo.com', '+1-555-2040', '2026-03-11 16:12:29.222032');


--
-- Data for Name: hotel_chain; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hotel_chain (chain_id, chain_name, central_office_address, contact_email, contact_phone, created_at) VALUES (1, 'Aurora Stays', '120 King St W, Toronto, ON', 'contact@aurorastays.com', '+1-416-555-1001', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel_chain (chain_id, chain_name, central_office_address, contact_email, contact_phone, created_at) VALUES (2, 'NorthPeak Hospitality', '330 Burrard St, Vancouver, BC', 'info@northpeak.com', '+1-604-555-2001', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel_chain (chain_id, chain_name, central_office_address, contact_email, contact_phone, created_at) VALUES (3, 'Maple Crest Hotels', '900 Rene-Levesque Blvd, Montreal, QC', 'hello@maplecrest.com', '+1-514-555-3001', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel_chain (chain_id, chain_name, central_office_address, contact_email, contact_phone, created_at) VALUES (4, 'Harborline Suites', '50 Causeway St, Boston, MA', 'support@harborline.com', '+1-617-555-4001', '2026-03-11 16:12:29.222032');
INSERT INTO public.hotel_chain (chain_id, chain_name, central_office_address, contact_email, contact_phone, created_at) VALUES (5, 'Frontier Lodge Group', '410 W Georgia St, Seattle, WA', 'desk@frontierlodge.com', '+1-206-555-5001', '2026-03-11 16:12:29.222032');


--
-- Data for Name: payment; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (1, 1, 1, 135.00, 'credit', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (2, 2, 2, 150.00, 'debit', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (3, 3, 3, 165.00, 'online', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (4, 4, 4, 180.00, 'cash', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (5, 5, 5, 195.00, 'credit', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (6, 6, 6, 210.00, 'debit', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (7, 7, 7, 225.00, 'online', '2026-03-11 16:12:29.222032');
INSERT INTO public.payment (payment_id, renting_id, employee_id, amount, method, paid_at) VALUES (8, 8, 8, 240.00, 'cash', '2026-03-11 16:12:29.222032');


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (1, 'CUST00001', 'SSN', 'CustomerFirst1', 'CustomerLast1', 'customer1@mail.com', '+1-613-3001', '11 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (2, 'CUST00002', 'SIN', 'CustomerFirst2', 'CustomerLast2', 'customer2@mail.com', '+1-613-3002', '12 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (3, 'CUST00003', 'SSN', 'CustomerFirst3', 'CustomerLast3', 'customer3@mail.com', '+1-613-3003', '13 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (4, 'CUST00004', 'SIN', 'CustomerFirst4', 'CustomerLast4', 'customer4@mail.com', '+1-613-3004', '14 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (5, 'CUST00005', 'SSN', 'CustomerFirst5', 'CustomerLast5', 'customer5@mail.com', '+1-613-3005', '15 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (6, 'CUST00006', 'SIN', 'CustomerFirst6', 'CustomerLast6', 'customer6@mail.com', '+1-613-3006', '16 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (7, 'CUST00007', 'SSN', 'CustomerFirst7', 'CustomerLast7', 'customer7@mail.com', '+1-613-3007', '17 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (8, 'CUST00008', 'SIN', 'CustomerFirst8', 'CustomerLast8', 'customer8@mail.com', '+1-613-3008', '18 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (9, 'CUST00009', 'SSN', 'CustomerFirst9', 'CustomerLast9', 'customer9@mail.com', '+1-613-3009', '19 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (10, 'CUST00010', 'SIN', 'CustomerFirst10', 'CustomerLast10', 'customer10@mail.com', '+1-613-3010', '20 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (11, 'CUST00011', 'SSN', 'CustomerFirst11', 'CustomerLast11', 'customer11@mail.com', '+1-613-3011', '21 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (12, 'CUST00012', 'SIN', 'CustomerFirst12', 'CustomerLast12', 'customer12@mail.com', '+1-613-3012', '22 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (13, 'CUST00013', 'SSN', 'CustomerFirst13', 'CustomerLast13', 'customer13@mail.com', '+1-613-3013', '23 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (14, 'CUST00014', 'SIN', 'CustomerFirst14', 'CustomerLast14', 'customer14@mail.com', '+1-613-3014', '24 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (15, 'CUST00015', 'SSN', 'CustomerFirst15', 'CustomerLast15', 'customer15@mail.com', '+1-613-3015', '25 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (16, 'CUST00016', 'SIN', 'CustomerFirst16', 'CustomerLast16', 'customer16@mail.com', '+1-613-3016', '26 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (17, 'CUST00017', 'SSN', 'CustomerFirst17', 'CustomerLast17', 'customer17@mail.com', '+1-613-3017', '27 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (18, 'CUST00018', 'SIN', 'CustomerFirst18', 'CustomerLast18', 'customer18@mail.com', '+1-613-3018', '28 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (19, 'CUST00019', 'SSN', 'CustomerFirst19', 'CustomerLast19', 'customer19@mail.com', '+1-613-3019', '29 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (20, 'CUST00020', 'SIN', 'CustomerFirst20', 'CustomerLast20', 'customer20@mail.com', '+1-613-3020', '30 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (21, 'CUST00021', 'SSN', 'CustomerFirst21', 'CustomerLast21', 'customer21@mail.com', '+1-613-3021', '31 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (22, 'CUST00022', 'SIN', 'CustomerFirst22', 'CustomerLast22', 'customer22@mail.com', '+1-613-3022', '32 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (23, 'CUST00023', 'SSN', 'CustomerFirst23', 'CustomerLast23', 'customer23@mail.com', '+1-613-3023', '33 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (24, 'CUST00024', 'SIN', 'CustomerFirst24', 'CustomerLast24', 'customer24@mail.com', '+1-613-3024', '34 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (25, 'CUST00025', 'SSN', 'CustomerFirst25', 'CustomerLast25', 'customer25@mail.com', '+1-613-3025', '35 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (26, 'CUST00026', 'SIN', 'CustomerFirst26', 'CustomerLast26', 'customer26@mail.com', '+1-613-3026', '36 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (27, 'CUST00027', 'SSN', 'CustomerFirst27', 'CustomerLast27', 'customer27@mail.com', '+1-613-3027', '37 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (28, 'CUST00028', 'SIN', 'CustomerFirst28', 'CustomerLast28', 'customer28@mail.com', '+1-613-3028', '38 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (29, 'CUST00029', 'SSN', 'CustomerFirst29', 'CustomerLast29', 'customer29@mail.com', '+1-613-3029', '39 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (30, 'CUST00030', 'SIN', 'CustomerFirst30', 'CustomerLast30', 'customer30@mail.com', '+1-613-3030', '40 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (31, 'CUST00031', 'SSN', 'CustomerFirst31', 'CustomerLast31', 'customer31@mail.com', '+1-613-3031', '41 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (32, 'CUST00032', 'SIN', 'CustomerFirst32', 'CustomerLast32', 'customer32@mail.com', '+1-613-3032', '42 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (33, 'CUST00033', 'SSN', 'CustomerFirst33', 'CustomerLast33', 'customer33@mail.com', '+1-613-3033', '43 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (34, 'CUST00034', 'SIN', 'CustomerFirst34', 'CustomerLast34', 'customer34@mail.com', '+1-613-3034', '44 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (35, 'CUST00035', 'SSN', 'CustomerFirst35', 'CustomerLast35', 'customer35@mail.com', '+1-613-3035', '45 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (36, 'CUST00036', 'SIN', 'CustomerFirst36', 'CustomerLast36', 'customer36@mail.com', '+1-613-3036', '46 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (37, 'CUST00037', 'SSN', 'CustomerFirst37', 'CustomerLast37', 'customer37@mail.com', '+1-613-3037', '47 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (38, 'CUST00038', 'SIN', 'CustomerFirst38', 'CustomerLast38', 'customer38@mail.com', '+1-613-3038', '48 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (39, 'CUST00039', 'SSN', 'CustomerFirst39', 'CustomerLast39', 'customer39@mail.com', '+1-613-3039', '49 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (40, 'CUST00040', 'SIN', 'CustomerFirst40', 'CustomerLast40', 'customer40@mail.com', '+1-613-3040', '50 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (41, 'CUST00041', 'SSN', 'CustomerFirst41', 'CustomerLast41', 'customer41@mail.com', '+1-613-3041', '51 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (42, 'CUST00042', 'SIN', 'CustomerFirst42', 'CustomerLast42', 'customer42@mail.com', '+1-613-3042', '52 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (43, 'CUST00043', 'SSN', 'CustomerFirst43', 'CustomerLast43', 'customer43@mail.com', '+1-613-3043', '53 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (44, 'CUST00044', 'SIN', 'CustomerFirst44', 'CustomerLast44', 'customer44@mail.com', '+1-613-3044', '54 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (45, 'CUST00045', 'SSN', 'CustomerFirst45', 'CustomerLast45', 'customer45@mail.com', '+1-613-3045', '55 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (46, 'CUST00046', 'SIN', 'CustomerFirst46', 'CustomerLast46', 'customer46@mail.com', '+1-613-3046', '56 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (47, 'CUST00047', 'SSN', 'CustomerFirst47', 'CustomerLast47', 'customer47@mail.com', '+1-613-3047', '57 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (48, 'CUST00048', 'SIN', 'CustomerFirst48', 'CustomerLast48', 'customer48@mail.com', '+1-613-3048', '58 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (49, 'CUST00049', 'SSN', 'CustomerFirst49', 'CustomerLast49', 'customer49@mail.com', '+1-613-3049', '59 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (50, 'CUST00050', 'SIN', 'CustomerFirst50', 'CustomerLast50', 'customer50@mail.com', '+1-613-3050', '60 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (51, 'CUST00051', 'SSN', 'CustomerFirst51', 'CustomerLast51', 'customer51@mail.com', '+1-613-3051', '61 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (52, 'CUST00052', 'SIN', 'CustomerFirst52', 'CustomerLast52', 'customer52@mail.com', '+1-613-3052', '62 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (53, 'CUST00053', 'SSN', 'CustomerFirst53', 'CustomerLast53', 'customer53@mail.com', '+1-613-3053', '63 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (54, 'CUST00054', 'SIN', 'CustomerFirst54', 'CustomerLast54', 'customer54@mail.com', '+1-613-3054', '64 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (55, 'CUST00055', 'SSN', 'CustomerFirst55', 'CustomerLast55', 'customer55@mail.com', '+1-613-3055', '65 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (56, 'CUST00056', 'SIN', 'CustomerFirst56', 'CustomerLast56', 'customer56@mail.com', '+1-613-3056', '66 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (57, 'CUST00057', 'SSN', 'CustomerFirst57', 'CustomerLast57', 'customer57@mail.com', '+1-613-3057', '67 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (58, 'CUST00058', 'SIN', 'CustomerFirst58', 'CustomerLast58', 'customer58@mail.com', '+1-613-3058', '68 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (59, 'CUST00059', 'SSN', 'CustomerFirst59', 'CustomerLast59', 'customer59@mail.com', '+1-613-3059', '69 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (60, 'CUST00060', 'SIN', 'CustomerFirst60', 'CustomerLast60', 'customer60@mail.com', '+1-613-3060', '70 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (61, 'CUST00061', 'SSN', 'CustomerFirst61', 'CustomerLast61', 'customer61@mail.com', '+1-613-3061', '71 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (62, 'CUST00062', 'SIN', 'CustomerFirst62', 'CustomerLast62', 'customer62@mail.com', '+1-613-3062', '72 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (63, 'CUST00063', 'SSN', 'CustomerFirst63', 'CustomerLast63', 'customer63@mail.com', '+1-613-3063', '73 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (64, 'CUST00064', 'SIN', 'CustomerFirst64', 'CustomerLast64', 'customer64@mail.com', '+1-613-3064', '74 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (65, 'CUST00065', 'SSN', 'CustomerFirst65', 'CustomerLast65', 'customer65@mail.com', '+1-613-3065', '75 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (66, 'CUST00066', 'SIN', 'CustomerFirst66', 'CustomerLast66', 'customer66@mail.com', '+1-613-3066', '76 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (67, 'CUST00067', 'SSN', 'CustomerFirst67', 'CustomerLast67', 'customer67@mail.com', '+1-613-3067', '77 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (68, 'CUST00068', 'SIN', 'CustomerFirst68', 'CustomerLast68', 'customer68@mail.com', '+1-613-3068', '78 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (69, 'CUST00069', 'SSN', 'CustomerFirst69', 'CustomerLast69', 'customer69@mail.com', '+1-613-3069', '79 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (70, 'CUST00070', 'SIN', 'CustomerFirst70', 'CustomerLast70', 'customer70@mail.com', '+1-613-3070', '80 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (71, 'CUST00071', 'SSN', 'CustomerFirst71', 'CustomerLast71', 'customer71@mail.com', '+1-613-3071', '81 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (72, 'CUST00072', 'SIN', 'CustomerFirst72', 'CustomerLast72', 'customer72@mail.com', '+1-613-3072', '82 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (73, 'CUST00073', 'SSN', 'CustomerFirst73', 'CustomerLast73', 'customer73@mail.com', '+1-613-3073', '83 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (74, 'CUST00074', 'SIN', 'CustomerFirst74', 'CustomerLast74', 'customer74@mail.com', '+1-613-3074', '84 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (75, 'CUST00075', 'SSN', 'CustomerFirst75', 'CustomerLast75', 'customer75@mail.com', '+1-613-3075', '85 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (76, 'CUST00076', 'SIN', 'CustomerFirst76', 'CustomerLast76', 'customer76@mail.com', '+1-613-3076', '86 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (77, 'CUST00077', 'SSN', 'CustomerFirst77', 'CustomerLast77', 'customer77@mail.com', '+1-613-3077', '87 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (78, 'CUST00078', 'SIN', 'CustomerFirst78', 'CustomerLast78', 'customer78@mail.com', '+1-613-3078', '88 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (79, 'CUST00079', 'SSN', 'CustomerFirst79', 'CustomerLast79', 'customer79@mail.com', '+1-613-3079', '89 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (80, 'CUST00080', 'SIN', 'CustomerFirst80', 'CustomerLast80', 'customer80@mail.com', '+1-613-3080', '90 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (81, 'CUST00081', 'SSN', 'CustomerFirst81', 'CustomerLast81', 'customer81@mail.com', '+1-613-3081', '91 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (82, 'CUST00082', 'SIN', 'CustomerFirst82', 'CustomerLast82', 'customer82@mail.com', '+1-613-3082', '92 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (83, 'CUST00083', 'SSN', 'CustomerFirst83', 'CustomerLast83', 'customer83@mail.com', '+1-613-3083', '93 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (84, 'CUST00084', 'SIN', 'CustomerFirst84', 'CustomerLast84', 'customer84@mail.com', '+1-613-3084', '94 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (85, 'CUST00085', 'SSN', 'CustomerFirst85', 'CustomerLast85', 'customer85@mail.com', '+1-613-3085', '95 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (86, 'CUST00086', 'SIN', 'CustomerFirst86', 'CustomerLast86', 'customer86@mail.com', '+1-613-3086', '96 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (87, 'CUST00087', 'SSN', 'CustomerFirst87', 'CustomerLast87', 'customer87@mail.com', '+1-613-3087', '97 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (88, 'CUST00088', 'SIN', 'CustomerFirst88', 'CustomerLast88', 'customer88@mail.com', '+1-613-3088', '98 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (89, 'CUST00089', 'SSN', 'CustomerFirst89', 'CustomerLast89', 'customer89@mail.com', '+1-613-3089', '99 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (90, 'CUST00090', 'SIN', 'CustomerFirst90', 'CustomerLast90', 'customer90@mail.com', '+1-613-3090', '100 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (91, 'CUST00091', 'SSN', 'CustomerFirst91', 'CustomerLast91', 'customer91@mail.com', '+1-613-3091', '101 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (92, 'CUST00092', 'SIN', 'CustomerFirst92', 'CustomerLast92', 'customer92@mail.com', '+1-613-3092', '102 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (93, 'CUST00093', 'SSN', 'CustomerFirst93', 'CustomerLast93', 'customer93@mail.com', '+1-613-3093', '103 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (94, 'CUST00094', 'SIN', 'CustomerFirst94', 'CustomerLast94', 'customer94@mail.com', '+1-613-3094', '104 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (95, 'CUST00095', 'SSN', 'CustomerFirst95', 'CustomerLast95', 'customer95@mail.com', '+1-613-3095', '105 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (96, 'CUST00096', 'SIN', 'CustomerFirst96', 'CustomerLast96', 'customer96@mail.com', '+1-613-3096', '106 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (97, 'CUST00097', 'SSN', 'CustomerFirst97', 'CustomerLast97', 'customer97@mail.com', '+1-613-3097', '107 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (98, 'CUST00098', 'SIN', 'CustomerFirst98', 'CustomerLast98', 'customer98@mail.com', '+1-613-3098', '108 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (99, 'CUST00099', 'SSN', 'CustomerFirst99', 'CustomerLast99', 'customer99@mail.com', '+1-613-3099', '109 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (100, 'CUST00100', 'SIN', 'CustomerFirst100', 'CustomerLast100', 'customer100@mail.com', '+1-613-3100', '110 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (101, 'CUST00101', 'SSN', 'CustomerFirst101', 'CustomerLast101', 'customer101@mail.com', '+1-613-3101', '111 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (102, 'CUST00102', 'SIN', 'CustomerFirst102', 'CustomerLast102', 'customer102@mail.com', '+1-613-3102', '112 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (103, 'CUST00103', 'SSN', 'CustomerFirst103', 'CustomerLast103', 'customer103@mail.com', '+1-613-3103', '113 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (104, 'CUST00104', 'SIN', 'CustomerFirst104', 'CustomerLast104', 'customer104@mail.com', '+1-613-3104', '114 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (105, 'CUST00105', 'SSN', 'CustomerFirst105', 'CustomerLast105', 'customer105@mail.com', '+1-613-3105', '115 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (106, 'CUST00106', 'SIN', 'CustomerFirst106', 'CustomerLast106', 'customer106@mail.com', '+1-613-3106', '116 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (107, 'CUST00107', 'SSN', 'CustomerFirst107', 'CustomerLast107', 'customer107@mail.com', '+1-613-3107', '117 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (108, 'CUST00108', 'SIN', 'CustomerFirst108', 'CustomerLast108', 'customer108@mail.com', '+1-613-3108', '118 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (109, 'CUST00109', 'SSN', 'CustomerFirst109', 'CustomerLast109', 'customer109@mail.com', '+1-613-3109', '119 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (110, 'CUST00110', 'SIN', 'CustomerFirst110', 'CustomerLast110', 'customer110@mail.com', '+1-613-3110', '120 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (111, 'CUST00111', 'SSN', 'CustomerFirst111', 'CustomerLast111', 'customer111@mail.com', '+1-613-3111', '121 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (112, 'CUST00112', 'SIN', 'CustomerFirst112', 'CustomerLast112', 'customer112@mail.com', '+1-613-3112', '122 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (113, 'CUST00113', 'SSN', 'CustomerFirst113', 'CustomerLast113', 'customer113@mail.com', '+1-613-3113', '123 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (114, 'CUST00114', 'SIN', 'CustomerFirst114', 'CustomerLast114', 'customer114@mail.com', '+1-613-3114', '124 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (115, 'CUST00115', 'SSN', 'CustomerFirst115', 'CustomerLast115', 'customer115@mail.com', '+1-613-3115', '125 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (116, 'CUST00116', 'SIN', 'CustomerFirst116', 'CustomerLast116', 'customer116@mail.com', '+1-613-3116', '126 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (117, 'CUST00117', 'SSN', 'CustomerFirst117', 'CustomerLast117', 'customer117@mail.com', '+1-613-3117', '127 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (118, 'CUST00118', 'SIN', 'CustomerFirst118', 'CustomerLast118', 'customer118@mail.com', '+1-613-3118', '128 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (119, 'CUST00119', 'SSN', 'CustomerFirst119', 'CustomerLast119', 'customer119@mail.com', '+1-613-3119', '129 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (120, 'CUST00120', 'SIN', 'CustomerFirst120', 'CustomerLast120', 'customer120@mail.com', '+1-613-3120', '130 Customer Road');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (121, 'EMP00001', 'SSN', 'EmployeeFirst1', 'EmployeeLast1', 'employee1@mail.com', '+1-343-4001', '21 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (122, 'EMP00002', 'SIN', 'EmployeeFirst2', 'EmployeeLast2', 'employee2@mail.com', '+1-343-4002', '22 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (123, 'EMP00003', 'SSN', 'EmployeeFirst3', 'EmployeeLast3', 'employee3@mail.com', '+1-343-4003', '23 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (124, 'EMP00004', 'SIN', 'EmployeeFirst4', 'EmployeeLast4', 'employee4@mail.com', '+1-343-4004', '24 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (125, 'EMP00005', 'SSN', 'EmployeeFirst5', 'EmployeeLast5', 'employee5@mail.com', '+1-343-4005', '25 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (126, 'EMP00006', 'SIN', 'EmployeeFirst6', 'EmployeeLast6', 'employee6@mail.com', '+1-343-4006', '26 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (127, 'EMP00007', 'SSN', 'EmployeeFirst7', 'EmployeeLast7', 'employee7@mail.com', '+1-343-4007', '27 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (128, 'EMP00008', 'SIN', 'EmployeeFirst8', 'EmployeeLast8', 'employee8@mail.com', '+1-343-4008', '28 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (129, 'EMP00009', 'SSN', 'EmployeeFirst9', 'EmployeeLast9', 'employee9@mail.com', '+1-343-4009', '29 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (130, 'EMP00010', 'SIN', 'EmployeeFirst10', 'EmployeeLast10', 'employee10@mail.com', '+1-343-4010', '30 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (131, 'EMP00011', 'SSN', 'EmployeeFirst11', 'EmployeeLast11', 'employee11@mail.com', '+1-343-4011', '31 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (132, 'EMP00012', 'SIN', 'EmployeeFirst12', 'EmployeeLast12', 'employee12@mail.com', '+1-343-4012', '32 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (133, 'EMP00013', 'SSN', 'EmployeeFirst13', 'EmployeeLast13', 'employee13@mail.com', '+1-343-4013', '33 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (134, 'EMP00014', 'SIN', 'EmployeeFirst14', 'EmployeeLast14', 'employee14@mail.com', '+1-343-4014', '34 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (135, 'EMP00015', 'SSN', 'EmployeeFirst15', 'EmployeeLast15', 'employee15@mail.com', '+1-343-4015', '35 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (136, 'EMP00016', 'SIN', 'EmployeeFirst16', 'EmployeeLast16', 'employee16@mail.com', '+1-343-4016', '36 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (137, 'EMP00017', 'SSN', 'EmployeeFirst17', 'EmployeeLast17', 'employee17@mail.com', '+1-343-4017', '37 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (138, 'EMP00018', 'SIN', 'EmployeeFirst18', 'EmployeeLast18', 'employee18@mail.com', '+1-343-4018', '38 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (139, 'EMP00019', 'SSN', 'EmployeeFirst19', 'EmployeeLast19', 'employee19@mail.com', '+1-343-4019', '39 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (140, 'EMP00020', 'SIN', 'EmployeeFirst20', 'EmployeeLast20', 'employee20@mail.com', '+1-343-4020', '40 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (141, 'EMP00021', 'SSN', 'EmployeeFirst21', 'EmployeeLast21', 'employee21@mail.com', '+1-343-4021', '41 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (142, 'EMP00022', 'SIN', 'EmployeeFirst22', 'EmployeeLast22', 'employee22@mail.com', '+1-343-4022', '42 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (143, 'EMP00023', 'SSN', 'EmployeeFirst23', 'EmployeeLast23', 'employee23@mail.com', '+1-343-4023', '43 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (144, 'EMP00024', 'SIN', 'EmployeeFirst24', 'EmployeeLast24', 'employee24@mail.com', '+1-343-4024', '44 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (145, 'EMP00025', 'SSN', 'EmployeeFirst25', 'EmployeeLast25', 'employee25@mail.com', '+1-343-4025', '45 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (146, 'EMP00026', 'SIN', 'EmployeeFirst26', 'EmployeeLast26', 'employee26@mail.com', '+1-343-4026', '46 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (147, 'EMP00027', 'SSN', 'EmployeeFirst27', 'EmployeeLast27', 'employee27@mail.com', '+1-343-4027', '47 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (148, 'EMP00028', 'SIN', 'EmployeeFirst28', 'EmployeeLast28', 'employee28@mail.com', '+1-343-4028', '48 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (149, 'EMP00029', 'SSN', 'EmployeeFirst29', 'EmployeeLast29', 'employee29@mail.com', '+1-343-4029', '49 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (150, 'EMP00030', 'SIN', 'EmployeeFirst30', 'EmployeeLast30', 'employee30@mail.com', '+1-343-4030', '50 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (151, 'EMP00031', 'SSN', 'EmployeeFirst31', 'EmployeeLast31', 'employee31@mail.com', '+1-343-4031', '51 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (152, 'EMP00032', 'SIN', 'EmployeeFirst32', 'EmployeeLast32', 'employee32@mail.com', '+1-343-4032', '52 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (153, 'EMP00033', 'SSN', 'EmployeeFirst33', 'EmployeeLast33', 'employee33@mail.com', '+1-343-4033', '53 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (154, 'EMP00034', 'SIN', 'EmployeeFirst34', 'EmployeeLast34', 'employee34@mail.com', '+1-343-4034', '54 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (155, 'EMP00035', 'SSN', 'EmployeeFirst35', 'EmployeeLast35', 'employee35@mail.com', '+1-343-4035', '55 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (156, 'EMP00036', 'SIN', 'EmployeeFirst36', 'EmployeeLast36', 'employee36@mail.com', '+1-343-4036', '56 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (157, 'EMP00037', 'SSN', 'EmployeeFirst37', 'EmployeeLast37', 'employee37@mail.com', '+1-343-4037', '57 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (158, 'EMP00038', 'SIN', 'EmployeeFirst38', 'EmployeeLast38', 'employee38@mail.com', '+1-343-4038', '58 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (159, 'EMP00039', 'SSN', 'EmployeeFirst39', 'EmployeeLast39', 'employee39@mail.com', '+1-343-4039', '59 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (160, 'EMP00040', 'SIN', 'EmployeeFirst40', 'EmployeeLast40', 'employee40@mail.com', '+1-343-4040', '60 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (161, 'EMP00041', 'SSN', 'EmployeeFirst41', 'EmployeeLast41', 'employee41@mail.com', '+1-343-4041', '61 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (162, 'EMP00042', 'SIN', 'EmployeeFirst42', 'EmployeeLast42', 'employee42@mail.com', '+1-343-4042', '62 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (163, 'EMP00043', 'SSN', 'EmployeeFirst43', 'EmployeeLast43', 'employee43@mail.com', '+1-343-4043', '63 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (164, 'EMP00044', 'SIN', 'EmployeeFirst44', 'EmployeeLast44', 'employee44@mail.com', '+1-343-4044', '64 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (165, 'EMP00045', 'SSN', 'EmployeeFirst45', 'EmployeeLast45', 'employee45@mail.com', '+1-343-4045', '65 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (166, 'EMP00046', 'SIN', 'EmployeeFirst46', 'EmployeeLast46', 'employee46@mail.com', '+1-343-4046', '66 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (167, 'EMP00047', 'SSN', 'EmployeeFirst47', 'EmployeeLast47', 'employee47@mail.com', '+1-343-4047', '67 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (168, 'EMP00048', 'SIN', 'EmployeeFirst48', 'EmployeeLast48', 'employee48@mail.com', '+1-343-4048', '68 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (169, 'EMP00049', 'SSN', 'EmployeeFirst49', 'EmployeeLast49', 'employee49@mail.com', '+1-343-4049', '69 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (170, 'EMP00050', 'SIN', 'EmployeeFirst50', 'EmployeeLast50', 'employee50@mail.com', '+1-343-4050', '70 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (171, 'EMP00051', 'SSN', 'EmployeeFirst51', 'EmployeeLast51', 'employee51@mail.com', '+1-343-4051', '71 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (172, 'EMP00052', 'SIN', 'EmployeeFirst52', 'EmployeeLast52', 'employee52@mail.com', '+1-343-4052', '72 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (173, 'EMP00053', 'SSN', 'EmployeeFirst53', 'EmployeeLast53', 'employee53@mail.com', '+1-343-4053', '73 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (174, 'EMP00054', 'SIN', 'EmployeeFirst54', 'EmployeeLast54', 'employee54@mail.com', '+1-343-4054', '74 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (175, 'EMP00055', 'SSN', 'EmployeeFirst55', 'EmployeeLast55', 'employee55@mail.com', '+1-343-4055', '75 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (176, 'EMP00056', 'SIN', 'EmployeeFirst56', 'EmployeeLast56', 'employee56@mail.com', '+1-343-4056', '76 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (177, 'EMP00057', 'SSN', 'EmployeeFirst57', 'EmployeeLast57', 'employee57@mail.com', '+1-343-4057', '77 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (178, 'EMP00058', 'SIN', 'EmployeeFirst58', 'EmployeeLast58', 'employee58@mail.com', '+1-343-4058', '78 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (179, 'EMP00059', 'SSN', 'EmployeeFirst59', 'EmployeeLast59', 'employee59@mail.com', '+1-343-4059', '79 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (180, 'EMP00060', 'SIN', 'EmployeeFirst60', 'EmployeeLast60', 'employee60@mail.com', '+1-343-4060', '80 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (181, 'EMP00061', 'SSN', 'EmployeeFirst61', 'EmployeeLast61', 'employee61@mail.com', '+1-343-4061', '81 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (182, 'EMP00062', 'SIN', 'EmployeeFirst62', 'EmployeeLast62', 'employee62@mail.com', '+1-343-4062', '82 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (183, 'EMP00063', 'SSN', 'EmployeeFirst63', 'EmployeeLast63', 'employee63@mail.com', '+1-343-4063', '83 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (184, 'EMP00064', 'SIN', 'EmployeeFirst64', 'EmployeeLast64', 'employee64@mail.com', '+1-343-4064', '84 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (185, 'EMP00065', 'SSN', 'EmployeeFirst65', 'EmployeeLast65', 'employee65@mail.com', '+1-343-4065', '85 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (186, 'EMP00066', 'SIN', 'EmployeeFirst66', 'EmployeeLast66', 'employee66@mail.com', '+1-343-4066', '86 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (187, 'EMP00067', 'SSN', 'EmployeeFirst67', 'EmployeeLast67', 'employee67@mail.com', '+1-343-4067', '87 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (188, 'EMP00068', 'SIN', 'EmployeeFirst68', 'EmployeeLast68', 'employee68@mail.com', '+1-343-4068', '88 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (189, 'EMP00069', 'SSN', 'EmployeeFirst69', 'EmployeeLast69', 'employee69@mail.com', '+1-343-4069', '89 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (190, 'EMP00070', 'SIN', 'EmployeeFirst70', 'EmployeeLast70', 'employee70@mail.com', '+1-343-4070', '90 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (191, 'EMP00071', 'SSN', 'EmployeeFirst71', 'EmployeeLast71', 'employee71@mail.com', '+1-343-4071', '91 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (192, 'EMP00072', 'SIN', 'EmployeeFirst72', 'EmployeeLast72', 'employee72@mail.com', '+1-343-4072', '92 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (193, 'EMP00073', 'SSN', 'EmployeeFirst73', 'EmployeeLast73', 'employee73@mail.com', '+1-343-4073', '93 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (194, 'EMP00074', 'SIN', 'EmployeeFirst74', 'EmployeeLast74', 'employee74@mail.com', '+1-343-4074', '94 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (195, 'EMP00075', 'SSN', 'EmployeeFirst75', 'EmployeeLast75', 'employee75@mail.com', '+1-343-4075', '95 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (196, 'EMP00076', 'SIN', 'EmployeeFirst76', 'EmployeeLast76', 'employee76@mail.com', '+1-343-4076', '96 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (197, 'EMP00077', 'SSN', 'EmployeeFirst77', 'EmployeeLast77', 'employee77@mail.com', '+1-343-4077', '97 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (198, 'EMP00078', 'SIN', 'EmployeeFirst78', 'EmployeeLast78', 'employee78@mail.com', '+1-343-4078', '98 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (199, 'EMP00079', 'SSN', 'EmployeeFirst79', 'EmployeeLast79', 'employee79@mail.com', '+1-343-4079', '99 Employee Street');
INSERT INTO public.person (person_id, legal_id, id_type, first_name, last_name, email, phone, address_line) VALUES (200, 'EMP00080', 'SIN', 'EmployeeFirst80', 'EmployeeLast80', 'employee80@mail.com', '+1-343-4080', '100 Employee Street');


--
-- Data for Name: renting; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (3, 33, 23, 3, NULL, '2026-03-10', '2026-03-13', 'active', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (4, 34, 24, 4, NULL, '2026-03-10', '2026-03-13', 'active', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (5, 35, 25, 5, NULL, '2026-03-01', '2026-03-04', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (6, 36, 26, 6, NULL, '2026-02-28', '2026-03-03', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (7, 37, 27, 7, NULL, '2026-02-27', '2026-03-02', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (8, 38, 28, 8, NULL, '2026-02-26', '2026-03-01', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (9, 39, 29, 9, NULL, '2026-02-25', '2026-02-28', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (10, 40, 30, 10, NULL, '2026-02-24', '2026-02-27', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (11, 41, 31, 11, NULL, '2026-02-23', '2026-02-26', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (12, 42, 32, 12, NULL, '2026-02-22', '2026-02-25', 'cancelled', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (1, 31, 21, 1, NULL, '2026-03-10', '2026-03-13', 'completed', '2026-03-11 16:12:29.222032');
INSERT INTO public.renting (renting_id, room_id, customer_id, employee_id, source_booking_id, start_date, end_date, status, created_at) VALUES (2, 32, 22, 2, NULL, '2026-03-10', '2026-03-13', 'completed', '2026-03-11 16:12:29.222032');


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (21, 21, '101', 'single', 160.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (22, 22, '101', 'single', 163.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (23, 23, '101', 'single', 166.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (24, 24, '101', 'single', 169.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (25, 25, '101', 'single', 172.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (26, 26, '101', 'single', 175.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (27, 27, '101', 'single', 178.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (28, 28, '101', 'single', 181.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (29, 29, '101', 'single', 184.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (30, 30, '101', 'single', 187.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (43, 3, '102', 'double', 118.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (44, 4, '102', 'double', 121.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (45, 5, '102', 'double', 124.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (46, 6, '102', 'double', 127.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (47, 7, '102', 'double', 130.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (48, 8, '102', 'double', 133.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (49, 9, '102', 'double', 136.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (50, 10, '102', 'double', 139.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (51, 11, '102', 'double', 142.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (52, 12, '102', 'double', 145.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (53, 13, '102', 'double', 148.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (54, 14, '102', 'double', 151.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (55, 15, '102', 'double', 154.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (56, 16, '102', 'double', 157.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (57, 17, '102', 'double', 160.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (58, 18, '102', 'double', 163.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (59, 19, '102', 'double', 166.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (60, 20, '102', 'double', 169.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (61, 21, '102', 'double', 172.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (62, 22, '102', 'double', 175.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (63, 23, '102', 'double', 178.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (64, 24, '102', 'double', 181.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (65, 25, '102', 'double', 184.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (66, 26, '102', 'double', 187.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (67, 27, '102', 'double', 190.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (68, 28, '102', 'double', 193.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (69, 29, '102', 'double', 196.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (70, 30, '102', 'double', 199.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (71, 31, '102', 'double', 202.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (72, 32, '102', 'double', 205.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (73, 33, '102', 'double', 208.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (74, 34, '102', 'double', 211.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (75, 35, '102', 'double', 214.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (76, 36, '102', 'double', 217.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (77, 37, '102', 'double', 220.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (78, 38, '102', 'double', 223.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (79, 39, '102', 'double', 226.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (80, 40, '102', 'double', 229.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (81, 1, '103', 'suite', 124.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (82, 2, '103', 'suite', 127.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (83, 3, '103', 'suite', 130.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (84, 4, '103', 'suite', 133.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (85, 5, '103', 'suite', 136.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (86, 6, '103', 'suite', 139.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (87, 7, '103', 'suite', 142.00, true, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (88, 8, '103', 'suite', 145.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (89, 9, '103', 'suite', 148.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (90, 10, '103', 'suite', 151.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (91, 11, '103', 'suite', 154.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (92, 12, '103', 'suite', 157.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (93, 13, '103', 'suite', 160.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (94, 14, '103', 'suite', 163.00, true, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (95, 15, '103', 'suite', 166.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (96, 16, '103', 'suite', 169.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (97, 17, '103', 'suite', 172.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (98, 18, '103', 'suite', 175.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (99, 19, '103', 'suite', 178.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (100, 20, '103', 'suite', 181.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (101, 21, '103', 'suite', 184.00, true, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (102, 22, '103', 'suite', 187.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (103, 23, '103', 'suite', 190.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (104, 24, '103', 'suite', 193.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (105, 25, '103', 'suite', 196.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (106, 26, '103', 'suite', 199.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (107, 27, '103', 'suite', 202.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (108, 28, '103', 'suite', 205.00, true, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (109, 29, '103', 'suite', 208.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (110, 30, '103', 'suite', 211.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (111, 31, '103', 'suite', 214.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (112, 32, '103', 'suite', 217.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (113, 33, '103', 'suite', 220.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (114, 34, '103', 'suite', 223.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (115, 35, '103', 'suite', 226.00, true, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (116, 36, '103', 'suite', 229.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (117, 37, '103', 'suite', 232.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (118, 38, '103', 'suite', 235.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (119, 39, '103', 'suite', 238.00, false, false, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (120, 40, '103', 'suite', 241.00, false, true, false, 'WiFi, TV, Balcony, Mini-Bar', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (121, 1, '104', 'family', 136.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (122, 2, '104', 'family', 139.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (123, 3, '104', 'family', 142.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (124, 4, '104', 'family', 145.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (125, 5, '104', 'family', 148.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (126, 6, '104', 'family', 151.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (127, 7, '104', 'family', 154.00, true, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (128, 8, '104', 'family', 157.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (129, 9, '104', 'family', 160.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (130, 10, '104', 'family', 163.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (131, 11, '104', 'family', 166.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (132, 12, '104', 'family', 169.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (133, 13, '104', 'family', 172.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (134, 14, '104', 'family', 175.00, true, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (135, 15, '104', 'family', 178.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (136, 16, '104', 'family', 181.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (137, 17, '104', 'family', 184.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (138, 18, '104', 'family', 187.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (139, 19, '104', 'family', 190.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (140, 20, '104', 'family', 193.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (141, 21, '104', 'family', 196.00, true, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (142, 22, '104', 'family', 199.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (143, 23, '104', 'family', 202.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (144, 24, '104', 'family', 205.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (145, 25, '104', 'family', 208.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (146, 26, '104', 'family', 211.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (147, 27, '104', 'family', 214.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (148, 28, '104', 'family', 217.00, true, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (149, 29, '104', 'family', 220.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (150, 30, '104', 'family', 223.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (151, 31, '104', 'family', 226.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (152, 32, '104', 'family', 229.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (153, 33, '104', 'family', 232.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (154, 34, '104', 'family', 235.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (155, 35, '104', 'family', 238.00, true, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (156, 36, '104', 'family', 241.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (157, 37, '104', 'family', 244.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (158, 38, '104', 'family', 247.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (159, 39, '104', 'family', 250.00, false, false, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (160, 40, '104', 'family', 253.00, false, true, true, 'WiFi, TV, Sofa-bed, Kitchenette', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (161, 1, '105', 'double', 148.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (162, 2, '105', 'double', 151.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (163, 3, '105', 'double', 154.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (164, 4, '105', 'double', 157.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (165, 5, '105', 'double', 160.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (166, 6, '105', 'double', 163.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (167, 7, '105', 'double', 166.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (168, 8, '105', 'double', 169.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (169, 9, '105', 'double', 172.00, false, false, true, 'WiFi, TV, Air Conditioning', 'Minor paint damage', 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (170, 10, '105', 'double', 175.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (171, 11, '105', 'double', 178.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (172, 12, '105', 'double', 181.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (173, 13, '105', 'double', 184.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (174, 14, '105', 'double', 187.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (175, 15, '105', 'double', 190.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (176, 16, '105', 'double', 193.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (177, 17, '105', 'double', 196.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (178, 18, '105', 'double', 199.00, false, false, true, 'WiFi, TV, Air Conditioning', 'Minor paint damage', 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (179, 19, '105', 'double', 202.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (180, 20, '105', 'double', 205.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (181, 21, '105', 'double', 208.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (182, 22, '105', 'double', 211.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (183, 23, '105', 'double', 214.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (184, 24, '105', 'double', 217.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (185, 25, '105', 'double', 220.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (186, 26, '105', 'double', 223.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (187, 27, '105', 'double', 226.00, false, false, true, 'WiFi, TV, Air Conditioning', 'Minor paint damage', 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (188, 28, '105', 'double', 229.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (189, 29, '105', 'double', 232.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (190, 30, '105', 'double', 235.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (191, 31, '105', 'double', 238.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (192, 32, '105', 'double', 241.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (193, 33, '105', 'double', 244.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (194, 34, '105', 'double', 247.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (195, 35, '105', 'double', 250.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (196, 36, '105', 'double', 253.00, false, false, true, 'WiFi, TV, Air Conditioning', 'Minor paint damage', 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (197, 37, '105', 'double', 256.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (198, 38, '105', 'double', 259.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (199, 39, '105', 'double', 262.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (200, 40, '105', 'double', 265.00, false, false, true, 'WiFi, TV, Air Conditioning', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (3, 3, '101', 'single', 106.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (4, 4, '101', 'single', 109.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (5, 5, '101', 'single', 112.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (6, 6, '101', 'single', 115.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (7, 7, '101', 'single', 118.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (8, 8, '101', 'single', 121.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (9, 9, '101', 'single', 124.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (10, 10, '101', 'single', 127.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (11, 11, '101', 'single', 130.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (12, 12, '101', 'single', 133.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (13, 13, '101', 'single', 136.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (14, 14, '101', 'single', 139.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (15, 15, '101', 'single', 142.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (16, 16, '101', 'single', 145.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (17, 17, '101', 'single', 148.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (18, 18, '101', 'single', 151.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (19, 19, '101', 'single', 154.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (20, 20, '101', 'single', 157.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (33, 33, '101', 'single', 196.00, false, false, false, 'WiFi, TV', NULL, 'rented');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (34, 34, '101', 'single', 199.00, false, false, false, 'WiFi, TV', NULL, 'rented');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (35, 35, '101', 'single', 202.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (36, 36, '101', 'single', 205.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (37, 37, '101', 'single', 208.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (38, 38, '101', 'single', 211.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (39, 39, '101', 'single', 214.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (40, 40, '101', 'single', 217.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (41, 1, '102', 'double', 112.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (42, 2, '102', 'double', 115.00, false, false, true, 'WiFi, TV, Mini-Fridge', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (1, 1, '101', 'single', 100.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (2, 2, '101', 'single', 103.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (31, 31, '101', 'single', 190.00, false, false, false, 'WiFi, TV', NULL, 'available');
INSERT INTO public.room (room_id, hotel_id, room_number, capacity, base_price, has_sea_view, has_mountain_view, is_extendable, amenities, issues, current_status) VALUES (32, 32, '101', 'single', 193.00, false, false, false, 'WiFi, TV', NULL, 'available');


--
-- Name: archive_archive_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.archive_archive_id_seq', 4, true);


--
-- Name: booking_booking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.booking_booking_id_seq', 20, true);


--
-- Name: customer_customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.customer_customer_id_seq', 120, true);


--
-- Name: employee_employee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.employee_employee_id_seq', 80, true);


--
-- Name: hotel_chain_chain_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hotel_chain_chain_id_seq', 5, true);


--
-- Name: hotel_hotel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hotel_hotel_id_seq', 40, true);


--
-- Name: payment_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_payment_id_seq', 8, true);


--
-- Name: person_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.person_person_id_seq', 200, true);


--
-- Name: renting_renting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.renting_renting_id_seq', 12, true);


--
-- Name: room_room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.room_room_id_seq', 200, true);


--
-- Name: archive archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive
    ADD CONSTRAINT archive_pkey PRIMARY KEY (archive_id);


--
-- Name: booking booking_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_pkey PRIMARY KEY (booking_id);


--
-- Name: customer customer_person_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_person_id_key UNIQUE (person_id);


--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- Name: employee employee_person_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_person_id_key UNIQUE (person_id);


--
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (employee_id);


--
-- Name: hotel_chain hotel_chain_chain_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel_chain
    ADD CONSTRAINT hotel_chain_chain_name_key UNIQUE (chain_name);


--
-- Name: hotel hotel_chain_id_hotel_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel
    ADD CONSTRAINT hotel_chain_id_hotel_name_key UNIQUE (chain_id, hotel_name);


--
-- Name: hotel_chain hotel_chain_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel_chain
    ADD CONSTRAINT hotel_chain_pkey PRIMARY KEY (chain_id);


--
-- Name: hotel hotel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel
    ADD CONSTRAINT hotel_pkey PRIMARY KEY (hotel_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- Name: person person_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_email_key UNIQUE (email);


--
-- Name: person person_legal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_legal_id_key UNIQUE (legal_id);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (person_id);


--
-- Name: renting renting_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting
    ADD CONSTRAINT renting_pkey PRIMARY KEY (renting_id);


--
-- Name: room room_hotel_id_room_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_hotel_id_room_number_key UNIQUE (hotel_id, room_number);


--
-- Name: room room_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (room_id);


--
-- Name: idx_booking_room_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_room_dates ON public.booking USING btree (room_id, start_date, end_date);


--
-- Name: idx_hotel_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hotel_filtering ON public.hotel USING btree (chain_id, category, city, total_rooms);


--
-- Name: idx_renting_room_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_renting_room_dates ON public.renting USING btree (room_id, start_date, end_date);


--
-- Name: idx_room_capacity_price_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_capacity_price_status ON public.room USING btree (capacity, base_price, current_status);


--
-- Name: booking trg_archive_booking; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_archive_booking AFTER UPDATE OF status ON public.booking FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION public.fn_archive_booking();


--
-- Name: renting trg_archive_renting; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_archive_renting AFTER UPDATE OF status ON public.renting FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION public.fn_archive_renting();


--
-- Name: booking trg_booking_status_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_booking_status_sync AFTER INSERT OR DELETE OR UPDATE ON public.booking FOR EACH ROW EXECUTE FUNCTION public.fn_after_booking_change();


--
-- Name: booking trg_booking_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_booking_validate BEFORE INSERT OR UPDATE ON public.booking FOR EACH ROW EXECUTE FUNCTION public.fn_validate_room_availability();


--
-- Name: renting trg_renting_status_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_renting_status_sync AFTER INSERT OR DELETE OR UPDATE ON public.renting FOR EACH ROW EXECUTE FUNCTION public.fn_after_renting_change();


--
-- Name: renting trg_renting_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_renting_validate BEFORE INSERT OR UPDATE ON public.renting FOR EACH ROW EXECUTE FUNCTION public.fn_validate_room_availability();


--
-- Name: booking booking_created_by_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_created_by_employee_id_fkey FOREIGN KEY (created_by_employee_id) REFERENCES public.employee(employee_id) ON DELETE SET NULL;


--
-- Name: booking booking_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON DELETE CASCADE;


--
-- Name: booking booking_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE CASCADE;


--
-- Name: customer customer_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(person_id) ON DELETE CASCADE;


--
-- Name: employee employee_hotel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_hotel_id_fkey FOREIGN KEY (hotel_id) REFERENCES public.hotel(hotel_id) ON DELETE CASCADE;


--
-- Name: employee employee_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.person(person_id) ON DELETE CASCADE;


--
-- Name: hotel hotel_chain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hotel
    ADD CONSTRAINT hotel_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES public.hotel_chain(chain_id) ON DELETE CASCADE;


--
-- Name: payment payment_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employee(employee_id) ON DELETE RESTRICT;


--
-- Name: payment payment_renting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_renting_id_fkey FOREIGN KEY (renting_id) REFERENCES public.renting(renting_id) ON DELETE CASCADE;


--
-- Name: renting renting_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting
    ADD CONSTRAINT renting_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON DELETE CASCADE;


--
-- Name: renting renting_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting
    ADD CONSTRAINT renting_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employee(employee_id) ON DELETE RESTRICT;


--
-- Name: renting renting_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting
    ADD CONSTRAINT renting_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE CASCADE;


--
-- Name: renting renting_source_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.renting
    ADD CONSTRAINT renting_source_booking_id_fkey FOREIGN KEY (source_booking_id) REFERENCES public.booking(booking_id) ON DELETE SET NULL;


--
-- Name: room room_hotel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_hotel_id_fkey FOREIGN KEY (hotel_id) REFERENCES public.hotel(hotel_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict qZzUMxachcmbAyLQFlY8wV7KGkWAWHIFl1VxRbZ5pUbRlkHmPeRqMR9aP2awNJb

