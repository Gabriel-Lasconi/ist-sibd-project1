#!/usr/bin/python3
#!/usr/bin/env python3
# web/trips.cgi

import cgi
import os
import psycopg2

import db
from ui import (
    print_header, print_footer, h, message,
    form_row, date_input, text_input, select
)


# -------------------------
# Parsers
# -------------------------
def parse_rkey(rkey: str):
    # rkey format: start||end||country||cni
    if not rkey:
        return None
    parts = rkey.split("||")
    if len(parts) != 4:
        return None
    start_date, end_date, country, cni = [p.strip() for p in parts]
    if not (start_date and end_date and country and cni):
        return None
    return start_date, end_date, country, cni


def parse_lkey(lkey: str):
    # lkey format: latitude||longitude (as strings)
    if not lkey:
        return None
    parts = lkey.split("||")
    if len(parts) != 2:
        return None
    lat, lon = [p.strip() for p in parts]
    if not (lat and lon):
        return None
    return lat, lon


# -------------------------
# Fetch data
# -------------------------
def fetch_reservations(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT r.start_date, r.end_date, r.country, r.cni,
                   b.name AS boat_name,
                   r.responsible,
                   sa.firstname, sa.surname
            FROM reservation r
            JOIN boat b
              ON b.country = r.country AND b.cni = r.cni
            JOIN sailor sa
              ON sa.email = r.responsible
            ORDER BY r.start_date DESC, r.end_date DESC, r.country, r.cni;
        """)
        return cur.fetchall()


def fetch_locations(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT latitude, longitude, name, country_name
            FROM location
            ORDER BY country_name, name, latitude, longitude;
        """)
        return cur.fetchall()


def fetch_authorised_sailors(conn, key):
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT a.sailor, sa.firstname, sa.surname
            FROM authorised a
            JOIN sailor sa ON sa.email = a.sailor
            WHERE a.start_date   = %s
              AND a.end_date     = %s
              AND a.boat_country = %s
              AND a.cni          = %s
            ORDER BY sa.surname, sa.firstname, a.sailor;
        """, (start_date, end_date, country, cni))
        return cur.fetchall()


def fetch_trips(conn, key):
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT t.takeoff,
                   t.arrival,
                   t.insurance,
                   t.skipper,
                   sa.firstname,
                   sa.surname,
                   lf.name AS from_name,
                   lf.country_name AS from_country,
                   t.from_latitude,
                   t.from_longitude,
                   lt.name AS to_name,
                   lt.country_name AS to_country,
                   t.to_latitude,
                   t.to_longitude
            FROM trip t
            JOIN sailor sa
              ON sa.email = t.skipper
            JOIN location lf
              ON lf.latitude = t.from_latitude AND lf.longitude = t.from_longitude
            JOIN location lt
              ON lt.latitude = t.to_latitude AND lt.longitude = t.to_longitude
            WHERE t.reservation_start_date = %s
              AND t.reservation_end_date   = %s
              AND t.boat_country           = %s
              AND t.cni                    = %s
            ORDER BY t.takeoff DESC, t.arrival DESC, t.skipper;
        """, (start_date, end_date, country, cni))
        return cur.fetchall()


def skipper_is_authorised(conn, key, skipper_email: str) -> bool:
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT 1
            FROM authorised
            WHERE start_date   = %s
              AND end_date     = %s
              AND boat_country = %s
              AND cni          = %s
              AND sailor       = %s;
        """, (start_date, end_date, country, cni, skipper_email))
        return cur.fetchone() is not None


# -------------------------
# Actions
# -------------------------
def handle_create(conn, key, form):
    takeoff = (form.getfirst("takeoff") or "").strip()
    arrival = (form.getfirst("arrival") or "").strip()
    insurance = (form.getfirst("insurance") or "").strip()
    skipper = (form.getfirst("skipper") or "").strip()
    from_key = (form.getfirst("from_loc") or "").strip()
    to_key = (form.getfirst("to_loc") or "").strip()

    if not (takeoff and arrival and insurance and skipper and from_key and to_key):
        return ("err", "Missing fields: takeoff, arrival, insurance, skipper, origin, destination are required.")

    if takeoff > arrival:
        return ("err", "Invalid dates: takeoff must be <= arrival.")

    from_parsed = parse_lkey(from_key)
    to_parsed = parse_lkey(to_key)
    if not from_parsed or not to_parsed:
        return ("err", "Invalid location selection.")

    from_lat, from_lon = from_parsed
    to_lat, to_lon = to_parsed

    if from_lat == to_lat and from_lon == to_lon:
        return ("err", "Origin and destination cannot be the same location.")

    # App-level enforcement of the (commented) IC-3:
    # "Skipper must be authorised for the reservation."
    if not skipper_is_authorised(conn, key, skipper):
        return ("err", "Skipper is not authorised for this reservation.")

    start_date, end_date, country, cni = key

    try:
        with conn:  # transaction
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO trip(
                        takeoff, arrival, insurance,
                        from_latitude, from_longitude,
                        to_latitude, to_longitude,
                        skipper,
                        reservation_start_date, reservation_end_date,
                        boat_country, cni
                    )
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);
                """, (
                    takeoff, arrival, insurance,
                    from_lat, from_lon,
                    to_lat, to_lon,
                    skipper,
                    start_date, end_date,
                    country, cni
                ))
        return ("ok", "Trip registered.")
    except psycopg2.Error as e:
        # IC-2 overlap trigger or FK failures will land here.
        return ("err", f"Database error while registering trip: {e.pgerror or str(e)}")


def handle_delete(conn, key, form):
    takeoff = (form.getfirst("takeoff") or "").strip()
    if not takeoff:
        return ("err", "Missing takeoff date to delete trip.")

    start_date, end_date, country, cni = key

    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("""
                    DELETE FROM trip
                    WHERE takeoff = %s
                      AND reservation_start_date = %s
                      AND reservation_end_date   = %s
                      AND boat_country           = %s
                      AND cni                    = %s;
                """, (takeoff, start_date, end_date, country, cni))
                if cur.rowcount == 0:
                    return ("warn", "No matching trip found.")
        return ("ok", "Trip removed.")
    except psycopg2.Error as e:
        return ("err", f"Database error while deleting trip: {e.pgerror or str(e)}")


# -------------------------
# Main
# -------------------------
def main():
    form = cgi.FieldStorage()
    action = (form.getfirst("action") or "").strip().lower()

    rkey = (form.getfirst("rkey") or "").strip()
    key = parse_rkey(rkey)

    msgs = []

    print_header("Trips")

    try:
        with db.connect() as conn:
            reservations = fetch_reservations(conn)

            if not reservations:
                print(message("warn", "No reservations found. Create one in Reservations first."))
                print_footer()
                return

            # If no reservation chosen, default to first
            if not key:
                start_date, end_date, country, cni, *_ = reservations[0]
                key = (str(start_date), str(end_date), str(country), str(cni))
                rkey = f"{key[0]}||{key[1]}||{key[2]}||{key[3]}"

            # Handle POST actions
            if os.environ.get("REQUEST_METHOD", "GET").upper() == "POST":
                if action == "create":
                    msgs.append(handle_create(conn, key, form))
                elif action == "delete":
                    msgs.append(handle_delete(conn, key, form))
                elif action:
                    msgs.append(("err", f"Unknown action: {action}"))

            # Refresh page data
            locations = fetch_locations(conn)
            authorised_sailors = fetch_authorised_sailors(conn, key)
            trips = fetch_trips(conn, key)

    except Exception as e:
        print(message("err", f"Server/connection error: {str(e)}"))
        print_footer()
        return

    for kind, txt in msgs:
        print(message(kind, txt))

    # Reservation selector (GET)
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Select reservation</h3>")

    options = []
    for start_date, end_date, country, cni, boat_name, resp_email, fn, sn in reservations:
        value = f"{start_date}||{end_date}||{country}||{cni}"
        label = f"{start_date} → {end_date} | {boat_name} ({country},{cni}) | responsible: {fn} {sn}"
        options.append((value, label))

    print('<form method="get" action="trips.cgi">')
    print(form_row("Reservation", select("rkey", options, selected=rkey)))
    print('<div class="row"><label></label><button type="submit">Load</button></div>')
    print("</form>")
    print("</div>")

    # Create trip form
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Register trip</h3>")

    if not locations:
        print(message("warn", "No locations found. Populate LOCATION first to register trips."))
    if not authorised_sailors:
        print(message("warn", "No authorised sailors for this reservation. Authorise someone first."))

    loc_opts = []
    for lat, lon, name, country_name in locations:
        value = f"{lat}||{lon}"
        label = f"{name} ({country_name}) [{lat}, {lon}]"
        loc_opts.append((value, label))

    skipper_opts = [(email, f"{fn} {sn} <{email}>") for (email, fn, sn) in authorised_sailors]

    print('<form method="post" action="trips.cgi">')
    print('<input type="hidden" name="action" value="create">')
    print(f'<input type="hidden" name="rkey" value="{h(rkey)}">')

    print(form_row("Takeoff (date)", date_input("takeoff")))
    print(form_row("Arrival (date)", date_input("arrival")))
    print(form_row("Insurance", text_input("insurance", placeholder="policy id / company", size=40)))

    print(form_row("Skipper", select("skipper", skipper_opts) if skipper_opts else "<em>No authorised sailors</em>"))
    print(form_row("Origin", select("from_loc", loc_opts) if loc_opts else "<em>No locations</em>"))
    print(form_row("Destination", select("to_loc", loc_opts) if loc_opts else "<em>No locations</em>"))

    disabled = " disabled" if (not loc_opts or not skipper_opts) else ""
    print(f'<div class="row"><label></label><button type="submit"{disabled}>Register trip</button></div>')
    print("</form>")
    print("</div>")

    # Trips list
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Trips for selected reservation</h3>")

    print("<table>")
    print("<thead><tr>"
          "<th>Takeoff</th><th>Arrival</th><th>Skipper</th><th>Insurance</th>"
          "<th>Origin</th><th>Destination</th><th>Actions</th>"
          "</tr></thead>")
    print("<tbody>")

    if not trips:
        print('<tr><td colspan="7"><em>No rows</em></td></tr>')
    else:
        for (takeoff, arrival, insurance, skipper, fn, sn,
             from_name, from_country, from_lat, from_lon,
             to_name, to_country, to_lat, to_lon) in trips:

            print("<tr>")
            print(f"<td>{h(takeoff)}</td>")
            print(f"<td>{h(arrival)}</td>")
            print(f"<td>{h(fn)} {h(sn)} &lt;{h(skipper)}&gt;</td>")
            print(f"<td>{h(insurance)}</td>")
            print(f"<td>{h(from_name)} ({h(from_country)})</td>")
            print(f"<td>{h(to_name)} ({h(to_country)})</td>")

            print("<td>")
            print(
                '<form method="post" action="trips.cgi" style="margin:0;">'
                '<input type="hidden" name="action" value="delete">'
                f'<input type="hidden" name="rkey" value="{h(rkey)}">'
                f'<input type="hidden" name="takeoff" value="{h(takeoff)}">'
                '<button type="submit" onclick="return confirm(\'Delete this trip?\')">Delete</button>'
                "</form>"
            )
            print("</td>")
            print("</tr>")

    print("</tbody></table>")
    print("</div>")

    # Locations table
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Available locations</h3>")
    print("<table>")
    print("<thead><tr><th>Name</th><th>Country</th><th>Latitude</th><th>Longitude</th></tr></thead>")
    print("<tbody>")
    if not locations:
        print('<tr><td colspan="4"><em>No rows</em></td></tr>')
    else:
        for lat, lon, name, country_name in locations:
            print("<tr>")
            print(f"<td>{h(name)}</td>")
            print(f"<td>{h(country_name)}</td>")
            print(f"<td>{h(lat)}</td>")
            print(f"<td>{h(lon)}</td>")
            print("</tr>")
    print("</tbody></table>")
    print("</div>")

    print_footer()


if __name__ == "__main__":
    main()
