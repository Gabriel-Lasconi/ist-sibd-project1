-- -------------------------
-- IC-1: Every Sailor is either Senior or Junior
-- -------------------------

CREATE OR REPLACE FUNCTION check_sailor_specialization()
RETURNS TRIGGER AS
$$
BEGIN
    -- Disjointness: nobody can be both junior and senior
    IF EXISTS (
        SELECT 1
        FROM junior j
        JOIN senior s USING (email)
        ) THEN
            RAISE EXCEPTION 'IC-1 violated: a sailor cannot be both Junior and Senior.';
    END IF;

    -- Specialization: every sailor must be in junior OR senior
    IF EXISTS (
        SELECT 1
        FROM sailor slr
        WHERE NOT EXISTS (SELECT 1 FROM junior j WHERE j.email = slr.email)
          AND NOT EXISTS (SELECT 1 FROM senior s WHERE s.email = slr.email)
        ) THEN
            RAISE EXCEPTION 'IC-1 violated: every Sailor must be either Junior or Senior.';
    END IF;

    RETURN NULL; -- return value ignored for AFTER triggers
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_check_sailor_specialization_sailor ON sailor;
CREATE CONSTRAINT TRIGGER tg_check_sailor_specialization_sailor
AFTER INSERT OR UPDATE OR DELETE ON sailor
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_sailor_specialization();

DROP TRIGGER IF EXISTS tg_check_sailor_specialization_junior ON junior;
CREATE CONSTRAINT TRIGGER tg_check_sailor_specialization_junior
AFTER INSERT OR UPDATE OR DELETE ON junior
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_sailor_specialization();

DROP TRIGGER IF EXISTS tg_check_sailor_specialization_senior ON senior;
CREATE CONSTRAINT TRIGGER tg_check_sailor_specialization_senior
AFTER INSERT OR UPDATE OR DELETE ON senior
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_sailor_specialization();


-- -------------------------
-- IC-2: Trips for the same reservation must not overlap
-- -------------------------

CREATE OR REPLACE FUNCTION check_trip_no_overlap()
RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM trip t
        WHERE t.reservation_start_date = NEW.reservation_start_date
          AND t.reservation_end_date = NEW.reservation_end_date
          AND t.boat_country = NEW.boat_country
          AND t.cni = NEW.cni

          -- Exclude the row itself
          AND (t.takeoff, t.reservation_start_date, t.reservation_end_date, t.boat_country, t.cni)
                  <> (NEW.takeoff, NEW.reservation_start_date, NEW.reservation_end_date, NEW.boat_country, NEW.cni)

          -- Overlap condition
          AND t.takeoff < NEW.arrival
          AND NEW.takeoff < t.arrival
        ) THEN
            RAISE EXCEPTION
                'IC-2 violated: overlapping trips for reservation (%, %, %, %).',
                NEW.reservation_start_date, NEW.reservation_end_date, NEW.boat_country, NEW.cni;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_check_trip_no_overlap ON trip;
CREATE CONSTRAINT TRIGGER tg_check_trip_no_overlap
AFTER INSERT OR UPDATE ON trip
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW
EXECUTE FUNCTION check_trip_no_overlap();
