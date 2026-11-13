# The course repository for Advanced Empirical Finance

This repo initializes the folder structure for the course *Advanced Empirical Finance: Topics and Data Science* so that you can start working immediately. We will work with R *and* Python to write code in this course. We will use Quarto, an open-source technical publishing system, to create beautiful articles, slides, blogs, and more to communicate our results. Follow the few installation steps in [Exercise 0](https://aef-course.ku.dk/exercises/technical-prerequisites.html) to ensure you have a running version of all the required software.

## Setting up the R and Python packages

R packages are managed with [uvr](https://github.com/nbafrank/uvr) (`uvr.toml`, `uvr.lock`), Python packages with [uv](https://docs.astral.sh/uv/) (`pyproject.toml`, `uv.lock`). Both include `aefsim`, the client for the trading game. You need uvr 0.4.8 or later (`uvr upgrade` updates it). In a terminal, in this folder:

```sh
uvr r install 4.6.1   # once: installs R 4.6.1, the version the course uses
uvr sync              # installs every R package of the course into .uvr/
uv sync               # installs Python and every Python package of the course into .venv/
```

Add a package with `uvr add tidymodels` or `uv add polars`, and commit `uvr.toml`, `uvr.lock`, `pyproject.toml` and `uv.lock`: your teammates then run `uvr sync` and `uv sync` to get exactly the same packages.

To render a Quarto file that uses both languages from a terminal, activate the R environment and run Quarto through uv: `source .uvr/activate` (Windows PowerShell: `. .\.uvr\activate.ps1`), then `uv run quarto render file.qmd`.

## Content of the repository

-   The folder `data` holds the public datasets of the course, as in the [Tidy Finance](https://www.tidy-finance.org) book: the Fama-French three factors, the ten industry portfolios, the macroeconomic predictors of Welch and Goyal (2008), and the consumer price index, monthly from 1960 (`data-raw/public_data.R` made them). The licensed files come from Absalon: store them in the `data` folder, too, under the names given there (`crsp_monthly.parquet` from the first lecture on). That way, we all have an identical folder structure, so you can run every code chunk from my slides without changing paths. It is **not** allowed to share the licensed files publicly; thus, neither you nor I are allowed to push these files to a public repo.
-   The folder `mandatory-assignments` contains the files `MA_R_template.qmd` and `MA_python_template.qmd`, which you can use to understand the inner workings of `quarto` files. The file automatically generates .pdf documents, which comply with the formatting standards of this course.
-   The folder `lecture-slides` contains all lecture slides, as HTML (as shown in the lecture) and as PDF (to print and annotate), and the `.qmd` files I used to render them. `quarto render lecture-slides/<deck>.qmd` makes both; the PDF needs TinyTeX (`quarto install tinytex`).

I will commit new changes regularly to the repository but alert you via 'Absalon' if any major change took place. To keep your local folder up-to-date, click on the `Source control` panel (`Str+Shift+G`). Then, click `.../Pull` to immediately update the local repository.

Working in a team? Each team gets a private copy of this repository on GitHub that stays connected to it, for the course material, the assignments and the trading game. See [Collaboration with Git and GitHub](https://aef-course.ku.dk/additional-material/github-collaboration.html).


