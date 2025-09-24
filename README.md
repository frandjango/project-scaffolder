# R Project Scaffolder — Git + `renv` + sensible folders

This repository contains a single function, `scaffold_project()`, that creates a new R project with:

- A clean **directory skeleton** (`data/`, `notebooks/`, `reports/`, `src/`, `lib/`, `literature/`)
- An **.Rproj** file
- **Git** initialized + first commit (`"<project name> initiated"`)
- Optional **remote** (create + push to **GitHub**, or attach any remote URL)
- Optional **`renv`** setup for reproducible, per‑project libraries
- Optional **YAML** override so you can evolve the structure without editing code

---

## Quick start

1. Save your scaffolder function to a file you can source, e.g. `~/R/scaffold_project.R`.
2. In a fresh R session, install dependencies and source the function:

```r
# Core deps
install.packages(c("fs", "usethis", "glue", "withr", "later"))

# Optional:
# - renv (for reproducible per‑project libraries)
# - gh   (for creating GitHub remotes)
# - yaml (only if you use a YAML template override)
install.packages(c("renv", "gh", "yaml"))

source("~/R/scaffold_project.R")
```

Create a local-only project:

```r
scaffold_project("my-new-project", path = "D:/projects")
```

Create and push a **private GitHub** repo (recommended):

```r
# One-time: create + store a GitHub token (free)
# usethis::create_github_token()  # opens GitHub; create a PAT with repo scope
# usethis::edit_r_environ()       # add: GITHUB_TOKEN=ghp_XXXXXXXXXXXXXXXX
# readRenviron("~/.Renviron")     # reload without restart

scaffold_project(
  "my-new-project",
  path = "D:/projects",
  create_remote = "github",
  github_private = TRUE
)
```

Attach an **existing remote** (GitLab/Bitbucket/self-hosted):

```r
scaffold_project(
  "my-new-project",
  path = "D:/projects",
  create_remote = "url",
  remote_url = "https://gitlab.com/you/my-new-project.git"
)
```

---

## What gets created

```
my-new-project/
├─ .git/                 # Git repo (first commit made)
├─ .gitignore
├─ .Rprofile
├─ my-new-project.Rproj
├─ README.md
├─ data/
│  ├─ raw/
│  ├─ preprocessed/
│  ├─ processed/
│  ├─ interim/
│  └─ sim-input/
├─ notebooks/            # analysis notebooks, prototypes
├─ reports/
│  ├─ figures/
│  └─ tables/
├─ src/                  # R scripts, pipelines
├─ lib/                  # your own packages/helpers
└─ literature/
   └─ README.md (stubs also placed in each top-level dir)
```

> The `.gitignore` keeps heavy/raw data and generated outputs out of Git, but preserves per‑folder `README.md` files so the structure is tracked.

---

## Function signature (key args)

```r
scaffold_project(
  name,                      # project / folder name (required)
  path = ".",                # parent directory where it will be created
  init_git = TRUE,           # init Git and first commit
  default_branch = "main",
  init_renv = TRUE,         # TRUE to lay down renv infrastructure
  create_remote = c("none","github","url"),
  remote_url = NULL,         # used when create_remote == "url"
  github_org = NULL,         # GitHub org/user; NULL = your user
  github_private = TRUE,     # for use_github()
  template_yaml = NULL,      # optional YAML to override folder/file layout
  open = interactive()       # switch your session into the new project
)
```

Common variants:

```r
# Minimal new project, no remote, no renv
scaffold_project("projA", path = getwd())

# New project + renv infra
scaffold_project("projB", init_renv = TRUE)

# New project + GitHub remote (private)
scaffold_project("projC", create_remote = "github", github_private = TRUE)

# New project + existing remote URL (e.g., GitLab)
scaffold_project("projD", create_remote = "url",
                 remote_url = "https://gitlab.com/me/projD.git")
```

---

## GitHub token (PAT) — 60‑second setup

A **Personal Access Token** is required for creating repos or pushing via **HTTPS**. It’s **free** and stored as an **environment variable**.

1. Create one: `usethis::create_github_token()` → choose **fine‑grained** or **classic** with `repo` scope.  
2. Store it: `usethis::edit_r_environ()` → add a line like `GITHUB_TOKEN=ghp_XXXX...` → save.  
3. Reload & verify: `readRenviron("~/.Renviron"); gh::gh_whoami()` should show your account.

> Git over **SSH** is an alternative (no token/expiry for pushes). You can still keep a token for API tasks (repo creation).

**Expiry & rotation:** When a token expires, API calls (and HTTPS pushes) return 401. Create a new token, update `~/.Renviron`, and retry. You may need to clear your OS credential cache for HTTPS pushes (Windows Credential Manager / macOS Keychain / Linux libsecret).

---

## `renv` (optional but recommended)

Set `init_renv = TRUE` to lay down reproducibility infrastructure:

- `renv/` folder + auto‑activation via `.Rprofile`
- `renv.lock` for exact package versions

Workflow:

```r
renv::init(bare = TRUE)  # scaffolded for you if init_renv=TRUE
install.packages(c("data.table","sf"))
renv::snapshot()         # record versions
# elsewhere:
renv::restore()          # reproduce the same library
```

---

## Customizing the structure (YAML)

Prefer to keep the layout editable without touching R code? Create a YAML like:

```yaml
# project_template.yml
dirs:
  data: ["raw","preprocessed","processed","interim","sim-input"]
  notebooks: []
  reports: ["figures","tables"]
  src: []
  lib: []
  literature: []
files_root: ["README.md", ".gitignore", ".Rprofile"]
```

Use it:

```r
scaffold_project("my-proj", template_yaml = "path/to/project_template.yml")
```

---

## Troubleshooting

- **“Path … does not appear to be inside a project or package.”**  
  The scaffolder explicitly sets the usethis project context (`proj_set()`), so `use_rstudio()`, `use_git()`, `use_github()` run in the right place. If you hit this outside the scaffolder, call `usethis::proj_set(<path>, force = TRUE)`.

- **401 / auth failures when creating the GitHub remote.**  
  Token missing/expired/wrong scopes. Recreate token, update `~/.Renviron`, run `readRenviron("~/.Renviron")`, and retry.

- **HTTPS pushes still fail after rotation.**  
  Clear cached credentials (Windows Credential Manager / Keychain / libsecret), then push again (use username + new PAT).

- **OneDrive paths.**  
  Works fine. If a file is “in use” during sync, rerun the step—rare transient issue.

---

## Common tweaks

Add a Quarto starter:

```r
writeLines("---
title: 'Analysis'
format: html
---\n\n", file.path("reports", "analysis.qmd"))
```

Add a `_targets.R` or `Makefile` in `src/` for pipelines.

Adjust `.gitignore` to keep a small sample in `data/raw/`:

```
data/raw/*
!data/raw/README.md
!data/raw/sample.csv
```

---

## License

Choose a license (MIT/BSD/GPL) and add via:

```r
usethis::use_mit_license("Your Name")
```

---

**Happy scaffolding!**  
If you have ideas for improvements (extra stubs, default `targets`, Quarto site, CI), add them to your version of `scaffold_project()` and bump this README so future‑you remembers.
