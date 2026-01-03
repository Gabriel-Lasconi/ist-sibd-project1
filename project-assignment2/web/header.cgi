#!/usr/bin/python3
# web/header.cgi

from ui import print_header, print_footer

print_header("Boat Management System Web Prototype")

print("""
<div class="card">
  <h3 style="margin-top:0;">What this prototype does</h3>
  <ul>
    <li><b>Sailors</b>: list, create, remove (junior/senior)</li>
    <li><b>Reservations</b>: list, create, remove</li>
    <li><b>Authorisations</b>: authorise / de-authorise sailors for a reservation</li>
    <li><b>Trips</b>: list, register, remove and show available locations</li>
  </ul>
  <p>
    All DB writes use parameterized SQL to avoid injection, and multi-step operations use transactions.
  </p>
</div>

<div class="card">
  <h3 style="margin-top:0;">Go to</h3>
  <ul>
    <li><a href="sailors.cgi">Sailors</a></li>
    <li><a href="reservations.cgi">Reservations</a></li>
    <li><a href="authorised.cgi">Authorisations</a></li>
    <li><a href="trips.cgi">Trips</a></li>
  </ul>
</div>
""")

print_footer()
