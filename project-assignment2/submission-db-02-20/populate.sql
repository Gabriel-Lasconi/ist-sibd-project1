-- ============================================================================
-- SIBD Project Assignment 2 – Boat Management System (Part 2)
-- populate.sql – sample data for schema-part2.sql
-- ============================================================================

TRUNCATE TABLE
  trip,
  authorised,
  reservation,
  date_interval,
  boat,
  valid_for,
  sailing_certificate,
  boat_class,
  senior,
  junior,
  sailor,
  location,
  country
RESTART IDENTITY CASCADE;

-- ============================================================================
-- Countries  (PK = name, iso_code is UNIQUE)
-- ============================================================================

INSERT INTO country (iso_code, flag, name) VALUES
('PRT', 'prt_flag.png', 'Portugal'),
('ESP', 'esp_flag.png', 'Spain'),
('GBR', 'gbr_flag.png', 'United Kingdom'),
('ROU', 'rou_flag.png', 'Romania'),
('CHE', 'che_flag.png', 'Switzerland'),
('RUS', 'rus_flag.png', 'Russia');

-- ============================================================================
-- Locations (PK = (latitude, longitude), FK country_name -> country(name))
-- Make sure every country where we register boats has >= 1 location (IC-1)
-- ============================================================================

INSERT INTO location (latitude, longitude, name, country_name) VALUES
-- Portugal
(38.722300, -9.139300, 'Lisbon Marina', 'Portugal'),
(41.157900, -8.629100, 'Porto Marina',  'Portugal'),

-- Spain
(42.240600, -8.720700, 'Vigo Harbor',   'Spain'),

-- United Kingdom
(51.507400, -0.127800, 'London Dock',   'United Kingdom'),

-- Romania
(44.426800, 26.102500, 'Bucharest Pier (Dambovita)', 'Romania'),

-- Switzerland
(46.204400,  6.143200, 'Geneva Marina', 'Switzerland');

-- ============================================================================
-- Sailors (PK = email) + specialization (junior/senior)
-- NOTE: mandatory specialization is a requirement (comment in schema),
-- so we insert every sailor into exactly one of (junior, senior).
-- ============================================================================

INSERT INTO sailor (firstname, surname, email) VALUES
('Gabriel', 'Lasconi', 'gabriel.lasconi@example.com'),
('Emy',     'Bimond',  'emy.bimond@example.com'),
('Ilia',    'Golub',   'ilia.golub@example.com'),
('Joao',    'Santos',  'joao.santos@example.com'),
('Maria',   'Santos',  'maria.santos@example.com'),
('Luis',    'Garcia',  'luis.garcia@example.com');

-- Seniors
INSERT INTO senior (email) VALUES
('gabriel.lasconi@example.com'),
('emy.bimond@example.com'),
('joao.santos@example.com'),
('luis.garcia@example.com');

-- Juniors
INSERT INTO junior (email) VALUES
('ilia.golub@example.com'),
('maria.santos@example.com');

-- ============================================================================
-- Boat classes
-- ============================================================================

INSERT INTO boat_class (name, max_length) VALUES
('ClassA', 10.00),
('ClassB', 15.00),
('Yacht',  30.00);

-- ============================================================================
-- Sailing certificates + valid_for (mandatory participation for sailing_certificate)
-- PK(certificate) = (sailor, issue_date)
-- ============================================================================

-- Joao Santos: ClassA certificate, valid in Portugal + Spain
INSERT INTO sailing_certificate (issue_date, expiry_date, sailor, boat_class) VALUES
(TIMESTAMP '2024-01-10 09:00:00', TIMESTAMP '2027-01-10 00:00:00', 'joao.santos@example.com', 'ClassA');

INSERT INTO valid_for (country_name, max_length, sailor, issue_date) VALUES
('Portugal', 10.00, 'joao.santos@example.com', TIMESTAMP '2024-01-10 09:00:00'),
('Spain',    10.00, 'joao.santos@example.com', TIMESTAMP '2024-01-10 09:00:00');

-- Joao Santos: classB certificate, valid in Portugal
INSERT INTO sailing_certificate (issue_date, expiry_date, sailor, boat_class) VALUES
(TIMESTAMP '2024-02-01 10:00:00', TIMESTAMP '2027-02-01 00:00:00',
 'joao.santos@example.com', 'ClassB');

INSERT INTO valid_for (country_name, max_length, sailor, issue_date) VALUES
('Portugal', 15.00, 'joao.santos@example.com', TIMESTAMP '2024-02-01 10:00:00');

-- Gabriel Lasconi: ClassB certificate, valid in Portugal + Spain + Romania
INSERT INTO sailing_certificate (issue_date, expiry_date, sailor, boat_class) VALUES
(TIMESTAMP '2023-03-05 10:30:00', TIMESTAMP '2026-03-05 00:00:00', 'gabriel.lasconi@example.com', 'ClassB');

INSERT INTO valid_for (country_name, max_length, sailor, issue_date) VALUES
('Portugal', 15.00, 'gabriel.lasconi@example.com', TIMESTAMP '2023-03-05 10:30:00'),
('Spain',    15.00, 'gabriel.lasconi@example.com', TIMESTAMP '2023-03-05 10:30:00'),
('Romania',  15.00, 'gabriel.lasconi@example.com', TIMESTAMP '2023-03-05 10:30:00');

-- Emy Bimond: ONLY ClassA certificate, valid only in Switzerland
INSERT INTO sailing_certificate (issue_date, expiry_date, sailor, boat_class) VALUES
(TIMESTAMP '2024-05-20 08:00:00', TIMESTAMP '2026-05-20 00:00:00', 'emy.bimond@example.com', 'ClassA');

INSERT INTO valid_for (country_name, max_length, sailor, issue_date) VALUES
('Switzerland', 10.00, 'emy.bimond@example.com', TIMESTAMP '2024-05-20 08:00:00');

-- Luis Garcia: ClassB certificate, valid in Portugal + United Kingdom
INSERT INTO sailing_certificate (issue_date, expiry_date, sailor, boat_class) VALUES
(TIMESTAMP '2022-11-01 12:00:00', TIMESTAMP '2026-11-01 00:00:00', 'luis.garcia@example.com', 'ClassB');

INSERT INTO valid_for (country_name, max_length, sailor, issue_date) VALUES
('Portugal',        15.00, 'luis.garcia@example.com', TIMESTAMP '2022-11-01 12:00:00'),
('United Kingdom',  15.00, 'luis.garcia@example.com', TIMESTAMP '2022-11-01 12:00:00');

-- ============================================================================
-- Boats (PK = (country, cni))
-- Some will have trips, some only reservations, one never used
-- ============================================================================

INSERT INTO boat (country, year, cni, name, length, boat_class) VALUES
('Portugal',        2018, 'SEA-001', 'Atlantic Breeze',  8.50, 'ClassA'),
('Portugal',        2019, 'SEA-002', 'Lusitania Star',  12.00, 'ClassB'),
('Spain',           2020, 'SEA-003', 'Costa del Sol',   11.20, 'ClassB'),
('Portugal',        2021, 'SEA-004', 'Ocean Queen',     24.00, 'Yacht'),
('United Kingdom',  2017, 'SEA-005', 'Foggy London',     9.80, 'ClassA'),
('Romania',         2016, 'SEA-006', 'Danube Runner',    7.00, 'ClassA');  -- unused boat

-- ============================================================================
-- Date intervals (reservation periods)
-- ============================================================================

INSERT INTO date_interval (start_date, end_date) VALUES
(DATE '2025-06-01', DATE '2025-06-05'),
(DATE '2025-07-10', DATE '2025-07-15'),
(DATE '2025-08-01', DATE '2025-08-05'),
(DATE '2025-09-01', DATE '2025-09-03'),
(DATE '2025-10-01', DATE '2025-10-02');  -- reservation but no trip

-- ============================================================================
-- Reservations (PK = start_date,end_date,country,cni)
-- responsible must be a SENIOR (FK to senior(email))
-- ============================================================================

INSERT INTO reservation (start_date, end_date, country, cni, responsible) VALUES
-- SEA-001 (Portugal, ClassA) responsible Santos (good for “surname ends with Santos” style tests)
(DATE '2025-06-01', DATE '2025-06-05', 'Portugal', 'SEA-001', 'joao.santos@example.com'),

-- SEA-002 (Portugal, ClassB) responsible Gabriel
(DATE '2025-07-10', DATE '2025-07-15', 'Portugal', 'SEA-002', 'gabriel.lasconi@example.com'),

-- SEA-003 (Spain, ClassB) responsible Luis
(DATE '2025-08-01', DATE '2025-08-05', 'Spain', 'SEA-003', 'luis.garcia@example.com'),

-- SEA-004 (Portugal, Yacht) responsible Emy (still Senior)
(DATE '2025-09-01', DATE '2025-09-03', 'Portugal', 'SEA-004', 'emy.bimond@example.com'),

-- SEA-005 (UK, ClassA) reservation but no trip
(DATE '2025-10-01', DATE '2025-10-02', 'United Kingdom', 'SEA-005', 'luis.garcia@example.com');

-- ============================================================================
-- Authorised sailors for each reservation
-- Must include at least one row per reservation (mandatory participation)
-- Also include the responsible senior among authorised (IC-6 intention)
-- ============================================================================

INSERT INTO authorised (start_date, end_date, boat_country, cni, sailor) VALUES
-- Reservation SEA-001 (Joao responsible, Ilia joins)
(DATE '2025-06-01', DATE '2025-06-05', 'Portugal', 'SEA-001', 'joao.santos@example.com'),
(DATE '2025-06-01', DATE '2025-06-05', 'Portugal', 'SEA-001', 'ilia.golub@example.com'),

-- Reservation SEA-002 (Gabriel responsible, Emy joins)
(DATE '2025-07-10', DATE '2025-07-15', 'Portugal', 'SEA-002', 'gabriel.lasconi@example.com'),
(DATE '2025-07-10', DATE '2025-07-15', 'Portugal', 'SEA-002', 'emy.bimond@example.com'),

-- Reservation SEA-003 (Luis responsible, Maria joins)
(DATE '2025-08-01', DATE '2025-08-05', 'Spain', 'SEA-003', 'luis.garcia@example.com'),
(DATE '2025-08-01', DATE '2025-08-05', 'Spain', 'SEA-003', 'maria.santos@example.com'),

-- Reservation SEA-004 (Emy responsible, Gabriel joins)
(DATE '2025-09-01', DATE '2025-09-03', 'Portugal', 'SEA-004', 'emy.bimond@example.com'),
(DATE '2025-09-01', DATE '2025-09-03', 'Portugal', 'SEA-004', 'gabriel.lasconi@example.com'),

-- Reservation SEA-005 (Luis responsible, Joao joins)
(DATE '2025-10-01', DATE '2025-10-02', 'United Kingdom', 'SEA-005', 'luis.garcia@example.com'),
(DATE '2025-10-01', DATE '2025-10-02', 'United Kingdom', 'SEA-005', 'joao.santos@example.com');

-- ============================================================================
-- Trips
-- PK = (takeoff, reservation_start_date, reservation_end_date, boat_country, cni)
-- Must reference reservation + locations + skipper(sailor)
-- takeoff >= reservation_start_date is enforced by CHECK (IC-4)
-- Skipper should be in authorised for that reservation (IC-3 intention)
-- ============================================================================

INSERT INTO trip (
  takeoff, arrival, insurance,
  from_latitude, from_longitude, to_latitude, to_longitude,
  skipper,
  reservation_start_date, reservation_end_date,
  boat_country, cni
) VALUES
-- Trip 1: SEA-001 (Portugal ClassA), skipper Joao (authorised + has ClassA cert)
(DATE '2025-06-01', DATE '2025-06-04', 'INS-001',
 38.722300, -9.139300, 41.157900, -8.629100,
 'joao.santos@example.com',
 DATE '2025-06-01', DATE '2025-06-05', 'Portugal', 'SEA-001'),

-- Trip 2: SEA-002 (Portugal ClassB), skipper Gabriel (authorised + has ClassB cert)
(DATE '2025-07-10', DATE '2025-07-14', 'INS-002',
 41.157900, -8.629100, 38.722300, -9.139300,
 'gabriel.lasconi@example.com',
 DATE '2025-07-10', DATE '2025-07-15', 'Portugal', 'SEA-002'),

-- Trip 3: SEA-003 (Spain ClassB), skipper Luis (authorised + has ClassB cert; valid_for includes UK+PRT, not Spain)
(DATE '2025-08-01', DATE '2025-08-04', 'INS-003',
 42.240600, -8.720700, 41.157900, -8.629100,
 'luis.garcia@example.com',
 DATE '2025-08-01', DATE '2025-08-05', 'Spain', 'SEA-003'),

-- Trip 4: SEA-004 (Portugal Yacht), skipper Emy (authorised BUT has only ClassA cert)
-- “skipper without cert for boat class” test case.
(DATE '2025-09-01', DATE '2025-09-03', 'INS-004',
 38.722300, -9.139300, 42.240600, -8.720700,
 'emy.bimond@example.com',
 DATE '2025-09-01', DATE '2025-09-03', 'Portugal', 'SEA-004');