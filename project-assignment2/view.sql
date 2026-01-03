-- ============================================================================
-- SIBD Project Assignment 2 – Boat Management System
-- view.sql – trip_info view
-- ============================================================================

DROP VIEW IF EXISTS trip_info;

CREATE VIEW trip_info AS
SELECT
  -- Origin country
  c_origin.iso_code        AS country_iso_origin,
  c_origin.name            AS country_name_origin,

  -- Destination country
  c_dest.iso_code          AS country_iso_dest,
  c_dest.name              AS country_name_dest,

  -- Origin/Destination location names
  l_origin.name            AS loc_name_origin,
  l_dest.name              AS loc_name_dest,

  -- Boat info
  b.cni                    AS cni_boat,
  c_boat.iso_code          AS country_iso_boat,
  c_boat.name              AS country_name_boat,

  -- Trip start date
  t.takeoff                AS trip_start_date

FROM trip t
JOIN location l_origin
  ON t.from_latitude  = l_origin.latitude
 AND t.from_longitude = l_origin.longitude
JOIN country c_origin
  ON l_origin.country_name = c_origin.name

JOIN location l_dest
  ON t.to_latitude  = l_dest.latitude
 AND t.to_longitude = l_dest.longitude
JOIN country c_dest
  ON l_dest.country_name = c_dest.name

JOIN boat b
  ON t.boat_country = b.country
 AND t.cni          = b.cni
JOIN country c_boat
  ON b.country = c_boat.name;

-- Testing
SELECT * FROM trip_info;
SELECT country_name_origin, country_name_dest, cni_boat, trip_start_date FROM trip_info;