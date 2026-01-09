#!/usr/bin/python3
# web/sailors.cgi

import cgi
import os
import psycopg2

import db
from ui import print_header, print_footer, h, message, text_input, select, form_row


def fetch_sailors(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT sa.email,
                   sa.firstname,
                   sa.surname,
                   CASE
                     WHEN j.email IS NOT NULL THEN 'Junior'
                     WHEN s.email IS NOT NULL THEN 'Senior'
                     ELSE '—'
                   END AS sailor_type
            FROM sailor sa
            LEFT JOIN junior j ON j.email = sa.email
            LEFT JOIN senior s ON s.email = sa.email
            ORDER BY sa.surname, sa.firstname, sa.email;
        """)
        return cur.fetchall()


def handle_create(conn, form):
    email = (form.getfirst("email") or "").strip()
    firstname = (form.getfirst("firstname") or "").strip()
    surname = (form.getfirst("surname") or "").strip()
    stype = (form.getfirst("stype") or "").strip().lower()  # "junior" or "senior"

    if not email or not firstname or not surname:
        return ("err", "Missing fields: email, firstname, and surname are required.")

    if stype not in ("junior", "senior"):
        return ("err", "Invalid sailor type. Choose Junior or Senior.")

    try:
        with conn:  # transaction
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO sailor(email, firstname, surname) VALUES (%s, %s, %s);",
                    (email, firstname, surname),
                )
                if stype == "junior":
                    cur.execute("INSERT INTO junior(email) VALUES (%s);", (email,))
                else:
                    cur.execute("INSERT INTO senior(email) VALUES (%s);", (email,))
        return ("ok", f"Sailor {email} created as {stype.capitalize()}.")
    except psycopg2.Error as e:
        # Rollback happens automatically because of "with conn:" on exception.
        return ("err", f"Database error while creating sailor: {e.pgerror or str(e)}")


def handle_delete(conn, form):
    email = (form.getfirst("email") or "").strip()
    if not email:
        return ("err", "Missing email to delete.")

    try:
        with conn:  # transaction
            with conn.cursor() as cur:
                # subtype tables first (FKs depend on sailor)
                cur.execute("DELETE FROM junior WHERE email = %s;", (email,))
                cur.execute("DELETE FROM senior WHERE email = %s;", (email,))
                cur.execute("DELETE FROM sailor WHERE email = %s;", (email,))
                if cur.rowcount == 0:
                    # rowcount reflects last statement (DELETE sailor)
                    return ("warn", f"No sailor found with email {email}.")
        return ("ok", f"Sailor {email} removed.")
    except psycopg2.Error as e:
        return ("err", f"Database error while deleting sailor: {e.pgerror or str(e)}")


def main():
    form = cgi.FieldStorage()
    action = (form.getfirst("action") or "").strip().lower()

    msgs = []

    print_header("Sailors")

    try:
        with db.connect() as conn:
            # Handle POST actions
            if os.environ.get("REQUEST_METHOD", "GET").upper() == "POST":
                if action == "create":
                    msgs.append(handle_create(conn, form))
                elif action == "delete":
                    msgs.append(handle_delete(conn, form))
                elif action:
                    msgs.append(("err", f"Unknown action: {action}"))

            # Show list after action
            sailors = fetch_sailors(conn)

    except Exception as e:
        # Connection-level or unexpected error
        print(message("err", f"Server/connection error: {str(e)}"))
        print_footer()
        return

    # Messages
    for kind, txt in msgs:
        print(message(kind, txt))

    # Create form
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Create sailor</h3>")
    print('<form method="post" action="sailors.cgi">')
    print('<input type="hidden" name="action" value="create">')

    print(form_row("Email", text_input("email", placeholder="email@example.com")))
    print(form_row("First name", text_input("firstname", placeholder="First Name")))
    print(form_row("Surname", text_input("surname", placeholder="Surname")))
    print(form_row("Type", select("stype", [("junior", "Junior"), ("senior", "Senior")], selected="senior")))

    print('<div class="row"><label></label><button type="submit">Create</button></div>')
    print("</form>")
    print("</div>")

    # List table
    print('<div class="card">')
    print("<h3 style='margin-top:0;'>Sailors list</h3>")

    print("<table>")
    print("<thead><tr>"
          "<th>Email</th><th>First name</th><th>Surname</th><th>Type</th><th>Actions</th>"
          "</tr></thead>")
    print("<tbody>")

    if not sailors:
        print('<tr><td colspan="5"><em>No rows</em></td></tr>')
    else:
        for email, firstname, surname, stype in sailors:
            print("<tr>")
            print(f"<td>{h(email)}</td>")
            print(f"<td>{h(firstname)}</td>")
            print(f"<td>{h(surname)}</td>")
            print(f"<td>{h(stype)}</td>")
            print("<td>")
            print('<form method="post" action="sailors.cgi" style="margin:0;">'
                  '<input type="hidden" name="action" value="delete">'
                  f'<input type="hidden" name="email" value="{h(email)}">'
                  '<button type="submit" onclick="return confirm(\'Delete this sailor?\')">Delete</button>'
                  "</form>")
            print("</td>")
            print("</tr>")

    print("</tbody></table>")
    print("</div>")

    print_footer()


if __name__ == "__main__":
    main()
