-- ============================================================================
-- SIBD Project 1 – Boat Management System
-- schema.sql – create schema + base tables
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS project;
SET search_path TO project;

-- drop in reverse dependency order
DROP TABLE IF EXISTS valid_in CASCADE;
DROP TABLE IF EXISTS certificate CASCADE;
DROP TABLE IF EXISTS crosses CASCADE;
DROP TABLE IF EXISTS trip CASCADE;
DROP TABLE IF EXISTS participates CASCADE;
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
    name       VARCHAR(70)  NOT NULL UNIQUE,   -- IC-2: country name is unique
    flag       VARCHAR(200) NOT NULL UNIQUE    -- IC-3: country flag is unique
    -- IC-4: any country that registers boats must have at least one location
);

CREATE TABLE boat_class (
    class_name    VARCHAR(30) PRIMARY KEY,
    max_length  NUMERIC(6,2) NOT NULL CHECK (max_length > 0)
);

CREATE TABLE boat (
    cni               VARCHAR(40) PRIMARY KEY,
    name              VARCHAR(80) NOT NULL,
    length          NUMERIC(6,2) NOT NULL CHECK (length > 0),
    year_of_registr INTEGER     NOT NULL CHECK (year_of_registr >= 1900),
    class_name        VARCHAR(30) NOT NULL,
    flag_iso_code     CHAR(3)     NOT NULL,
    picture_url       VARCHAR(300),
    FOREIGN KEY (class_name)    REFERENCES boat_class(class_name),
    FOREIGN KEY (flag_iso_code) REFERENCES country(iso_code)
    -- IC-1: boat.length_m must not exceed the max_length_m of its boat_class
);

CREATE TABLE sailor (
    sailor_id   INTEGER      PRIMARY KEY,
    first_name  VARCHAR(80)  NOT NULL,
    surname     VARCHAR(80)  NOT NULL,
    email       VARCHAR(254) NOT NULL,
    category    VARCHAR(10)  NOT NULL,
    CHECK (category IN ('Senior', 'Junior'))
    -- IC-5 / IC-6 / IC-10 depend on category when sailor is responsible / skipper
);

CREATE TABLE location (
    location_id  INTEGER      PRIMARY KEY,
    name         VARCHAR(80)  NOT NULL,
    latitude     NUMERIC(8,5) NOT NULL,
    longitude    NUMERIC(8,5) NOT NULL,
    iso_code     CHAR(3)      NOT NULL,
    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
    -- IC-7: any two locations must be at least one nautical mile apart
);

CREATE TABLE jurisdiction (
    jurisdiction_id INTEGER     PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    type            VARCHAR(30) NOT NULL,
    iso_code        CHAR(3),
    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
    -- IC-8: there is exactly one country administering a non-international jurisdiction; jurisdictions of type 'International Waters' have no country
);

-- ============================================================================
-- Reservations and participation
-- ============================================================================

CREATE TABLE reservation (
    reservation_id INTEGER      PRIMARY KEY,
    boat_cni       VARCHAR(40)  NOT NULL,
    start_date     DATE         NOT NULL,
    end_date       DATE         NOT NULL,
    CHECK (end_date >= start_date), -- IC-11: valid reservation interval
    FOREIGN KEY (boat_cni) REFERENCES boat(cni)
    -- IC-13 relates reservation and trip dates (trip inside reservation period)
);

-- association <participates> between Reservation and Sailor
CREATE TABLE participates (
    reservation_id  INTEGER  NOT NULL,
    sailor_id       INTEGER  NOT NULL,
    is_responsible  BOOLEAN  NOT NULL DEFAULT FALSE,
    PRIMARY KEY (reservation_id, sailor_id),
    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (sailor_id)      REFERENCES sailor(sailor_id)
    -- IC-5: each reservation has exactly one responsible sailor and that sailor must be Senior
);

-- ============================================================================
-- Trips
-- ============================================================================

CREATE TABLE trip (
    trip_id         INTEGER      PRIMARY KEY,
    reservation_id  INTEGER      NOT NULL,
    skipper_id      INTEGER      NOT NULL,
    start_location  INTEGER      NOT NULL,
    end_location    INTEGER      NOT NULL,
    takeoff_date    DATE         NOT NULL,
    arrival_date    DATE         NOT NULL,
    insurance_ref   VARCHAR(60)  NOT NULL,
    CHECK (arrival_date >= takeoff_date), -- IC-12: valid trip interval
    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (skipper_id)     REFERENCES sailor(sailor_id),
    FOREIGN KEY (start_location) REFERENCES location(location_id),
    FOREIGN KEY (end_location)   REFERENCES location(location_id)
    -- IC-6: skipper must be an authorised participant in the reservation
    -- IC-10: skipper must have a valid certificate for the boat class, jurisdiction(s) and trip dates
    -- IC-13: trip dates must lie inside the reservation period
);

-- association <crosses_by> between Trip and Jurisdiction
CREATE TABLE crosses (
    trip_id         INTEGER NOT NULL,
    sequence_no     INTEGER NOT NULL, -- order in which jurisdictions are crossed
    jurisdiction_id INTEGER NOT NULL,
    PRIMARY KEY (trip_id, sequence_no),
    FOREIGN KEY (trip_id)         REFERENCES trip(trip_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);

-- ============================================================================
-- Certificates
-- ============================================================================

CREATE TABLE certificate (
    certificate_id  INTEGER     PRIMARY KEY,
    sailor_id       INTEGER     NOT NULL,
    class_name      VARCHAR(30) NOT NULL,
    issue_date      DATE        NOT NULL,
    expiry_date     DATE        NOT NULL,
    CHECK (expiry_date > issue_date), -- part of IC-9: dates themselves valid
    FOREIGN KEY (sailor_id)  REFERENCES sailor(sailor_id),
    FOREIGN KEY (class_name) REFERENCES boat_class(class_name)
    -- IC-9: expired certificates must not authorise future trips
);

-- association <valid_in> between Certificate and Jurisdiction
CREATE TABLE valid_in (
    certificate_id  INTEGER NOT NULL,
    jurisdiction_id INTEGER NOT NULL,
    PRIMARY KEY (certificate_id, jurisdiction_id),
    FOREIGN KEY (certificate_id)  REFERENCES certificate(certificate_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);