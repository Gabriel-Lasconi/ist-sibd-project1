-- ============================================================================
-- Country with the most boats
-- ============================================================================
SELECT b.country
FROM boat b
GROUP BY b.country
HAVING COUNT(*) >= ALL (
    SELECT COUNT(*)
    FROM boat
    GROUP BY country
);

-- ============================================================================
-- Sailors with at least two certificates
-- ============================================================================
SELECT sc.sailor
FROM sailing_certificate sc
GROUP BY sc.sailor
HAVING COUNT(*) >= 2;


-- ============================================================================
-- Sailors who sailed to every location in Portugal
-- ============================================================================
SELECT s.email
FROM sailor s
WHERE NOT EXISTS (
    SELECT 1
    FROM location l
    WHERE l.country_name = 'Portugal'
      AND NOT EXISTS (
          SELECT 1
          FROM trip t
          WHERE t.skipper = s.email
            AND t.to_latitude  = l.latitude
            AND t.to_longitude = l.longitude
      )
);

-- ============================================================================
-- Sailors with the most skipped trips
-- ============================================================================
SELECT a.sailor
FROM authorised a
LEFT JOIN trip t
  ON t.reservation_start_date = a.start_date
 AND t.reservation_end_date   = a.end_date
 AND t.boat_country           = a.boat_country
 AND t.cni                    = a.cni
 AND t.skipper                = a.sailor
WHERE t.skipper IS NULL
GROUP BY a.sailor
HAVING COUNT(*) >= ALL (
    SELECT COUNT(*)
    FROM authorised a2
    LEFT JOIN trip t2
      ON t2.reservation_start_date = a2.start_date
     AND t2.reservation_end_date   = a2.end_date
     AND t2.boat_country           = a2.boat_country
     AND t2.cni                    = a2.cni
     AND t2.skipper                = a2.sailor
    WHERE t2.skipper IS NULL
    GROUP BY a2.sailor
);

-- ============================================================================
-- Sailors with the longest summed trip duration per reservation
-- ============================================================================
SELECT t.skipper,
       t.reservation_start_date,
       t.reservation_end_date,
       t.boat_country,
       t.cni,
       SUM(t.arrival - t.takeoff) AS total_duration
FROM trip t
GROUP BY t.skipper,
         t.reservation_start_date,
         t.reservation_end_date,
         t.boat_country,
         t.cni
HAVING SUM(t.arrival - t.takeoff) >= ALL (
    SELECT SUM(t2.arrival - t2.takeoff)
    FROM trip t2
    GROUP BY t2.skipper,
             t2.reservation_start_date,
             t2.reservation_end_date,
             t2.boat_country,
             t2.cni
);



