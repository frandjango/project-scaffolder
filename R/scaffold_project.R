#' Scaffold a new R research project
#'
#' Creates a new R project with a standard directory structure, Git
#' initialisation, optional renv setup, and optional remote (GitHub or
#' arbitrary URL).
#'
#' @param name Character. Name of the new project (used as the folder name).
#' @param path Character. Parent directory in which to create the project.
#'   Defaults to the current working directory.
#' @param init_git Logical. Initialise a Git repository? Default `TRUE`.
#' @param default_branch Character. Name of the default Git branch. Default
#'   `"main"`.
#' @param init_renv Logical. Initialise renv (bare)? Default `TRUE`.
#' @param create_remote Character. One of `"none"`, `"github"`, or `"url"`.
#'   Default `"none"`.
#' @param remote_url Character. Remote URL when `create_remote = "url"`.
#' @param github_org Character. GitHub organisation to create the repo under
#'   (NULL = personal account).
#' @param github_private Logical. Create a private GitHub repo? Default `TRUE`.
#' @param template_yaml Character. Path to a YAML file that overrides the
#'   default directory structure.
#' @param open Logical. Open the new project in RStudio? Default
#'   `interactive()`.
#'
#' @return Invisibly returns the absolute path to the created project.
#' @export
scaffold_project <- function(
  name,
  path = ".",
  init_git = TRUE,
  default_branch = "main",
  init_renv = TRUE,
  create_remote = c("none", "github", "url"),
  remote_url = NULL,
  github_org = NULL,
  github_private = TRUE,
  template_yaml = NULL,
  open = interactive()
) {
  if (!is.null(template_yaml)) {
    if (!requireNamespace("yaml", quietly = TRUE)) install.packages("yaml")
  }
  if (init_renv && !requireNamespace("renv", quietly = TRUE)) {
    install.packages("renv")
  }

  create_remote <- match.arg(create_remote)

  root <- fs::path_abs(fs::path(path, name))
  if (fs::dir_exists(root)) {
    stop("Target dir already exists: ", root)
  }
  fs::dir_create(root)

  # ---------- structure (defaults) ----------
  dirs <- list(
    data = c("raw", "processed", "interim", "sim-input"),
    docs = c(),
    notebooks = character(),
    reports = c("figures", "tables"),
    src = character(),
    lib = character(),
    literature = character(),
    tests = c("testthat")
  )
  files_root <- c("README.md", ".gitignore", ".Rprofile")
  # allow YAML override
  if (!is.null(template_yaml)) {
    tpl <- yaml::read_yaml(template_yaml)
    if (!is.null(tpl$dirs)) {
      dirs <- tpl$dirs
    }
    if (!is.null(tpl$files_root)) files_root <- tpl$files_root
  }

  # make top-level and subdirs
  for (top in names(dirs)) {
    fs::dir_create(fs::path(root, top))
    if (length(dirs[[top]]) > 0) {
      fs::dir_create(fs::path(root, top, dirs[[top]]))
    }
  }

  # small helper: write file only if it doesn't exist
  write_if_new <- function(path, text) {
    if (!fs::file_exists(path)) writeLines(text, path, useBytes = TRUE)
  }

  # ---------- root files ----------
  if ("README.md" %in% files_root) {
    write_if_new(
      fs::path(root, "README.md"),
      glue::glue("# {name}\n\nProject initialised on {Sys.Date()}.\n\n")
    )
  }

  if (".gitignore" %in% files_root) {
    write_if_new(
      fs::path(root, ".gitignore"),
      paste(
        c(
          "# Windows / shell artefacts",
          "bash.exe.stackdump",
          "",
          "# R / RStudio",
          ".Rproj.user/",
          ".Rhistory",
          ".RData",
          ".Rprofile",
          ".Renviron",
          ".env",
          "",
          "# renv (local library; lock file is tracked separately)",
          "renv/",
          "",
          "# Generated outputs / caches",
          "cache/",
          "graphs/",
          "logs/",
          "reports/figures/",
          "reports/tables/",
          "",
          "# Heavy or ephemeral data (keep structure, not contents)",
          "literature/",
          "data/raw/",
          "data/interim/",
          "",
          "# Allow small docs that explain folders:",
          "!data/README.md",
          "!notebooks/README.md",
          "!reports/README.md",
          "!src/README.md",
          "!lib/README.md"
        ),
        collapse = "\n"
      )
    )
  }

  if (".Rprofile" %in% files_root) {
    write_if_new(
      fs::path(root, ".Rprofile"),
      'options(usethis.protocol = "https")  # usethis prefers https remotes\n'
    )
  }

  # README.md in each top-level directory (tests gets its own below)
  dir_readmes <- list(
    data = paste(c(
      "# data",
      "",
      "Project data organised by processing stage.",
      "",
      "| Subfolder | Purpose |",
      "|-----------|---------|",
      "| `raw/`       | Original, unmodified source files. **Never edit these.** (gitignored) |",
      "| `processed/` | Clean, analysis-ready datasets derived from raw. |",
      "| `interim/`   | Intermediate outputs between pipeline steps. (gitignored) |",
      "| `sim-input/` | Inputs for simulation or modelling runs. |",
      "",
      "Add small reference files (lookup tables, metadata) directly here."
    ), collapse = "\n"),
    docs = paste(c(
      "# docs",
      "",
      "Project documentation: design decisions, data dictionaries, meeting notes, onboarding guides.",
      "",
      "Keep documents that help a new collaborator (or future you) understand the project.",
      "Generated reports belong in `reports/` instead."
    ), collapse = "\n"),
    notebooks = paste(c(
      "# notebooks",
      "",
      "Exploratory analysis, prototyping, and literate-programming documents.",
      "",
      "Use `.Rmd` or `.qmd` files here. Name them with a numeric prefix and a short description:",
      "",
      "```",
      "01-eda.qmd",
      "02-feature-engineering.Rmd",
      "03-model-selection.qmd",
      "```",
      "",
      "Notebooks are for exploration — production-ready logic should be moved to `src/`."
    ), collapse = "\n"),
    reports = paste(c(
      "# reports",
      "",
      "Polished outputs for stakeholders or publication.",
      "",
      "| Subfolder | Purpose |",
      "|-----------|---------|",
      "| `figures/` | Charts and plots (gitignored — regenerate from `src/`). |",
      "| `tables/`  | Summary tables (gitignored — regenerate from `src/`). |",
      "",
      "Place final `.qmd` / `.Rmd` report sources directly here."
    ), collapse = "\n"),
    src = paste(c(
      "# src",
      "",
      "R scripts that form the analysis pipeline.",
      "",
      "Suggested naming convention:",
      "",
      "```",
      "01-ingest.R        # load and validate raw data",
      "02-clean.R         # reshape, filter, impute",
      "03-analyse.R       # models, statistics",
      "04-visualise.R     # produce figures saved to reports/figures/",
      "```",
      "",
      "Each script should be runnable in isolation given the outputs of the previous step.",
      "Shared helpers used across multiple scripts belong in `lib/`."
    ), collapse = "\n"),
    lib = paste(c(
      "# lib",
      "",
      "Custom R functions and helpers shared across scripts in `src/`.",
      "",
      "Source individual files at the top of a script:",
      "",
      "```r",
      'source("lib/utils.R")',
      "```",
      "",
      "If helpers grow large enough to warrant their own package, build one with `usethis::create_package()`."
    ), collapse = "\n"),
    literature = paste(c(
      "# literature",
      "",
      "Papers, reports, and reference documents relevant to this project.",
      "",
      "This folder is **gitignored** — PDFs and large files are not committed.",
      "Store a `references.bib` or a plain-text reading list here to track what you have read."
    ), collapse = "\n")
  )

  for (top in names(dirs)[names(dirs) != "tests"]) {
    content <- if (!is.null(dir_readmes[[top]])) {
      dir_readmes[[top]]
    } else {
      glue::glue("# {top}\n\nDescribe how you use `{top}/`.")
    }
    write_if_new(fs::path(root, top, "README.md"), content)
  }

  # descriptive README for tests/
  write_if_new(
    fs::path(root, "tests", "README.md"),
    paste(
      c(
        "# tests",
        "",
        "Unit tests for this project using [testthat](https://testthat.r-lib.org/).",
        "",
        "## Structure",
        "",
        "```",
        "tests/",
        "└── testthat/",
        "    ├── test-<topic>.R   # one file per script or logical group",
        "    └── ...",
        "```",
        "",
        "Each test file in `tests/testthat/` must be prefixed with `test-`.",
        "testthat will ignore any file that does not follow this convention.",
        "",
        "## Running tests",
        "",
        "Run all tests from the project root:",
        "",
        "```r",
        'testthat::test_dir("tests/testthat")',
        "```",
        "",
        "Or source a specific test file directly:",
        "",
        "```r",
        'source("tests/testthat/test-<topic>.R")',
        "```",
        "",
        "## Writing tests",
        "",
        "Each test file groups related assertions using `test_that()` blocks:",
        "",
        "```r",
        "library(testthat)",
        "",
        'test_that("my function returns expected output", {',
        "  result <- my_function(input)",
        '  expect_equal(result, expected)',
        '  expect_true(is.numeric(result))',
        "})",
        "```",
        "",
        "Common expectations: `expect_equal()`, `expect_true()`, `expect_false()`,",
        "`expect_error()`, `expect_warning()`, `expect_length()`, `expect_snapshot()`.",
        "",
        "Name test files to mirror the script they cover, e.g. `src/clean.R` → `tests/testthat/test-clean.R`."
      ),
      collapse = "\n"
    )
  )

  # starter testthat file so test_dir() has something to run immediately
  write_if_new(
    fs::path(root, "tests", "testthat", "test-placeholder.R"),
    paste(
      c(
        'library(testthat)',
        '',
        'test_that("placeholder passes", {',
        '  expect_true(TRUE)',
        '})'
      ),
      collapse = "\n"
    )
  )

  # ---------- .Rproj, Git, renv, remote ----------
  old_proj <- tryCatch(usethis::proj_get(), error = function(e) NULL)
  usethis::proj_set(root, force = TRUE)
  on.exit(
    {
      if (is.null(old_proj)) {
        usethis::proj_set(NULL)
      } else {
        usethis::proj_set(old_proj)
      }
    },
    add = TRUE
  )

  usethis::use_rstudio()

  if (init_git) {
    usethis::use_git(message = glue::glue("{name} initiated"))
    try(usethis::git_default_branch_rename(default_branch), silent = TRUE)
  }

  if (init_renv) {
    renv::init(project = root, bare = TRUE)
  }

  if (init_git && create_remote != "none") {
    if (create_remote == "github") {
      if (!requireNamespace("gh", quietly = TRUE)) {
        install.packages("gh")
      }
      ok <- tryCatch(
        {
          gh::gh_whoami()
          TRUE
        },
        error = function(e) FALSE
      )
      if (!ok) {
        stop(
          "GitHub token missing or expired. Run usethis::create_github_token(),
      then run usethis::edit_r_environ() to add to ~/.Renviron as GITHUB_TOKEN and save,
      then readRenviron('~/.Renviron'),
      then check with gh::gh_whoami() - it should show your username,
      then retry."
        )
      }

      old_browse <- getOption("usethis.browse")
      old_browser <- getOption("browser")
      options(
        usethis.browse = FALSE,
        browser = function(...) invisible(NULL)
      )
      on.exit(
        {
          options(usethis.browse = old_browse)
          options(browser = old_browser)
        },
        add = TRUE
      )

      usethis::use_github(
        private = github_private,
        organisation = github_org,
        protocol = "https"
      )
    } else if (create_remote == "url") {
      if (is.null(remote_url)) {
        stop("Provide remote_url when create_remote = 'url'.")
      }
      withr::with_dir(root, {
        system2("git", c("remote", "add", "origin", remote_url))
        system2("git", c("push", "-u", "origin", default_branch))
      })
    }
  }

  message("✅ Project ready at: ", root)

  if (open) {
    usethis::proj_activate(root)
  }
  invisible(root)
}
