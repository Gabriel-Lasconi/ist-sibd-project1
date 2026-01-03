#!/usr/bin/python3
# web/reservations.cgi

import cgi
import os
import psycopg2

import db
from ui import (
    print_header, print_footer, h, message,
    form_row, date_input, select
)


def fetch_boats(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT country, cni, name
            FROM boat
            ORDER BY country, cni;
        """)
        return cur.fetchall()


def fetch_seniors(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT se.email, sa.firstname, sa.surname
            FROM senior se
            JOIN sailor sa ON sa.email = se.email
            ORDER BY sa.surname, sa.firstname, se.email;
        """)
        return cur.fetchall()


def fetch_reservations(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT r.start_date,
                   r.end_date,
                   r.country,
                   r.cni,
                   b.name AS boat_name,
                   r.responsible,
                   (sa.firstname || ' ' || sa.surname) AS responsible_name
            FROM reservation r
            JOIN boat b
              ON b.country = r.country AND b.cni = r.cni
            JOIN sailor sa
              ON sa.email = r.responsible
            ORDER BY r.start_date DESC, r.end_date DESC, r.country, r.cni;
        """)
        return cur.fetchall()


def handle_create(conn, form):
    start_date = (form.getfirst("start_date") or "").strip()
    end_date = (form.getfirst("end_date") or "").strip()
    boat_key = (form.getfirst("boat_key") or "").strip()      # "country||cni"
    responsible = (form.getfirst("responsible") or "").strip()

    if not start_date or not end_date or not boat_key or not responsible:
        return ("err", "Missing fields: start_date, end_date, boat, responsible are required.")

    if "||" not in boat_key:
        return ("err", "Invalid boat selection.")

    country, cni = boat_key.split("||", 1)

    # Simple date sanity check (strings are YYYY-MM-DD in HTML date input)
    if start_date > end_date:
        return ("err", "Invalid interval: start_date must be <= end_date.")

    try:
        with conn:  # transaction (commit/rollback)
            with conn.cursor() as cur:
                # Ensure date_interval exists
                cur.execute("""
                    INSERT INTO date_interval(start_date, end_date)
                    VALUES (%s, %s)
                    ON CONFLICT (start_date, end_date) DO NOTHING;
                """, (start_date, end_date))

                # Create reservation
                cur.execute("""
                    INSERT INTO reservation(start_date, end_date, country, cni, responsible)
                    VALUES (%s, %s, %s, %s, %s);
                """, (start_date, end_date, country, cni, responsible))

                # Ensure at least one authorised sailor (the responsible)
                cur.execute("""
                    INSERT INTO authorised(start_date, end_date, boat_country, cni, sailor)
                    VALUES (%s, %s, %s, %s, %s);
                """, (start_date, end_date, country, cni, responsible))

        return ("ok", "Reservation created (and responsible sailor authorised).")

    except psycopg2.Error as e:
        return ("err", f"Database error while creating reservation: {e.pgerror or str(e)}")


def handle_delete(conn, form):
    start_date = (form.getfirst("start_date") or "").strip()
    end_date = (form.getfirst("end_date") or "").strip()
    country = (form.getfirst("country") or "").strip()
    cni = (form.getfirst("cni") or "").strip()

    if not start_date or not end_date or not country or not cni:
        return ("err", "Missing reservation key fields for delete.")

    try:
        with conn:  # transaction
            with conn.cursor() as cur:
                # Delete dependent rows first (we are not using DELETE CASCADE)
                cur.execute("""
                    DELETE FROM trip
                    WHERE reservation_start_date = %s
                      AND reservation_end_date   = %s
                      AND boat_country           = %s
                      AND cni                    = %s;
                """, (start_date, end_date, country, cni))

                cur.execute("""
                    DELETE FROM authorised
                    WHERE start_date    = %s
                      AND end_date      = %s
                      AND boat_country  = %s
                      AND cni           = %s;
                """, (start_date, end_date, country, cni))

                cur.execute("""
                    DELETE FROM reservation
                    WHERE start_date = %s
                      AND end_date   = %s
                      AND country    = %s
                      AND cni        = %s;
                """, (start_date, end_date, country, cni))

                if cur.rowcount == 0:
                    return ("warn", "No matching reservation found.")

        return ("ok", "Reservation removed (plus related trips/authorisations).")

    except psycopg2.Error as e:
        return ("err", f"Database error while deleting reservation: {e.pgerror or str(e)}")


def main():
    form = cgi.FieldStorage()
    action = (form.getfirst("action") or "").strip().lower()

    msgs = []

    print_header("Reservations")

    try:
        with db.connect() as conn:
            # Handle POST
            if os.environ.get("REQUEST_METHOD", "GET").upper() == "POST":
                if action == "create":
                    msgs.append(handle_create(conn, form))
                elif action == "delete":
                    msgs.append(handle_delete(conn, form))
                elif action:
                    msgs.append(("err", f"Unknown action: {action}"))

            # Refresh data
            boats = fetch_boats(conn)
            seniors = fetch_seniors(conn)
            reservations = fetch_reservations(conn)

    except Exception as e:
        print(message("err", f"Server/connection error: {str(e)}"))
        print_footer()
        return

    for kind, txt in msgs:
        print(message(kind, txt))

    # Create form
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Create reservation</h3>")
    print('<form method="post" action="reservations.cgi">')
    print('<input type="hidden" name="action" value="create">')

    boat_options = []
    for country, cni, boat_name in boats:
        value = f"{country}||{cni}"
        label = f"{boat_name} ({country}, {cni})"
        boat_options.append((value, label))

    senior_options = []
    for email, firstname, surname in seniors:
        senior_options.append((email, f"{firstname} {surname} <{email}>"))

    if not boat_options:
        print(message("warn", "No boats found. Populate BOAT first to create reservations."))
    if not senior_options:
        print(message("warn", "No seniors found. Create a Senior sailor first (responsible must be Senior)."))

    print(form_row("Start date", date_input("start_date")))
    print(form_row("End date", date_input("end_date")))
    print(form_row("Boat", select("boat_key", boat_options) if boat_options else "<em>No boats</em>"))
    print(form_row("Responsible (Senior)", select("responsible", senior_options) if senior_options else "<em>No seniors</em>"))

    disabled = " disabled" if (not boat_options or not senior_options) else ""
    print(f'<div class="row"><label></label><button type="submit"{disabled}>Create</button></div>')
    print("</form>")
    print("</div>")

    # List table
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Reservations list</h3>")

    print("<table>")
    print("<thead><tr>"
          "<th>Start</th><th>End</th><th>Boat</th><th>Country</th><th>CNI</th><th>Responsible</th><th>Actions</th>"
          "</tr></thead>")
    print("<tbody>")

    if not reservations:
        print('<tr><td colspan="7"><em>No rows</em></td></tr>')
    else:
        for start_date, end_date, country, cni, boat_name, responsible, resp_name in reservations:
            print("<tr>")
            print(f"<td>{h(start_date)}</td>")
            print(f"<td>{h(end_date)}</td>")
            print(f"<td>{h(boat_name)}</td>")
            print(f"<td>{h(country)}</td>")
            print(f"<td>{h(cni)}</td>")
            print(f"<td>{h(resp_name)} &lt;{h(responsible)}&gt;</td>")
            print("<td>")
            print(
                '<form method="post" action="reservations.cgi" style="margin:0;">'
                '<input type="hidden" name="action" value="delete">'
                f'<input type="hidden" name="start_date" value="{h(start_date)}">'
                f'<input type="hidden" name="end_date" value="{h(end_date)}">'
                f'<input type="hidden" name="country" value="{h(country)}">'
                f'<input type="hidden" name="cni" value="{h(cni)}">'
                '<button type="submit" onclick="return confirm(\'Delete this reservation (and its trips/authorisations)?\')">Delete</button>'
                "</form>"
            )
            print("</td>")
            print("</tr>")

    print("</tbody></table>")
    print("</div>")

    print_footer()


if __name__ == "__main__":
    main()
