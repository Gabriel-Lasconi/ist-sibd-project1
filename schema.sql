-- ============================================================================
-- SIBD Project 1 – Boat Management System
-- schema.sql  – create schema + base tables
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS project;
SET search_path TO project;

DROP TABLE IF EXISTS certificate_jurisdiction CASCADE;
DROP TABLE IF EXISTS certificate CASCADE;
DROP TABLE IF EXISTS trip_jurisdiction CASCADE;
DROP TABLE IF EXISTS trip CASCADE;
DROP TABLE IF EXISTS reservation_sailor CASCADE;
DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS boat CASCADE;
DROP TABLE IF EXISTS boat_class CASCADE;
DROP TABLE IF EXISTS location CASCADE;
DROP TABLE IF EXISTS jurisdiction CASCADE;
DROP TABLE IF EXISTS sailor CASCADE;
DROP TABLE IF EXISTS country CASCADE;

-- ============================================================================
-- Base entities
-- ============================================================================

CREATE TABLE country (
    iso_code   CHAR(3)      PRIMARY KEY,
    name       VARCHAR(60)  NOT NULL UNIQUE,
    flag       VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE boat_class (
    class_name    VARCHAR(30) PRIMARY KEY,
    description   VARCHAR(100),
    max_length_m  NUMERIC(6,2) NOT NULL CHECK (max_length_m > 0)
);

CREATE TABLE boat (
    cni               VARCHAR(40) PRIMARY KEY,
    name              VARCHAR(80) NOT NULL,
    length_m          NUMERIC(6,2) NOT NULL CHECK (length_m > 0),
    registration_year INTEGER     NOT NULL CHECK (registration_year >= 1900),
    class_name        VARCHAR(30) NOT NULL,
    flag_iso_code     CHAR(3)     NOT NULL,
    picture_url       VARCHAR(300),

    FOREIGN KEY (class_name)    REFERENCES boat_class(class_name),
    FOREIGN KEY (flag_iso_code) REFERENCES country(iso_code)
);

CREATE TABLE sailor (
    sailor_id   SERIAL       PRIMARY KEY,
    first_name  VARCHAR(40)  NOT NULL,
    surname     VARCHAR(60)  NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    category    VARCHAR(10)  NOT NULL,
    CHECK (category IN ('Senior', 'Junior'))
);

CREATE TABLE location (
    location_id  SERIAL       PRIMARY KEY,
    name         VARCHAR(80)  NOT NULL,
    latitude     NUMERIC(8,5) NOT NULL,
    longitude    NUMERIC(8,5) NOT NULL,
    iso_code     CHAR(3)      NOT NULL,

    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
);

CREATE TABLE jurisdiction (
    jurisdiction_id SERIAL      PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    type            VARCHAR(30) NOT NULL,
    iso_code        CHAR(3),

    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
);

-- ============================================================================
-- Reservations and participation
-- ============================================================================

CREATE TABLE reservation (
    reservation_id SERIAL      PRIMARY KEY,
    boat_cni       VARCHAR(40) NOT NULL,
    start_date     DATE        NOT NULL,
    end_date       DATE        NOT NULL,
    CHECK (end_date >= start_date),

    FOREIGN KEY (boat_cni) REFERENCES boat(cni)
);

CREATE TABLE reservation_sailor (
    reservation_id  INTEGER  NOT NULL,
    sailor_id       INTEGER  NOT NULL,
    is_responsible  BOOLEAN  NOT NULL DEFAULT FALSE,

    PRIMARY KEY (reservation_id, sailor_id),

    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (sailor_id)      REFERENCES sailor(sailor_id)
);

-- ============================================================================
-- Trips
-- ============================================================================

CREATE TABLE trip (
    trip_id         SERIAL       PRIMARY KEY,
    reservation_id  INTEGER      NOT NULL,
    skipper_id      INTEGER      NOT NULL,
    start_location  INTEGER      NOT NULL,
    end_location    INTEGER      NOT NULL,
    takeoff_date    DATE         NOT NULL,
    arrival_date    DATE         NOT NULL,
    insurance_ref   VARCHAR(60)  NOT NULL,
    CHECK (arrival_date >= takeoff_date),

    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (skipper_id)     REFERENCES sailor(sailor_id),
    FOREIGN KEY (start_location) REFERENCES location(location_id),
    FOREIGN KEY (end_location)   REFERENCES location(location_id)
);

CREATE TABLE trip_jurisdiction (
    trip_id         INTEGER NOT NULL,
    sequence_no     INTEGER NOT NULL,
    jurisdiction_id INTEGER NOT NULL,

    PRIMARY KEY (trip_id, sequence_no),

    FOREIGN KEY (trip_id)         REFERENCES trip(trip_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);

-- ============================================================================
-- Certificates
-- ============================================================================

CREATE TABLE certificate (
    certificate_id  SERIAL      PRIMARY KEY,
    sailor_id       INTEGER     NOT NULL,
    class_name      VARCHAR(30) NOT NULL,
    issue_date      DATE        NOT NULL,
    expiry_date     DATE        NOT NULL,
    CHECK (expiry_date > issue_date),

    FOREIGN KEY (sailor_id)  REFERENCES sailor(sailor_id),
    FOREIGN KEY (class_name) REFERENCES boat_class(class_name)
);

CREATE TABLE certificate_jurisdiction (
    certificate_id  INTEGER NOT NULL,
    jurisdiction_id INTEGER NOT NULL,

    PRIMARY KEY (certificate_id, jurisdiction_id),

    FOREIGN KEY (certificate_id)  REFERENCES certificate(certificate_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);