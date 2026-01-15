# The course repository for Advanced Empirical Finance 2026

This repo initializes the folder structure for the course *Advanced Empirical Finance: Topics and Data Science* so that you can start working immediately. We will work with R *and* Python to write code in this course. We will use Quarto, an open-source technical publishing system, to create beautiful articles, slides, blogs, and more to communicate our results. The next few installation steps ensure you have a running version of all the required software.

## Technical prerequisites

1.  Install [R (Version \> 4.5.0)](https://cran.r-project.org/)

2.  Install [Python (Version \> 3.10.0)](https://www.python.org/downloads/)

3.  Install [Positron (latest Version)](https://positron.posit.co/start.html)
4.  Register a [free GitHub account](https://happygitwithr.com/github-acct)
5.  Install [Git] (https://git-scm.com/install/)
6.  Configure Git in Positron:
     - In Positron and open the source control view (`Ctrl+Shift+G)`
     - If Git is not installed, the Source Control view will show instructions on how to install it.
     - Once Git is up and running you can clone the course-repository by opening the source control view (`Ctrl+Shift+G)` and pressing `Clone Repository`. Then, you provide the course repository url [https://github.com/advanced-empirical-finance/course-repository.git](https://github.com/advanced-empirical-finance/course-repository.git) and choose a local folder where the repository should be stored. 

7. Open the cloned repository in Positron by navigating to `File` -> `Open Project` and selecting the folder where you cloned the repository.
8. To install *all* required R packages for the course, open the Terminal (`Ctrl+``) in Positron and install the `renv` package by typing the commands

        install.packages("renv")
        renv::restore()

You can install new packages, e.g., by calling `install.packages("tidymodels")´. To collaborate with your peers, just run `renv::snapshot()` to keep track of all the packages you use, and share the `renv.lock` file. Your colleagues only have to run `renv::restore()` to replicate your exact R package environment.

## Optional prerequisites

1. Install the newest version of [Quarto](https://quarto.org/docs/download/). (Quarto comes prebundled with Positron, so you will have access to quarto once you followed the previous step)
1. In order to create PDFs you will need to install a recent distribution of LaTeX. I recomment to install `TinyTeX`, a lightweight, cross-platform, portable, and easy-to-maintain LaTeX distribution by typing the command
  
          quarto install tool tinytex

in Positron / Terminal or directly in the console

## Content of the repository

-   You find a (currently empty) folder, `data`, already populated with some non-proprietary files. All proprietary files required to solve the exercise and assignments in this course will be made available via Absalon. I always assume you download the data and store it in the `data` folder of the course repository. You can download the files and include them in the data folder. That way, we have an identical folder structure, so you can run every code chunk from my slides without changing paths. It is **not** allowed to share the proprietary files publicly; thus, neither you nor I are allowed to push these files to a public repo.
-   The folder `mandatory_assignments` contains the files `MA_R_template.qmd` and `MA_python_template.qmd`, which you can use to understand the inner workings of `quarto` files. The file automatically generates .pdf documents, which comply with the formatting standards of this course.
-   The folder `lecture_slides` contains all lecture slides and the corresponding `.qmd` files I used to render the slides.

I will commit new changes regularly to the repository but alert you via 'Absalon' if any major change took place. To keep your local folder up-to-date, click on the `Source control` panel (`Str+Shift+G`). Then, click `.../Pull` to immediately update the local repository.
