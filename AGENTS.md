# Instructions for AI assistants

This is the course repository of *Advanced Empirical Finance: Topics and Data Science* at the University of Copenhagen, or a team's copy of it. Students write empirical finance reports in Quarto, with R or Python, and hand them in as PDF. The student you work with answers for every line, so explain what you change and why, and keep it simple enough to defend in an exam. The full expectations are in the assignment quality criteria: https://aef-course.ku.dk/additional-material/assignment-quality-criteria.html

## Environment

- R packages are managed with uvr (`uvr.toml`, `uvr.lock`), Python packages with uv (`pyproject.toml`, `uv.lock`). Add packages with `uvr add <pkg>` or `uv add <pkg>`. Never use `install.packages()`, `pip install` or conda.
- Render from a terminal in the repository root: `source .uvr/activate` (Windows PowerShell: `. .\.uvr\activate.ps1`), then `uv run quarto render <file>.qmd`.
- Use only functions and arguments that exist in the installed package versions; check them in the installed help or source when in doubt.

## Code

- R: tidyverse with the native pipe `|>`, tidyfinance, ggplot2, nanoparquet for parquet files. Python: polars (not pandas), tidyfinance, plotnine, great_tables. Do not mix styles within a report.
- Keep the code as simple as the task allows: no classes, configuration objects, logging or wrapper layers for a one-off analysis.
- Put packages in one setup chunk at the top and named constants (sample period, window lengths, seeds) right after them; no unexplained numbers in the code.
- Comments say why a step is there, not what the next line does.
- Set a seed before every random step.
- Use only information available at the time of each decision: lag characteristics, prices and predictors; never use the test period for tuning or variable selection.

## Data

- `data/` holds the public course data as parquet files (`factors_ff3_monthly`, `industries_ff_monthly`, `macro_predictors`, `cpi_monthly`). Read files with relative paths from the repository root, e.g. `data/factors_ff3_monthly.parquet`.
- Licensed files from Absalon, such as `data/crsp_monthly.parquet`, may be read by code, but never print their rows in the chat, never copy them elsewhere, and never commit them. Inspect them through column names, types and summary statistics.
- The trading game token lives in `.Renviron` (R) or `.env` (Python), set with `set_token()`. Never write it into code, output or commits.

## Reports

- Start from `mandatory-assignments/MA_R_template.qmd` or `MA_python_template.qmd`; team work goes into folders such as `assignment-1/`, not into the course's own files (`lecture-slides/`, `mandatory-assignments/`, `data-raw/`).
- Every number in the text comes from inline code, never typed by hand. Figures and tables have captions and `fig-`/`tbl-` labels and are referenced in the text; axes have labels with units.
- Every chunk has a short, meaningful label.
- Cite only references you have checked at the source; never invent papers, page numbers or quotes. Use `references.bib`.
- After a change, render the whole document and check that the numbers in the text still match the tables and figures.

## Git

- Small commits with a message that says what changed and why. Check `git status` before committing: never add `data/` files other than the public ones, `.Renviron` or `.env`.
- Do not rewrite history or force-push.
