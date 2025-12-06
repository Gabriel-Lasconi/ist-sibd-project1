-- ============================================================================
-- Names of all boats that are used in some trip
-- ============================================================================

SELECT DISTINCT b.name
FROM boat b
JOIN reservation r ON r.boat_cni = b.cni
JOIN trip t ON t.reservation_id = r.reservation_id;

-- ============================================================================
-- Names of all boats that are not used in any trip
-- ============================================================================

SELECT b.name
FROM boat b
LEFT JOIN reservation r ON r.boat_cni = b.cni
LEFT JOIN trip t ON t.reservation_id = r.reservation_id
WHERE t.trip_id IS NULL;

-- ============================================================================
-- Names of all all boats registered in 'PRT' where at least one responsible 
-- for a reservation has surname ending with 'Santos'
-- ============================================================================

SELECT DISTINCT b.name
FROM boat b
JOIN reservation r ON r.boat_cni = b.cni
JOIN reservation_sailor rs ON rs.reservation_id = r.reservation_id
JOIN sailor s ON s.sailor_id = rs.sailor_id
WHERE b.flag_iso_code = 'PRT'
  AND rs.is_responsible = TRUE
  AND s.surname LIKE '%Santos';

-- ============================================================================
-- Full names of all skippers without any certificate corresponding to the class
-- of the trip's boat
-- ============================================================================

SELECT DISTINCT s.first_name || ' ' || s.surname AS full_name
FROM trip t
JOIN sailor s ON s.sailor_id = t.skipper_id
JOIN reservation r ON r.reservation_id = t.reservation_id
JOIN boat b ON b.cni = r.boat_cni
LEFT JOIN certificate c ON c.sailor_id = s.sailor_id AND c.class_name = b.class_name
WHERE c.certificate_id IS NULL;
