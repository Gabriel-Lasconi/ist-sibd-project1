-- ============================================================================
-- SIBD Project 1 – Boat Management System
-- create_tables.sql
--
--  • Drops existing tables (if any)
--  • Creates all base tables and basic constraints
--  • Lists, as comments, integrity constraints that cannot be enforced in SQL
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Drop tables in reverse dependency order
-- ---------------------------------------------------------------------------
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

-- ===========================================================================
--  Base entities
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Country
-- ---------------------------------------------------------------------------
CREATE TABLE country (
    iso_code   CHAR(3)      PRIMARY KEY,      -- standard ISO code, e.g. 'PRT'
    name       VARCHAR(60)  NOT NULL UNIQUE,
    flag       VARCHAR(200) NOT NULL UNIQUE   -- could be URL or file name
);

-- IC (not enforceable in plain SQL):
--  • Any country that registers boats must have at least one location.

-- ---------------------------------------------------------------------------
-- Boat class
-- ---------------------------------------------------------------------------
CREATE TABLE boat_class (
    class_id      VARCHAR(20) PRIMARY KEY,
    description   VARCHAR(100),
    max_length_m  NUMERIC(6,2) NOT NULL CHECK (max_length_m > 0)
);

-- ---------------------------------------------------------------------------
-- Boat
-- ---------------------------------------------------------------------------
CREATE TABLE boat (
    cni               VARCHAR(40) PRIMARY KEY,      -- unique national boat id
    name              VARCHAR(80) NOT NULL,
    length_m          NUMERIC(6,2) NOT NULL CHECK (length_m > 0),
    registration_year INTEGER     NOT NULL
                                 CHECK (registration_year >= 1900),
    class_id          VARCHAR(20) NOT NULL,
    flag_country      CHAR(3)     NOT NULL,         -- country where it is registered
    picture_url       VARCHAR(300),

    FOREIGN KEY (class_id)     REFERENCES boat_class(class_id),
    FOREIGN KEY (flag_country) REFERENCES country(iso_code)
);

-- IC (domain-level):
--  • For each class, boats must not exceed the maximum length of that class
--    (boat.length_m <= boat_class.max_length_m). This would require a trigger.

-- ---------------------------------------------------------------------------
-- Sailor
-- ---------------------------------------------------------------------------
CREATE TABLE sailor (
    sailor_id   SERIAL       PRIMARY KEY,
    first_name  VARCHAR(40)  NOT NULL,
    surname     VARCHAR(60)  NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    category    VARCHAR(10)  NOT NULL,
    CHECK (category IN ('Senior', 'Junior'))
);

-- IC:
--  • Senior sailors have extra responsibilities; some of them are enforced
--    via constraints/comments in reservation_sailor and trip.

-- ---------------------------------------------------------------------------
-- Location
-- ---------------------------------------------------------------------------
CREATE TABLE location (
    location_id  SERIAL       PRIMARY KEY,
    name         VARCHAR(80)  NOT NULL,
    latitude     NUMERIC(8,5) NOT NULL,   -- degrees
    longitude    NUMERIC(8,5) NOT NULL,   -- degrees
    iso_code     CHAR(3)      NOT NULL,

    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
);

-- IC (not implementable with standard constraints):
--  • Any two locations in the system must be at least one nautical mile apart.

-- ---------------------------------------------------------------------------
-- Jurisdiction
-- ---------------------------------------------------------------------------
CREATE TABLE jurisdiction (
    jurisdiction_id SERIAL       PRIMARY KEY,
    name            VARCHAR(80)  NOT NULL,
    kind            VARCHAR(30)  NOT NULL,
        -- e.g. 'Internal Waters', 'Territorial Sea', 'EEZ', 'International Waters'
    iso_code        CHAR(3),     -- NULL for 'International Waters'

    FOREIGN KEY (iso_code) REFERENCES country(iso_code)
);

-- IC (cross-attribute, hard to enforce in pure SQL):
--  • If kind = 'International Waters', iso_code must be NULL;
--    otherwise iso_code must be NOT NULL.


-- ===========================================================================
--  Reservations and participation
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Reservation
-- ---------------------------------------------------------------------------
CREATE TABLE reservation (
    reservation_id SERIAL      PRIMARY KEY,
    boat_cni       VARCHAR(40) NOT NULL,
    start_date     DATE        NOT NULL,
    end_date       DATE        NOT NULL,
    fast_booking   BOOLEAN     NOT NULL DEFAULT FALSE,

    FOREIGN KEY (boat_cni) REFERENCES boat(cni),
    CHECK (end_date >= start_date)
);

-- IC (requires multi-row checks / triggers):
--  • Every reservation must include at least one authorized sailor.
--  • Among the authorized sailors, at least one must be a Senior sailor
--    who is marked as responsible for the reservation.
--  • Only authorized sailors may navigate or operate the boat during the
--    reservation’s time frame.


-- ---------------------------------------------------------------------------
-- Reservation_Sailor – authorized sailors per reservation
-- ---------------------------------------------------------------------------
CREATE TABLE reservation_sailor (
    reservation_id  INTEGER    NOT NULL,
    sailor_id       INTEGER    NOT NULL,
    is_responsible  BOOLEAN    NOT NULL DEFAULT FALSE,

    PRIMARY KEY (reservation_id, sailor_id),

    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (sailor_id)      REFERENCES sailor(sailor_id)
);

-- IC (requires triggers):
--  • For each reservation, at least one row must exist in this table.
--  • Exactly one authorized sailor per reservation should be responsible.
--  • Any sailor with is_responsible = TRUE must be of category 'Senior'.


-- ===========================================================================
--  Trips
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Trip
-- ---------------------------------------------------------------------------
CREATE TABLE trip (
    trip_id          SERIAL       PRIMARY KEY,
    reservation_id   INTEGER      NOT NULL,
    skipper_id       INTEGER      NOT NULL,
    start_location   INTEGER      NOT NULL,
    end_location     INTEGER      NOT NULL,
    takeoff_date     DATE         NOT NULL,
    arrival_date     DATE         NOT NULL,
    insurance_ref    VARCHAR(60)  NOT NULL,

    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    FOREIGN KEY (skipper_id)     REFERENCES sailor(sailor_id),
    FOREIGN KEY (start_location) REFERENCES location(location_id),
    FOREIGN KEY (end_location)   REFERENCES location(location_id),

    CHECK (arrival_date >= takeoff_date)
);

-- IC (requires multi-table logic):
--  • The skipper of a trip must be one of the authorized sailors for the
--    corresponding reservation (i.e., appear in reservation_sailor).
--  • The boat that performs the trip is the boat of the reservation; this
--    is guaranteed only indirectly via reservation.boat_cni.


-- ---------------------------------------------------------------------------
-- Trip_Jurisdiction – jurisdictions crossed by a trip
-- ---------------------------------------------------------------------------
CREATE TABLE trip_jurisdiction (
    trip_id         INTEGER NOT NULL,
    jurisdiction_id INTEGER NOT NULL,
    sequence_no     INTEGER NOT NULL,   -- order of crossing

    PRIMARY KEY (trip_id, jurisdiction_id),
    FOREIGN KEY (trip_id)         REFERENCES trip(trip_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);

-- IC:
--  • A trip should list all jurisdictions it navigates in the order they are
--    crossed. Ensuring completeness and correct order requires application
--    logic, not just SQL constraints.


-- ===========================================================================
--  Certificates
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Certificate – a personal sailing certification
-- ---------------------------------------------------------------------------
CREATE TABLE certificate (
    certificate_id  SERIAL      PRIMARY KEY,
    sailor_id       INTEGER     NOT NULL,
    class_id        VARCHAR(20) NOT NULL,
    issue_date      DATE        NOT NULL,
    expiry_date     DATE        NOT NULL,

    FOREIGN KEY (sailor_id) REFERENCES sailor(sailor_id),
    FOREIGN KEY (class_id)  REFERENCES boat_class(class_id),

    CHECK (expiry_date > issue_date)
);

-- IC:
--  • Certificates authorize the sailor to act as skipper for the given boat
--    class in one or more country jurisdictions (see certificate_jurisdiction).
--  • A sailor should not act as skipper outside the jurisdictions and classes
--    for which he/she holds valid certificates; this cannot be enforced only
--    with constraints on this table.


-- ---------------------------------------------------------------------------
-- Certificate_Jurisdiction – coverage of a certificate
-- ---------------------------------------------------------------------------
CREATE TABLE certificate_jurisdiction (
    certificate_id  INTEGER NOT NULL,
    jurisdiction_id INTEGER NOT NULL,

    PRIMARY KEY (certificate_id, jurisdiction_id),

    FOREIGN KEY (certificate_id)  REFERENCES certificate(certificate_id),
    FOREIGN KEY (jurisdiction_id) REFERENCES jurisdiction(jurisdiction_id)
);

-- End of create_tables.sql