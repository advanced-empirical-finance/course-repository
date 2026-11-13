"""PDF versions of rendered reveal.js decks, for printing and annotating.

Every deck exists as HTML (the slides, with their interactive parts) and as
PDF (a static copy that looks the same, one page per slide). Render the deck
first, then, from the repository root:

    uv run --with playwright python tools/deck_pdf.py lecture-slides/aef-01-introduction.html

Several decks at once: pass several HTML files. The PDF lands next to each
HTML file. The script uses a browser that is already installed (Chromium,
Chrome or Edge), so Playwright needs no browser download. A slide with an
R | Python tabset becomes one page per tab, so the PDF shows both languages.
An embedded page, such as the trading game video, is printed as it first
appears, with a link: a click on it in the PDF opens it in the browser.
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

# Runs before the deck's own scripts. When reveal.js is about to lay out the
# print pages, every slide with a tabset is copied once per tab, and each
# copy keeps only its own tab.
SPLIT_TABSETS = """
(() => {
  function keepTab(slide, k, suffix) {
    for (const tabset of slide.querySelectorAll('.panel-tabset')) {
      tabset.removeAttribute('data-group');
      const items = [...tabset.querySelectorAll(':scope > ul > li')];
      const panes = [...tabset.querySelectorAll(':scope > .tab-content > div')];
      items.forEach((item, i) => { if (i !== k) item.remove(); });
      panes.forEach((pane, i) => { if (i !== k) pane.remove(); });
      for (const pane of tabset.querySelectorAll(':scope > .tab-content > div')) {
        pane.removeAttribute('hidden');
        pane.classList.add('active');
      }
      for (const item of tabset.querySelectorAll(':scope > ul > li')) {
        item.classList.add('active');
        const link = item.querySelector('a');
        if (link) {
          link.setAttribute('aria-selected', 'true');
          link.setAttribute('data-tabby-default', '');
        }
      }
    }
    if (suffix) {
      // Copies need ids of their own, or links and tabs find the original
      for (const el of [slide, ...slide.querySelectorAll('[id]')]) {
        if (el.id) el.id = el.id + suffix;
      }
      for (const link of slide.querySelectorAll('a[href^="#"]')) {
        link.setAttribute('href', link.getAttribute('href') + suffix);
      }
    }
  }
  function splitTabsets() {
    let copies = 0;
    for (const slide of document.querySelectorAll('.reveal .slides section')) {
      const tabsets = slide.querySelectorAll(':scope .panel-tabset');
      if (!tabsets.length || slide.querySelector('section')) continue;
      const tabs = Math.max(...[...tabsets].map(t => t.querySelectorAll(':scope > ul > li').length));
      const original = slide.cloneNode(true);
      let last = slide;
      for (let k = 1; k < tabs; k++) {
        const copy = original.cloneNode(true);
        keepTab(copy, k, '-tab' + k);
        last.after(copy);
        last = copy;
        copies++;
      }
      keepTab(slide, 0, '');
    }
    window.__tabsetCopies = copies;
  }
  let reveal;
  Object.defineProperty(window, 'Reveal', {
    configurable: true,
    get() { return reveal; },
    set(value) {
      reveal = value;
      if (value && value.initialize && !value.__split) {
        const initialize = value.initialize.bind(value);
        value.initialize = (options) => { splitTabsets(); return initialize(options); };
        value.__split = true;
      }
    },
  });
})();
"""


# After reveal.js has laid out the print pages: a link over every embedded
# page (iframe), so that a click on it in the PDF opens it in the browser.
LINK_IFRAMES = """
() => {
  let links = 0;
  for (const frame of document.querySelectorAll('.pdf-page iframe')) {
    const page = frame.closest('.pdf-page');
    const p = page.getBoundingClientRect();
    const f = frame.getBoundingClientRect();
    const link = document.createElement('a');
    link.href = frame.getAttribute('data-src') || frame.src;
    Object.assign(link.style, {
      position: 'absolute', zIndex: 10, left: (f.left - p.left) + 'px', top: (f.top - p.top) + 'px',
      width: f.width + 'px', height: f.height + 'px',
    });
    page.appendChild(link);
    links++;
  }
  return links;
}
"""


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
        page.add_init_script(SPLIT_TABSETS)
        for name in files:
            html = pathlib.Path(name).resolve()
            pdf = html.with_suffix(".pdf")
            # reveal.js lays out every slide as one printable page in print-pdf mode
            page.goto(html.as_uri() + "?print-pdf", wait_until="load")
            page.wait_for_function("() => window.Reveal && window.Reveal.isReady()")
            page.evaluate("() => document.fonts.ready")
            page.evaluate("() => window.MathJax && MathJax.startup ? MathJax.startup.promise : null")
            page.wait_for_timeout(2000)
            page.evaluate(LINK_IFRAMES)
            page.pdf(path=str(pdf), prefer_css_page_size=True, print_background=True)
            pages = page.evaluate("() => document.querySelectorAll('.pdf-page').length")
            copies = page.evaluate("() => window.__tabsetCopies || 0")
            print(f"{pdf.name}: {pages} pages, {copies} of them extra tabs")
        browser.close()


if __name__ == "__main__":
    main(sys.argv[1:])
