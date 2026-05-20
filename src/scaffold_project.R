# scaffold_project.R
# this function scaffolds a new research project with a standard structure for data management plan purposes
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
  # deps
  pkgs <- c("fs", "usethis", "glue", "withr", "later")
  to_install <- pkgs[
    !vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(to_install)) {
    install.packages(to_install)
  }
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
  # README
  if ("README.md" %in% files_root) {
    write_if_new(
      fs::path(root, "README.md"),
      glue::glue("# {name}\n\nProject initialised on {Sys.Date()}.\n\n")
    )
  }

  # .gitignore (designed for R + your structure)
  if (".gitignore" %in% files_root) {
    write_if_new(
      fs::path(root, ".gitignore"),
      paste(
        c(
          "# R / RStudio",
          ".Rproj.user/",
          ".Rhistory",
          ".RData",
          ".Renviron",
          ".env",
          "",
          "# renv",
          "renv/library/",
          "renv/staging/",
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

  # .Rprofile (minimal; customize freely)
  if (".Rprofile" %in% files_root) {
    write_if_new(
      fs::path(root, ".Rprofile"),
      'options(usethis.protocol = "https")  # usethis prefers https remotes\n'
    )
  }

  # README.md in each top-level directory (tests gets its own below)
  for (top in names(dirs)[names(dirs) != "tests"]) {
    write_if_new(
      fs::path(root, top, "README.md"),
      glue::glue("# {top}\n\nDescribe how you use `{top}/`.\n")
    )
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
  # Make 'root' the active usethis project for the duration of the block
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

  # Now usethis knows where to operate
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

      # Store old options and suppress all browser opening
      old_browse <- getOption("usethis.browse")
      old_browser <- getOption("browser")
      options(
        usethis.browse = FALSE,
        browser = function(...) {
          invisible(NULL)
        } # No-op browser function
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
    # Launch the project in a new session
    usethis::proj_activate(root)
    Sys.sleep(2)
    quit(save = "no", runLast = FALSE)
  }
  invisible(root)
}
