# Click-to-reveal ties (optional)

## Summary

Add an opt-in mode where tie connector lines are hidden until the user clicks
(selects) an item on the timeline. When active, only ties whose `from` or `to`
endpoint is among the currently selected items are drawn. Empty selection
draws no ties. Default behavior is unchanged: ties are always visible.

## Motivation

Dense timelines with many cross-task dependencies become visually noisy when
every tie is drawn at once. Developers want a setting that lets end users
"explore" dependencies one task at a time: click a task, see only its ties.

## User-facing API (R)

`ties` (and the `setTies()` setter) accept two shapes:

1. **data.frame** with `from`, `to` columns — current behavior, all ties
   always drawn. Unchanged.
2. **list** of the form
   `list(data = <df with from/to>, onClick = TRUE)` — click-to-reveal mode.

`onClick` is a single logical (`TRUE`/`FALSE`). `onClick = FALSE` in the list
form is equivalent to passing the data.frame directly.

### Validation (R)

In `timevis()` and `setTies()`:

- If `ties` is a list (and not a data.frame), require it has a `data` element
  that is a data.frame with `from`/`to` columns (existing checks reused), and
  an `onClick` element that is a single logical. Reject otherwise with a clear
  message: `"timevis: 'ties$onClick' must be a single TRUE or FALSE"`,
  `"timevis: 'ties$data' must be a data.frame with 'from' and 'to' columns"`.
- If `ties` is a data.frame, behavior is exactly as today.
- `NULL` clears ties, as today.

## Wire format (R -> JS)

Two top-level fields on the widget payload `x`:

- `ties`: array of `{from, to}` objects, or `NULL` (unchanged).
- `tiesOnClick`: scalar logical, default `FALSE`. Always present when `ties`
  is non-null.

For `setTies()` messages: send both `ties` and `tiesOnClick` together.

## JS behavior

State additions in `factory`:

- `tiesOnClick = false` (mirrors the new opt).

In `renderValue`:

- When `'ties' in opts`, set `tiesData = opts.ties || null` (as today) and
  `tiesOnClick = !!opts.tiesOnClick`.
- During first-init only, register a `timeline.on('select', ...)` handler
  that calls `that.drawTies()`. This must run regardless of `shinyMode`
  (distinct from the existing Shiny-only `select` handler).

In `drawTies()`:

- After clearing existing paths and the `!tiesData || !tiesData.length`
  early-return, add:

  ```js
  var filterIds = null;
  if (tiesOnClick) {
    var sel = timeline.getSelection() || [];
    if (!sel.length) return;             // empty selection -> no ties
    filterIds = {};
    for (var k = 0; k < sel.length; k++) filterIds[String(sel[k])] = true;
  }
  ```

- Inside the per-tie loop, skip ties where neither endpoint matches:

  ```js
  if (filterIds &&
      !filterIds[String(tie.from)] &&
      !filterIds[String(tie.to)]) continue;
  ```

In `setTies` handler:

- Update both `tiesData = params.ties || null` and
  `tiesOnClick = !!params.tiesOnClick`, then call `this.drawTies()`.

Multi-select (ctrl-click) is supported naturally because
`timeline.getSelection()` returns all selected ids — union semantics fall out
of the filter logic.

## Tests

Extend `tests/testthat/test-ties.R`:

- list form with valid `data` + `onClick = TRUE` is accepted; round-trips to
  `x$ties` (array) + `x$tiesOnClick == TRUE`.
- list form with `onClick = FALSE` is accepted; equivalent to df form.
- list form rejects: missing `data`, `data` not a df, `data` missing from/to,
  `onClick` not logical, `onClick` not length 1.
- df form unchanged: `x$tiesOnClick` is `FALSE` (or absent / falsy).
- `setTies()` accepts both shapes and produces correct API call payload
  containing both fields.

## Documentation

- Update `@param ties` roxygen in `R/timevis.R` to describe both shapes.
- Update `setTies()` roxygen in `R/api.R` similarly.
- Regenerate `man/timevis.Rd` and `man/setTies.Rd`.
- README: extend the ties section with a click-to-reveal example.
- `NEWS.md`: add bullet under current dev version.

## Out of scope

- No new visual styling for "highlighted" vs "unhighlighted" items.
- No hover-to-reveal mode (selection only).
- No persistence of selection across re-renders beyond what vis-timeline
  already provides.
- No Shiny input exposing which ties are currently drawn.

## Backward compatibility

Default `tiesOnClick = FALSE` and the data.frame form of `ties` are
preserved bit-for-bit. Existing apps that pass `ties = df` see no change.
