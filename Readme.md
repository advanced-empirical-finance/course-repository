# The course repository for Advanced Empirical Finance 2026

This repo initializes the folder structure for the course *Advanced Empirical Finance: Topics and Data Science* so that you can start working immediately. We will work with R *and* Python to write code in this course. We will use Quarto, an open-source technical publishing system, to create beautiful articles, slides, blogs, and more to communicate our results. The next few installation steps ensure you have a running version of all the required software.

## Technical prerequisites

1.  Install [R (Version > 4.5.0)](https://cran.r-project.org/)
2.  Install [Python (Version > 3.10.0)](https://www.python.org/downloads/)
3.  Install [Positron (latest Version)](https://positron.posit.co/start.html)
4.  (Optional) Install the newest version of [Quarto](https://quarto.org/docs/download/). (Quarto comes prebundled with Positron, so you will have access to quarto once you followed the previous step)
5.  Register a [free GitHub account](https://happygitwithr.com/github-acct)
6.  Install [Git] (https://git-scm.com/install/)
7.  Configure Git in Positron:
     - In Positron and open the source control view (`Ctrl+Shift+G)`
     - If Git is not installed, the Source Control view will show instructions on how to install it.
     - Once Git is up and running you can clone the course-repository by opening the source control view (`Ctrl+Shift+G)` and pressing `Clone Repository` 





and [configure Git](https://happygitwithr.com/hello-git) before proceeding.

8.  Open the terminal in RStudio. The terminal is in the tab next to the R console pane in RStudio. Install/Update `TinyTeX`, a lightweight, cross-platform, portable, and easy-to-maintain LaTeX distribution by typing the command
  
          quarto install tool tinytex

9.  Clone the [course environment repository](https://github.com/advanced-empirical-finance/course_environment_AEF) by opening RStudio, clicking `File/New Project,` and selecting `Version Control`. Then, click `Git` and provide the repository address <https://github.com/advanced-empirical-finance/course_environment_AEF.git>. RStudio will then automatically open the project in the new environment.

10.  In the console of RStudio, install the `reticulate` R package. Proceed with `Y` when asked if you want to install the packages. Use the package to install Python

             install.packages("reticulate")                               
             reticulate::install_python(version = "3.10.11", force = TRUE)

11.  Tell `renv` to use Python:
  
        renv::use_python("PATH")

    -   `"PATH"` on Mac: `"~/.pyenv/versions/3.10.11/bin/python"`.
    -   `"PATH"` on Windows: `"C:/Users/<User>/AppData/Local/r-reticulate/r-reticulate/pyenv/pyenv-win/versions/3.10.11/python.exe"` where `<User>` is your user name.

11.  Tell `renv` to install all other required packages. Confirm with `Y` when asked if you want to proceed:

         renv::restore()

Now, you are ready to execute all code found in this repository and every code chunk from this course, including every chapter of the [tidy-finance.org platform](www.tidy-finance.org). Whenever you install a new package (e.g., `tidymodels`), do as you would typically do 

    install.packages("tidymodels") 
    
At the end of the session, you update your package management system ion by running 

    renv::snapshot()
    
The same applies if you update or install Python packages (you can do this from the Rstudio Terminal), for example by calling

    pip install yfinance

To collaborate with peers, you can share the `renv.lock` and `requirements.txt` files. They only have to run 

    renv::init()
  
to replicate your exact package environment.

## Further content of the repository

-   You find a (currently empty) folder, `data`. All data required to solve the exercise and assignments in this course is available in the files `tidy_finance_r.sqlite` and `tidy_finance_python.sqlite` on Absalon. You can download the files and include them in the data folder. That way, we have an identical folder structure, so you can run every code chunk from my slides without changing paths. It is **not** allowed to share the `.sqlite` files publicly; thus, neither you nor I are allowed to push the file to a public repo.
-   The folder `mandatory_assignments` contains the files `MA_R_template.qmd` and `MA_python_template.qmd`, which you can use to understand the inner workings of `quarto` files. The file automatically generates .pdf documents, which comply with the formatting standards of this course.
-   The folder `lecture_slides` contains all lecture slides and the corresponding `.qmd` files I used to render the slides.

I will commit new changes regularly to the repository but alert you via 'Absalon' if any major change took place. To keep the repository up-to-date, you can click on the `Git` panel on the `Environment, History, Connections, Git, Tutorial` pane (upper-right side of your RStudio interface). Then, click on the `Pull` button to immediately update the local repository.
