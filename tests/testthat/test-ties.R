context("ties / setTies")

items <- data.frame(
  id      = 1:3,
  content = c("Plan", "Build", "Ship"),
  start   = c("2016-01-10", "2016-01-14", "2016-01-20"),
  end     = c("2016-01-13", "2016-01-19", "2016-01-22")
)

test_that("timevis() with ties = NULL stores no ties", {
  w <- timevis(data = items)
  expect_null(w$x$ties)
})

test_that("timevis() errors when ties is not a data.frame", {
  expect_error(
    timevis(data = items, ties = list(from = 1, to = 2)),
    "'ties\\$data' must be a data.frame"
  )
})

test_that("timevis() errors when ties is missing required columns", {
  expect_error(
    timevis(data = items, ties = data.frame(from = 1)),
    "'from' and 'to'"
  )
  expect_error(
    timevis(data = items, ties = data.frame(to = 1)),
    "'from' and 'to'"
  )
})

test_that("timevis() accepts a zero-row ties data.frame", {
  w <- timevis(data = items,
               ties = data.frame(from = character(), to = character()))
  expect_true(is.null(w$x$ties) || length(w$x$ties) == 0)
})

test_that("timevis() normalises ties to list-of-lists with character ids", {
  w <- timevis(data = items,
               ties = data.frame(from = c(1L, 2L), to = c(2L, 3L)))
  expect_true(is.list(w$x$ties))
  expect_length(w$x$ties, 2)
  expect_equal(w$x$ties[[1]]$from, "1")
  expect_equal(w$x$ties[[1]]$to,   "2")
  expect_equal(w$x$ties[[2]]$from, "2")
  expect_equal(w$x$ties[[2]]$to,   "3")
})

test_that("setTies chained pre-render queues the API call", {
  ties_df <- data.frame(from = 1L, to = 2L)
  w <- timevis(data = items) %>% setTies(ties_df)
  expect_true(length(w$x$api) >= 1)
  call <- w$x$api[[length(w$x$api)]]
  expect_equal(call$method, "setTies")
  expect_true(is.list(call$ties))
  expect_length(call$ties, 1)
  expect_equal(call$ties[[1]]$from, "1")
  expect_equal(call$ties[[1]]$to,   "2")
})

test_that("setTies accepts NULL to clear ties", {
  w <- timevis(data = items) %>% setTies(NULL)
  call <- w$x$api[[length(w$x$api)]]
  expect_equal(call$method, "setTies")
  expect_null(call$ties)
})

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
