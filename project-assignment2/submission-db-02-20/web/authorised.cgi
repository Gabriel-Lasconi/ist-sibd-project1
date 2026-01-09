#!/usr/bin/python3
# web/authorised.cgi

import cgi
import os
import psycopg2

import db
from ui import (
    print_header, print_footer, h, message,
    form_row, select
)


def parse_rkey(rkey: str):
    # rkey format: start||end||country||cni
    if not rkey or "||" not in rkey:
        return None
    parts = rkey.split("||")
    if len(parts) != 4:
        return None
    start_date, end_date, country, cni = [p.strip() for p in parts]
    if not (start_date and end_date and country and cni):
        return None
    return start_date, end_date, country, cni


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


def fetch_authorised(conn, key):
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT a.sailor,
                   sa.firstname,
                   sa.surname,
                   CASE
                     WHEN j.email IS NOT NULL THEN 'Junior'
                     WHEN s.email IS NOT NULL THEN 'Senior'
                     ELSE '—'
                   END AS sailor_type
            FROM authorised a
            JOIN sailor sa ON sa.email = a.sailor
            LEFT JOIN junior j ON j.email = a.sailor
            LEFT JOIN senior s ON s.email = a.sailor
            WHERE a.start_date = %s
              AND a.end_date = %s
              AND a.boat_country = %s
              AND a.cni = %s
            ORDER BY sa.surname, sa.firstname, a.sailor;
        """, (start_date, end_date, country, cni))
        return cur.fetchall()


def fetch_responsible(conn, key):
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT r.responsible, sa.firstname, sa.surname
            FROM reservation r
            JOIN sailor sa ON sa.email = r.responsible
            WHERE r.start_date = %s
              AND r.end_date = %s
              AND r.country = %s
              AND r.cni = %s;
        """, (start_date, end_date, country, cni))
        return cur.fetchone()


def fetch_candidate_sailors(conn, key):
    """
    Sailors not yet authorised for this reservation.
    """
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT sa.email, sa.firstname, sa.surname
            FROM sailor sa
            WHERE NOT EXISTS (
                SELECT 1
                FROM authorised a
                WHERE a.start_date = %s
                  AND a.end_date = %s
                  AND a.boat_country = %s
                  AND a.cni = %s
                  AND a.sailor = sa.email
            )
            ORDER BY sa.surname, sa.firstname, sa.email;
        """, (start_date, end_date, country, cni))
        return cur.fetchall()


def count_authorised(conn, key):
    start_date, end_date, country, cni = key
    with conn.cursor() as cur:
        cur.execute("""
            SELECT COUNT(*)
            FROM authorised
            WHERE start_date = %s
              AND end_date = %s
              AND boat_country = %s
              AND cni = %s;
        """, (start_date, end_date, country, cni))
        return int(cur.fetchone()[0])


def handle_add(conn, key, form):
    sailor = (form.getfirst("sailor") or "").strip()
    if not sailor:
        return ("err", "Choose a sailor to authorise.")

    start_date, end_date, country, cni = key

    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO authorised(start_date, end_date, boat_country, cni, sailor)
                    VALUES (%s, %s, %s, %s, %s);
                """, (start_date, end_date, country, cni, sailor))
        return ("ok", f"Authorised {sailor}.")
    except psycopg2.Error as e:
        return ("err", f"Database error while authorising: {e.pgerror or str(e)}")


def handle_remove(conn, key, form):
    sailor = (form.getfirst("sailor") or "").strip()
    if not sailor:
        return ("err", "Missing sailor to de-authorise.")

    responsible_row = fetch_responsible(conn, key)
    if responsible_row and responsible_row[0] == sailor:
        return ("err", "You cannot de-authorise the responsible sailor for the reservation.")

    # Keep at least 1 authorised sailor (app-level rule)
    if count_authorised(conn, key) <= 1:
        return ("err", "You cannot remove the last authorised sailor for a reservation.")

    start_date, end_date, country, cni = key

    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("""
                    DELETE FROM authorised
                    WHERE start_date = %s
                      AND end_date = %s
                      AND boat_country = %s
                      AND cni = %s
                      AND sailor = %s;
                """, (start_date, end_date, country, cni, sailor))
                if cur.rowcount == 0:
                    return ("warn", "No such authorisation found.")
        return ("ok", f"De-authorised {sailor}.")
    except psycopg2.Error as e:
        return ("err", f"Database error while de-authorising: {e.pgerror or str(e)}")


def main():
    form = cgi.FieldStorage()
    action = (form.getfirst("action") or "").strip().lower()

    # Reservation selection via GET or POST field
    rkey = (form.getfirst("rkey") or "").strip()
    key = parse_rkey(rkey)

    msgs = []

    print_header("Authorisations")

    try:
        with db.connect() as conn:
            reservations = fetch_reservations(conn)

            if os.environ.get("REQUEST_METHOD", "GET").upper() == "POST":
                if not key:
                    msgs.append(("err", "Select a reservation first."))
                else:
                    if action == "add":
                        msgs.append(handle_add(conn, key, form))
                    elif action == "remove":
                        msgs.append(handle_remove(conn, key, form))
                    elif action:
                        msgs.append(("err", f"Unknown action: {action}"))

            # Refresh view data after any action
            if key:
                responsible_row = fetch_responsible(conn, key)
                authorised_rows = fetch_authorised(conn, key)
                candidate_sailors = fetch_candidate_sailors(conn, key)
            else:
                responsible_row = None
                authorised_rows = []
                candidate_sailors = []

    except Exception as e:
        print(message("err", f"Server/connection error: {str(e)}"))
        print_footer()
        return

    for kind, txt in msgs:
        print(message(kind, txt))

    # Reservation selector (GET)
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Select reservation</h3>")

    if not reservations:
        print(message("warn", "No reservations found. Create one in Reservations first."))
        print("</div>")
        print_footer()
        return

    options = []
    for start_date, end_date, country, cni, boat_name, resp_email, fn, sn in reservations:
        value = f"{start_date}||{end_date}||{country}||{cni}"
        label = f"{start_date} → {end_date} | {boat_name} ({country},{cni}) | responsible: {fn} {sn}"
        options.append((value, label))

    selected_value = rkey if key else options[0][0]

    print('<form method="get" action="authorised.cgi">')
    print(form_row("Reservation", select("rkey", options, selected=selected_value)))
    print('<div class="row"><label></label><button type="submit">Load</button></div>')
    print("</form>")
    print("</div>")

    # If no key provided, default to first reservation for display convenience
    if not key:
        key = parse_rkey(options[0][0])
        rkey = options[0][0]
        # We already fetched authorised_rows etc only if key existed above,
        # so in this case we'd need the user to click Load.
        print(message("warn", "Pick a reservation and click Load to manage its authorised sailors."))
        print_footer()
        return

    # Reservation info
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Reservation details</h3>")
    if responsible_row:
        resp_email, fn, sn = responsible_row
        print(f"<div><b>Responsible:</b> {h(fn)} {h(sn)} &lt;{h(resp_email)}&gt;</div>")
    else:
        print(message("err", "Reservation not found (maybe deleted)."))
        print("</div>")
        print_footer()
        return
    print("</div>")

    # Add authorisation
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Authorise a sailor</h3>")

    if not candidate_sailors:
        print(message("warn", "All sailors are already authorised for this reservation (or no sailors exist)."))
    else:
        cand_opts = [(email, f"{fn} {sn} <{email}>") for (email, fn, sn) in candidate_sailors]
        print('<form method="post" action="authorised.cgi">')
        print('<input type="hidden" name="action" value="add">')
        print(f'<input type="hidden" name="rkey" value="{h(rkey)}">')
        print(form_row("Sailor", select("sailor", cand_opts)))
        print('<div class="row"><label></label><button type="submit">Authorise</button></div>')
        print("</form>")

    print("</div>")

    # List and remove authorisation
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Authorised sailors</h3>")

    print("<table>")
    print("<thead><tr><th>Email</th><th>Name</th><th>Type</th><th>Actions</th></tr></thead>")
    print("<tbody>")

    if not authorised_rows:
        print('<tr><td colspan="4"><em>No rows</em></td></tr>')
    else:
        resp_email = responsible_row[0]
        for sailor_email, fn, sn, stype in authorised_rows:
            print("<tr>")
            print(f"<td>{h(sailor_email)}</td>")
            print(f"<td>{h(fn)} {h(sn)}</td>")
            print(f"<td>{h(stype)}</td>")
            print("<td>")

            if sailor_email == resp_email:
                print("<em>responsible</em>")
            else:
                print(
                    '<form method="post" action="authorised.cgi" style="margin:0;">'
                    '<input type="hidden" name="action" value="remove">'
                    f'<input type="hidden" name="rkey" value="{h(rkey)}">'
                    f'<input type="hidden" name="sailor" value="{h(sailor_email)}">'
                    '<button type="submit" onclick="return confirm(\'De-authorise this sailor?\')">De-authorise</button>'
                    "</form>"
                )

            print("</td>")
            print("</tr>")

    print("</tbody></table>")
    print("</div>")

    print_footer()


if __name__ == "__main__":
    main()
