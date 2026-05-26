# Click-to-reveal Ties Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in mode where ties hide until a timeline item is clicked, then only that item's ties show.

**Architecture:** Extend the `ties` argument (and `setTies()` setter) to accept either the current `data.frame` *or* a `list(data = <df>, onClick = TRUE)`. The R layer normalises this into two wire fields, `ties` (array) and `tiesOnClick` (logical). The JS widget stores `tiesOnClick`, hooks `timeline.on('select')`, and filters the per-tie draw loop in `drawTies()` by `timeline.getSelection()` when the flag is on.

**Tech Stack:** R (htmlwidgets, testthat, roxygen2), vanilla JS (vis-timeline).

---

## File Structure

- **Modify** `R/timevis.R` — extend `ties` validation, add `tiesOnClick` to widget payload, update roxygen.
- **Modify** `R/api.R` — extend `setTies()` to accept list form and ship `tiesOnClick`, update roxygen.
- **Modify** `inst/htmlwidgets/timevis.js` — store `tiesOnClick`, hook `select`, filter in `drawTies()`, update `setTies` handler.
- **Modify** `tests/testthat/test-ties.R` — add tests for the new list form + setter.
- **Regenerate** `man/timevis.Rd`, `man/setTies.Rd` via `devtools::document()`.
- **Modify** `NEWS.md`, `README.md` — note new feature and add a usage example.

---

### Task 1: R-side helper to normalise `ties`

**Files:**
- Modify: `R/timevis.R` (replace the `if (!is.null(ties)) { ... }` block around lines 474–486)
- Test: `tests/testthat/test-ties.R`

- [ ] **Step 1: Write failing tests for the new list form**

Append to `tests/testthat/test-ties.R`:

```r
test_that("timevis() accepts ties = list(data = df, onClick = TRUE)", {
  w <- timevis(
    data = items,
    ties = list(
      data    = data.frame(from = c(1L, 2L), to = c(2L, 3L)),
      onClick = TRUE
    )
  )
  expect_true(is.list(w$x$ties))
  expect_length(w$x$ties, 2)
  expect_equal(w$x$ties[[1]]$from, "1")
  expect_true(isTRUE(w$x$tiesOnClick))
})

test_that("timevis() with ties list and onClick = FALSE matches df form", {
  w <- timevis(
    data = items,
    ties = list(
      data    = data.frame(from = 1L, to = 2L),
      onClick = FALSE
    )
  )
  expect_false(isTRUE(w$x$tiesOnClick))
  expect_length(w$x$ties, 1)
})

test_that("timevis() with bare df ties has tiesOnClick FALSE", {
  w <- timevis(data = items, ties = data.frame(from = 1L, to = 2L))
  expect_false(isTRUE(w$x$tiesOnClick))
})

test_that("timevis() rejects ties list with bad onClick", {
  expect_error(
    timevis(data = items,
            ties = list(data = data.frame(from = 1, to = 2), onClick = "yes")),
    "'ties\\$onClick' must be a single TRUE or FALSE"
  )
  expect_error(
    timevis(data = items,
            ties = list(data = data.frame(from = 1, to = 2),
                        onClick = c(TRUE, FALSE))),
    "'ties\\$onClick' must be a single TRUE or FALSE"
  )
})

test_that("timevis() rejects ties list with missing or invalid data", {
  expect_error(
    timevis(data = items, ties = list(onClick = TRUE)),
    "'ties\\$data' must be a data.frame"
  )
  expect_error(
    timevis(data = items,
            ties = list(data = list(from = 1, to = 2), onClick = TRUE)),
    "'ties\\$data' must be a data.frame"
  )
  expect_error(
    timevis(data = items,
            ties = list(data = data.frame(from = 1), onClick = TRUE)),
    "'from' and 'to'"
  )
})
```

- [ ] **Step 2: Run tests and confirm they fail**

Run: `Rscript -e "devtools::test(filter = 'ties')"`
Expected: the 5 new tests fail (either with errors that don't match, or with the old "ties must be a data.frame" message).

- [ ] **Step 3: Add the normalisation helper above `timevis()` in `R/timevis.R`**

Insert just above the `timevis <- function(...)` definition (around line 388):

```r
# Normalise the `ties` argument into a list of:
#   data  : data.frame with from/to (or NULL)
#   onClick: single logical (default FALSE)
tv_normalize_ties <- function(ties) {
  if (is.null(ties)) {
    return(list(data = NULL, onClick = FALSE))
  }
  if (is.data.frame(ties)) {
    return(list(data = ties, onClick = FALSE))
  }
  if (is.list(ties)) {
    if (!is.data.frame(ties$data)) {
      stop("timevis: 'ties$data' must be a data.frame", call. = FALSE)
    }
    if (!is.logical(ties$onClick) || length(ties$onClick) != 1 ||
        is.na(ties$onClick)) {
      stop("timevis: 'ties$onClick' must be a single TRUE or FALSE",
           call. = FALSE)
    }
    return(list(data = ties$data, onClick = ties$onClick))
  }
  stop("timevis: 'ties' must be a data.frame or a list(data, onClick)",
       call. = FALSE)
}
```

- [ ] **Step 4: Replace the in-place ties block in `timevis()`**

Replace the block currently at lines ~474–486 (the `if (!is.null(ties)) { ... ties <- dataframeToD3(...) }`) with:

```r
  ties_norm   <- tv_normalize_ties(ties)
  tiesOnClick <- ties_norm$onClick
  ties_df     <- ties_norm$data
  if (!is.null(ties_df)) {
    if (!("from" %in% names(ties_df)) || !("to" %in% names(ties_df))) {
      stop("timevis: 'ties' must contain 'from' and 'to' columns",
           call. = FALSE)
    }
    ties <- dataframeToD3(data.frame(
      from = as.character(ties_df$from),
      to   = as.character(ties_df$to)
    ))
  } else {
    ties <- NULL
  }
```

Then in the `x = list(...)` literal that builds the payload (currently ending with `ties = ties`), add `tiesOnClick = tiesOnClick` immediately after `ties = ties`.

- [ ] **Step 5: Run tests and confirm they pass**

Run: `Rscript -e "devtools::test(filter = 'ties')"`
Expected: all ties tests pass (existing + 5 new).

- [ ] **Step 6: Commit**

```bash
git add R/timevis.R tests/testthat/test-ties.R
git commit -m "feat(ties): accept list(data, onClick) form in timevis()"
```

---

### Task 2: Extend `setTies()` to accept the list form

**Files:**
- Modify: `R/api.R` (the `setTies` definition, lines ~531–540)
- Test: `tests/testthat/test-ties.R`

- [ ] **Step 1: Write failing tests for `setTies()` with list form**

Append to `tests/testthat/test-ties.R`:

```r
test_that("setTies accepts list(data, onClick = TRUE) and forwards both", {
  ties_arg <- list(
    data    = data.frame(from = 1L, to = 2L),
    onClick = TRUE
  )
  w <- timevis(data = items) %>% setTies(ties_arg)
  call <- w$x$api[[length(w$x$api)]]
  expect_equal(call$method, "setTies")
  expect_true(is.list(call$ties))
  expect_length(call$ties, 1)
  expect_equal(call$ties[[1]]$from, "1")
  expect_true(isTRUE(call$tiesOnClick))
})

test_that("setTies with bare df sends tiesOnClick FALSE", {
  w <- timevis(data = items) %>% setTies(data.frame(from = 1, to = 2))
  call <- w$x$api[[length(w$x$api)]]
  expect_false(isTRUE(call$tiesOnClick))
})

test_that("setTies(NULL) sends NULL ties and FALSE tiesOnClick", {
  w <- timevis(data = items) %>% setTies(NULL)
  call <- w$x$api[[length(w$x$api)]]
  expect_null(call$ties)
  expect_false(isTRUE(call$tiesOnClick))
})

test_that("setTies rejects bad list form", {
  expect_error(
    timevis(data = items) %>%
      setTies(list(data = data.frame(from = 1, to = 2), onClick = "x")),
    "'ties\\$onClick' must be a single TRUE or FALSE"
  )
})
```

- [ ] **Step 2: Run tests and confirm they fail**

Run: `Rscript -e "devtools::test(filter = 'ties')"`
Expected: the 4 new setTies tests fail (existing setTies tests still pass).

- [ ] **Step 3: Update `setTies()` in `R/api.R` to use the normaliser**

Replace the body of `setTies` (lines ~531–540) with:

```r
setTies <- function(id, ties) {
  method <- "setTies"
  ties_norm   <- tv_normalize_ties(ties)
  tiesOnClick <- ties_norm$onClick
  ties_df     <- ties_norm$data
  if (!is.null(ties_df)) {
    if (!("from" %in% names(ties_df)) || !("to" %in% names(ties_df))) {
      stop("timevis: 'ties' must contain 'from' and 'to' columns",
           call. = FALSE)
    }
    ties <- dataframeToD3(data.frame(
      from = as.character(ties_df$from),
      to   = as.character(ties_df$to)
    ))
  } else {
    ties <- NULL
  }
  callJS()
}
```

(`callJS()` picks up `tiesOnClick` from the parent frame automatically.)

- [ ] **Step 4: Run tests and confirm they pass**

Run: `Rscript -e "devtools::test(filter = 'ties')"`
Expected: all ties tests pass.

- [ ] **Step 5: Commit**

```bash
git add R/api.R tests/testthat/test-ties.R
git commit -m "feat(ties): accept list(data, onClick) form in setTies()"
```

---

### Task 3: JS widget — store `tiesOnClick`, filter draw, hook select

**Files:**
- Modify: `inst/htmlwidgets/timevis.js`

(No new automated tests — this layer is exercised manually; R-side tests in Tasks 1–2 already cover the wire format.)

- [ ] **Step 1: Add `tiesOnClick` state**

Find (around line 25):

```js
    var tiesData = null;            // array of {from, to} tie objects or null
    var tiesSvg = null;             // SVG overlay element for drawing tie lines
```

Insert directly above the `tiesSvg` line:

```js
    var tiesOnClick = false;        // when true, only draw ties touching the current selection
```

- [ ] **Step 2: Read `tiesOnClick` from `opts` in `renderValue`**

Find (around line 72):

```js
        if ('ties' in opts) {
          tiesData = opts.ties || null;
        }
```

Replace with:

```js
        if ('ties' in opts) {
          tiesData = opts.ties || null;
        }
        if ('tiesOnClick' in opts) {
          tiesOnClick = !!opts.tiesOnClick;
        }
```

- [ ] **Step 3: Hook a non-Shiny `select` handler that redraws ties**

Find the `timeline.on('changed', function() { ... that.drawTies(); ... })` block (around lines 184–193). Immediately after it (still inside the `if (!initialized)` block), add:

```js
          // Redraw ties whenever the selection changes (independent of Shiny mode).
          timeline.on('select', function() {
            that.drawTies();
          });
```

- [ ] **Step 4: Filter the per-tie loop in `drawTies()`**

Find inside `drawTies()` (around line 666):

```js
        if (!tiesData || !tiesData.length) return;
```

Immediately after that line, insert:

```js
        var filterIds = null;
        if (tiesOnClick) {
          var sel = timeline.getSelection() || [];
          if (!sel.length) return;
          filterIds = {};
          for (var k = 0; k < sel.length; k++) filterIds[String(sel[k])] = true;
        }
```

Then inside the `for (var i = 0; i < tiesData.length; i++)` loop, immediately after `var tie = tiesData[i];`, insert:

```js
          if (filterIds &&
              !filterIds[String(tie.from)] &&
              !filterIds[String(tie.to)]) continue;
```

- [ ] **Step 5: Update the `setTies` API handler to read both fields**

Find (around line 653):

```js
      setTies : function(params) {
        tiesData = params.ties || null;
        this.drawTies();
      },
```

Replace with:

```js
      setTies : function(params) {
        tiesData = params.ties || null;
        if ('tiesOnClick' in params) {
          tiesOnClick = !!params.tiesOnClick;
        }
        this.drawTies();
      },
```

- [ ] **Step 6: Manual sanity check via the R package**

Run from the repo root:

```bash
Rscript -e "devtools::load_all(); \
  print(timevis( \
    data = data.frame(id=1:3, content=c('A','B','C'), \
                      start=c('2016-01-10','2016-01-14','2016-01-20'), \
                      end  =c('2016-01-13','2016-01-19','2016-01-22')), \
    ties = list(data = data.frame(from=c(1,2), to=c(2,3)), onClick = TRUE) \
  )\$x[c('ties','tiesOnClick')])"
```

Expected: prints a `ties` list-of-lists with two entries and `tiesOnClick = TRUE`.

- [ ] **Step 7: Commit**

```bash
git add inst/htmlwidgets/timevis.js
git commit -m "feat(ties): JS click-to-reveal filtering and select hook"
```

---

### Task 4: Documentation

**Files:**
- Modify: `R/timevis.R` (roxygen for `@param ties`)
- Modify: `R/api.R` (roxygen for `setTies`)
- Regenerate: `man/timevis.Rd`, `man/setTies.Rd`
- Modify: `NEWS.md`, `README.md`

- [ ] **Step 1: Update `@param ties` in `R/timevis.R`**

Replace the existing `@param ties ...` block (around lines 78–82) with:

```r
#' @param ties Optional connector lines between items. Either:
#' \itemize{
#'   \item a data.frame with \code{from} and \code{to} columns of item IDs
#'   (ties are always shown), or
#'   \item a list of the form
#'   \code{list(data = <df with from/to>, onClick = TRUE)}: ties are hidden
#'   until an item is clicked; only ties touching the current selection are
#'   drawn (union across multi-select; nothing drawn when nothing is selected).
#' }
#' Each tie draws a three-segment (horizontal-vertical-horizontal) line from
#' the right edge of the \code{from} item to the left edge of the \code{to}
#' item. An item may appear in multiple rows. See also
#' \code{\link[timevis]{setTies}}.
```

- [ ] **Step 2: Update the `setTies` roxygen in `R/api.R`**

Replace the existing `@param ties` line (around line 518–519) with:

```r
#' @param ties Either a data.frame with \code{from} and \code{to} columns of
#'   item IDs (always-on ties), a list of the form
#'   \code{list(data = <df>, onClick = TRUE)} for click-to-reveal mode, or
#'   \code{NULL} to remove all ties.
```

- [ ] **Step 3: Regenerate man pages**

Run: `Rscript -e "devtools::document()"`
Expected: `man/timevis.Rd` and `man/setTies.Rd` updated; no errors.

- [ ] **Step 4: Add a NEWS entry**

Open `NEWS.md`, find the topmost (most recent / unreleased) version section, and add a bullet:

```
- New click-to-reveal ties mode: pass `ties = list(data = <df>, onClick = TRUE)`
  to `timevis()` or `setTies()` so that ties are hidden until an item is
  clicked, then only that item's ties are drawn.
```

- [ ] **Step 5: Add a README example**

Open `README.md`, find the ties section (search for `## Ties` or `setTies`). Append a subsection:

````markdown
#### Click-to-reveal ties

Pass `ties` as a list with `onClick = TRUE` to hide ties until an item is
clicked. Only ties touching the current selection are drawn:

```r
timevis(
  data = data.frame(id = 1:3, content = c("Plan", "Build", "Ship"),
                    start = c("2016-01-10", "2016-01-14", "2016-01-20"),
                    end   = c("2016-01-13", "2016-01-19", "2016-01-22")),
  ties = list(
    data    = data.frame(from = c(1, 2), to = c(2, 3)),
    onClick = TRUE
  )
)
```
````

- [ ] **Step 6: Full check**

Run: `Rscript -e "devtools::test()"` and `Rscript -e "devtools::check(args = '--no-manual')"`
Expected: all tests pass; check has no new ERRORs / WARNINGs introduced by these changes.

- [ ] **Step 7: Commit**

```bash
git add R/timevis.R R/api.R man/timevis.Rd man/setTies.Rd NEWS.md README.md
git commit -m "docs(ties): document click-to-reveal mode"
```
