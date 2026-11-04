test_that("6-digit municipal codes resolve only unique matches", {
  seats <- data.frame(
    code_muni = c(3304557, 3550308, NA_real_),
    name_muni = c("Rio de Janeiro", "Sao Paulo", "missing")
  )

  expect_equal(.lookup_muni_code(seats, 330455, 2010)$code_muni, 3304557)
  expect_equal(.lookup_muni_code(seats, " 355030 ", 2010)$code_muni, 3550308)
  expect_equal(.lookup_muni_code(seats, 3304557, 2010)$code_muni, 3304557)
  expect_equal(.lookup_muni_code(seats, 3304557.0, 2010)$code_muni, 3304557)
  factor_seats <- transform(seats[1:2, ], code_muni = factor(code_muni))
  expect_equal(as.character(.lookup_muni_code(factor_seats, 330455, 2010)$code_muni), "3304557")
})

test_that("historical 6-digit ambiguity is an error", {
  seats <- data.frame(code_muni = c(1599902, 1599903))

  expect_error(
    .lookup_muni_code(seats, 159990, 1872),
    "matches 2 municipalities in 1872"
  )
  expect_equal(.lookup_muni_code(seats, 1599903, 1872)$code_muni, 1599903)
})

test_that("malformed and missing municipal codes are rejected", {
  seats <- data.frame(code_muni = c(3304557, NA_real_))

  for (code in list(NA, Inf, 330455.5, "33a455", "33045", 999999, c(330455, 355030))) {
    expect_error(.lookup_muni_code(seats, code, 2010))
  }
})
