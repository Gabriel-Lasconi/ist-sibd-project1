-- ============================================================================
-- SIBD Project 1 – Boat Management System
-- populate.sql – data to play with and test queries
-- ============================================================================

SET search_path TO project;

TRUNCATE TABLE
    certificate_jurisdiction,
    certificate,
    trip_jurisdiction,
    trip,
    reservation_sailor,
    reservation,
    boat,
    boat_class,
    location,
    jurisdiction,
    sailor,
    country
RESTART IDENTITY CASCADE;

-- ============================================================================
-- Countries
-- ============================================================================

INSERT INTO country (iso_code, name, flag) VALUES
('PRT', 'Portugal',         'prt_flag.png'),
('ESP', 'Spain',            'esp_flag.png'),
('GBR', 'United Kingdom',   'gbr_flag.png'),
('ROU', 'Romania',          'rou_flag.png'),
('CHE', 'Switzerland',      'che_flag.png'),
('RUS', 'Russia',           'rus_flag.png');

-- ============================================================================
-- Boat classes - simple classification for boats
-- ============================================================================

INSERT INTO boat_class (class_name, description, max_length_m) VALUES
('ClassA', 'Small leisure boats',        10.00),
('ClassB', 'Medium sailing boats',       15.00),
('Yacht',  'Large yacht / motor vessel', 30.00);

-- ============================================================================
-- Boats - some boats will be used in trips, some only in reservations, one never used
-- ============================================================================

INSERT INTO boat (cni, name, length_m, registration_year, class_name, flag_iso_code, picture_url) VALUES
('SEA-001', 'Atlantic Breeze',  8.5,  2018, 'ClassA', 'PRT', 'atlantic_breeze.jpg'),
('SEA-002', 'Lusitania Star',  12.0, 2019, 'ClassB', 'PRT', 'lusitania_star.jpg'),
('SEA-003', 'Costa del Sol',   11.2, 2020, 'ClassB', 'ESP', 'costa_del_sol.jpg'),
('SEA-004', 'Ocean Queen',     24.0, 2021, 'Yacht',  'PRT', 'ocean_queen.jpg'),
('SEA-005', 'Foggy London',     9.8, 2017, 'ClassA', 'GBR', 'foggy_london.jpg'),  -- reservation but no trip
('SEA-006', 'Harbor Runner',    7.0, 2016, 'ClassA', 'PRT', 'harbor_runner.jpg'); -- completely unused

-- ============================================================================
-- Sailors
-- ============================================================================

INSERT INTO sailor (sailor_id, first_name, surname, email, category) VALUES
(1, 'Gabriel', 'Lasconi', 'gabriel.lasconi@example.com', 'Senior'),
(2, 'Emy',     'Bimond',  'emy.bimond@example.com',      'Senior'),
(3, 'Ilia',    'Golub',   'ilia.golub@example.com',      'Junior'),
(4, 'Joao',    'Santos',  'joao.santos@example.com',     'Senior'),
(5, 'Maria',   'Santos',  'maria.santos@example.com',    'Junior'),
(6, 'Luis',    'Garcia',  'luis.garcia@example.com',     'Senior');

-- ============================================================================
-- Locations
-- ============================================================================

INSERT INTO location (location_id, name, latitude, longitude, iso_code) VALUES
(1, 'Lisbon Marina', 38.7223,  -9.1393, 'PRT'),
(2, 'Porto Marina',  41.1579,  -8.6291, 'PRT'),
(3, 'Vigo Harbor',   42.2406,  -8.7207, 'ESP'),
(4, 'London Dock',   51.5074,  -0.1278, 'GBR');

-- ============================================================================
-- Jurisdictions
-- ============================================================================

INSERT INTO jurisdiction (jurisdiction_id, name, type, iso_code) VALUES
(1, 'Portugal Coastal Waters',   'National',           'PRT'),
(2, 'Spain Coastal Waters',      'National',           'ESP'),
(3, 'Atlantic International',    'International Waters', NULL);

-- ============================================================================
-- Reservations
-- ============================================================================

INSERT INTO reservation (reservation_id, boat_cni, start_date, end_date) VALUES
(1, 'SEA-001', DATE '2025-06-01', DATE '2025-06-05'),
(2, 'SEA-002', DATE '2025-07-10', DATE '2025-07-15'),
(3, 'SEA-003', DATE '2025-08-01', DATE '2025-08-05'),
(4, 'SEA-004', DATE '2025-09-01', DATE '2025-09-03'),
(5, 'SEA-005', DATE '2025-10-01', DATE '2025-10-02');  -- reservation but no trip

-- ============================================================================
-- Reservation_sailor
-- ============================================================================

INSERT INTO reservation_sailor (reservation_id, sailor_id, is_responsible) VALUES
-- Reservation 1 – responsible sailor with surname Santos
(1, 4, TRUE),
(1, 3, FALSE),

-- Reservation 2 – Gabriel + Emy
(2, 1, TRUE),
(2, 2, FALSE),

-- Reservation 3 – Luis responsible, Maria joins
(3, 6, TRUE),
(3, 5, FALSE),

-- Reservation 4 – only Emy, acting as responsible skipper later
(4, 2, TRUE),

-- Reservation 5 – Joao again + Maria
(5, 4, TRUE),
(5, 5, FALSE);

-- ============================================================================
-- Trips - trips tied to reservations, all skippers are Seniors
-- Trip 4 is to test: Emy on a Yacht with no Yacht cert
-- ============================================================================

INSERT INTO trip (
    trip_id, reservation_id, skipper_id, start_location, end_location,
    takeoff_date, arrival_date, insurance_ref
) VALUES
-- Trip 1: ClassA boat, skipper Joao Santos
(1, 1, 4, 1, 2, DATE '2025-06-01', DATE '2025-06-04', 'INS-001'),

-- Trip 2: ClassB boat, skipper Gabriel
(2, 2, 1, 2, 1, DATE '2025-07-10', DATE '2025-07-14', 'INS-002'),

-- Trip 3: ClassB boat, skipper Luis
(3, 3, 6, 3, 2, DATE '2025-08-01', DATE '2025-08-04', 'INS-003'),

-- Trip 4: Yacht, skipper Emy, but she won’t have a Yacht certificate
(4, 4, 2, 1, 3, DATE '2025-09-01', DATE '2025-09-03', 'INS-004');

-- ============================================================================
-- Trip_jurisdiction - in which waters each trip sails, in order
-- ============================================================================

INSERT INTO trip_jurisdiction (trip_id, sequence_no, jurisdiction_id) VALUES
(1, 1, 1), (1, 2, 3), -- Trip 1: Portugal → International
(2, 1, 1), -- Trip 2: Portugal only
(3, 1, 1), (3, 2, 2), -- Trip 3: Portugal → Spain
(4, 1, 3); -- Trip 4: International only

-- ============================================================================
-- Certificates - who is allowed to skipper which boat classes (at least on paper…)
-- again Emy is missing a Yacht certificate
-- ============================================================================

INSERT INTO certificate (certificate_id, sailor_id, class_name, issue_date, expiry_date) VALUES
(1, 4, 'ClassA', DATE '2024-01-01', DATE '2027-01-01'),  -- Joao Santos – ClassA
(2, 1, 'ClassB', DATE '2023-03-01', DATE '2026-03-01'),  -- Gabriel Lasconi – ClassB
(3, 2, 'ClassA', DATE '2024-05-01', DATE '2026-05-01');  -- Emy Bimond – ClassA only

-- ============================================================================
-- Certificate_jurisdiction - map those certificates to the waters where they’re valid
-- ============================================================================

INSERT INTO certificate_jurisdiction (certificate_id, jurisdiction_id) VALUES
(1, 1), -- Joao → Portugal
(2, 1), (2, 2), -- Gabriel → Portugal + Spain
(3, 3); -- Emy → International only