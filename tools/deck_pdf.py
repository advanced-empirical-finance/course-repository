"""PDF versions of rendered reveal.js decks, for printing and annotating.

Every deck exists as HTML (the slides, with their interactive parts) and as
PDF (a static copy, one page per slide). Render the deck first, then, from
the repository root:

    uv run --with playwright python tools/deck_pdf.py lecture-slides/aef-1-introduction.html

Several decks at once: pass several HTML files. The PDF lands next to each
HTML file. The script uses a browser that is already installed (Chromium,
Chrome or Edge), so Playwright needs no browser download. Code in tabbed
chunks shows the first tab (R) in the PDF.
"""

import pathlib
import sys

from playwright.sync_api import sync_playwright

# Installed browsers, tried in this order
BROWSERS = [
    {"executable_path": "/usr/bin/chromium"},
    {"channel": "chrome"},
    {"channel": "msedge"},
    {},
]


def launch(playwright):
    for options in BROWSERS:
        path = options.get("executable_path")
        if path and not pathlib.Path(path).exists():
            continue
        try:
            return playwright.chromium.launch(**options)
        except Exception:
            continue
    raise SystemExit("No Chromium, Chrome or Edge found. Install one of them, then run the script again.")


def main(files):
    if not files:
        raise SystemExit(__doc__)
    with sync_playwright() as playwright:
        browser = launch(playwright)
        page = browser.new_page()
        for name in files:
            html = pathlib.Path(name).resolve()
            pdf = html.with_suffix(".pdf")
            # reveal.js lays out every slide as one printable page in print-pdf mode
            page.goto(html.as_uri() + "?print-pdf", wait_until="load")
            page.wait_for_function("() => window.Reveal && window.Reveal.isReady()")
            page.evaluate("() => document.fonts.ready")
            page.evaluate("() => window.MathJax && MathJax.startup ? MathJax.startup.promise : null")
            page.wait_for_timeout(2000)
            page.pdf(path=str(pdf), prefer_css_page_size=True, print_background=True)
            pages = page.evaluate("() => document.querySelectorAll('.pdf-page').length")
            print(f"{pdf.name}: {pages} pages")
        browser.close()


if __name__ == "__main__":
    main(sys.argv[1:])
