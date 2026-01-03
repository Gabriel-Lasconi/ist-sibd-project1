# web/ui.py
# A little HTML for CGI scripts.

import html
from typing import Iterable, Sequence, Any, Optional


def h(x: Any) -> str:
    """HTML-escape."""
    return html.escape("" if x is None else str(x), quote=True)


def print_header(title: str, extra_head: str = "") -> None:
    # CGI header
    print("Content-Type: text/html; charset=utf-8")
    print("Cache-Control: no-store")
    print()

    print(f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{h(title)}</title>
  <style>
    body {{ font-family: system-ui, Arial, sans-serif; margin: 24px; max-width: 980px; }}
    header {{ display: flex; align-items: baseline; gap: 16px; }}
    nav a {{ margin-right: 12px; }}
    table {{ border-collapse: collapse; width: 100%; margin: 12px 0 20px; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
    th {{ background: #f6f6f6; }}
    .card {{ border: 1px solid #ddd; border-radius: 10px; padding: 14px; margin: 12px 0; }}
    .msg {{ padding: 10px 12px; border-radius: 10px; margin: 12px 0; }}
    .ok {{ background: #eef9ef; border: 1px solid #bfe7c3; }}
    .err {{ background: #fdeeee; border: 1px solid #f2b6b6; }}
    .warn {{ background: #fff8e6; border: 1px solid #f2d28b; }}
    label {{ display: inline-block; min-width: 160px; margin: 6px 0; }}
    input, select {{ padding: 6px; }}
    button {{ padding: 7px 10px; cursor: pointer; }}
    .row {{ margin: 6px 0; }}
    footer {{ margin-top: 26px; color: #666; font-size: 0.9rem; }}
    code {{ background: #f6f6f6; padding: 2px 5px; border-radius: 6px; }}
  </style>
  {extra_head}
</head>
<body>
<header>
  <h2 style="margin:0;">{h(title)}</h2>
  <nav>
    <a href="header.cgi">Home</a>
    <a href="sailors.cgi">Sailors</a>
    <a href="reservations.cgi">Reservations</a>
    <a href="authorised.cgi">Authorisations</a>
    <a href="trips.cgi">Trips</a>
  </nav>
</header>
<hr>
""")


def print_footer() -> None:
    print("""
<footer>
  <hr>
  <div>Boating Management System - web app prototype</div>
</footer>
</body>
</html>
""")


def message(kind: str, text: str) -> str:
    """
    kind: 'ok' | 'err' | 'warn'
    Returns HTML string.
    """
    kind_class = kind if kind in ("ok", "err", "warn") else "warn"
    return f'<div class="msg {kind_class}">{h(text)}</div>'


def render_table(headers: Sequence[str], rows: Iterable[Sequence[Any]]) -> str:
    thead = "".join(f"<th>{h(col)}</th>" for col in headers)
    tbody = []
    for r in rows:
        tds = "".join(f"<td>{h(v)}</td>" for v in r)
        tbody.append(f"<tr>{tds}</tr>")
    return f"""
<table>
  <thead><tr>{thead}</tr></thead>
  <tbody>
    {''.join(tbody) if tbody else '<tr><td colspan="' + str(len(headers)) + '"><em>No rows</em></td></tr>'}
  </tbody>
</table>
"""


def form_row(label: str, control_html: str) -> str:
    return f'<div class="row"><label>{h(label)}</label>{control_html}</div>'


def text_input(name: str, value: str = "", placeholder: str = "", size: int = 30) -> str:
    return f'<input type="text" name="{h(name)}" value="{h(value)}" placeholder="{h(placeholder)}" size="{size}">'


def date_input(name: str, value: str = "") -> str:
    return f'<input type="date" name="{h(name)}" value="{h(value)}">'


def number_input(name: str, value: str = "", step: str = "1") -> str:
    return f'<input type="number" name="{h(name)}" value="{h(value)}" step="{h(step)}">'


def select(name: str, options: Sequence[tuple[str, str]], selected: Optional[str] = None) -> str:
    """
    options: [(value, label), ...]
    """
    opts = []
    for v, lbl in options:
        sel = ' selected' if selected is not None and v == selected else ''
        opts.append(f'<option value="{h(v)}"{sel}>{h(lbl)}</option>')
    return f'<select name="{h(name)}">{"".join(opts)}</select>'
