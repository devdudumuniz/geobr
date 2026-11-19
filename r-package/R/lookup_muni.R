#' Look up municipality codes and names
#'
#' @description
#' Input a municipality \strong{name} \emph{or} \strong{code} and get the names
#' and codes of the municipality.
#'
#' @template year
#' @param name_muni The municipality name to be looked up.
#' @param code_muni The 7-digit IBGE municipality code or the 6-digit DATASUS
#'   code without its check digit. A 6-digit code must identify a unique
#'   municipality in the requested year.
#' @return A `data.frame` with 13 columns identifying the geographies information
#'         of that municipality.
#'
#' @return A `data.frame`
#'
#' @export
#'
#' @details Only available from 2010 Census data so far
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' # Look for municipality Rio de Janeiro
#' mun <- lookup_muni(
#'   name_muni = "Rio de Janeiro",
#'   year = 2022
#'   )
#'
#' # Look for a given municipality code
#' mun <- lookup_muni(
#'   code_muni = 3304557,
#'   year = 2022
#'   )
#'
#' # Get the lookup table for all municipalities
#' mun_all <- lookup_muni(
#'   name_muni = "all",
#'   year = 2022
#'   )
#'
#' # Or:
#' mun_all <- lookup_muni(
#'   code_muni = "all",
#'   year = 2022
#'   )
#'
lookup_muni <- function(year,
                        name_muni = NULL,
                        code_muni = NULL) {


  # check input: name_ and code_ at the same time
  if (!is.null(name_muni) & !is.null(code_muni)) {
    cli::cli_abort("Arguments 'name_muni' and 'code_muni' cannot be used at the same time.")
  }

  # check input: if both arguments are empty
  if (is.null(name_muni) & is.null(code_muni)) {
    cli::cli_abort("Please insert a valid municipality name or code.")
  }

  # download data
  # df <- geobr::read_municipality(
  df <- geobr::read_municipal_seat(
    year = year,
    output = "sf"
    ) |>
    sf::st_drop_geometry()

  # return ALL -----------------------------------------------------------------------

  if (isTRUE(any(name_muni == "all", code_muni == "all"))) {
    return(df)
    }


  # search name -----------------------------------------------------------------------

  # if code_muni is empty and name_muni is not empty, search for name_muni
  if (is.null(code_muni) & !is.null(name_muni)) {

      # 1. Format input

      x <- name_muni
      x <- tolower(x)
      # remove special characters
      x <- iconv(x, to="ASCII//TRANSLIT")
      x <- iconv(x, to="UTF-8")
      # trim white spaces
      x <- trimws(x, "both")

      # 2. Format input new column
      df <- df |>
        dplyr::mutate(
          name_muni_formatted = tolower(name_muni),
          name_muni_formatted = iconv(name_muni_formatted, to="ASCII//TRANSLIT")
          )

      # Filter muni code
      lookup_filter <- df |>
        dplyr::filter(name_muni_formatted == x)

      # tenta match probabilistico
      if (nrow(lookup_filter) == 0) {

        conn <- duckdb::dbConnect(duckdb::duckdb())
        on.exit(DBI::dbDisconnect(conn, shutdown = TRUE), add = TRUE)
        DBI::dbWriteTable(conn, name = "munis", value = df)

        query <- "
          SELECT
            code_muni,
            name_muni_formatted,
            similarity,
            RANK() OVER (
              PARTITION BY code_muni
              ORDER BY similarity DESC
            ) AS rank_num
          FROM (
            SELECT
              code_muni,
              name_muni_formatted,
              CAST(jaro_similarity(?, name_muni_formatted) AS NUMERIC(5,3)) AS similarity
            FROM munis
          ) t
          WHERE similarity > 0.9
        "

        df_prob <- DBI::dbGetQuery(conn, query, params = list(x))

        # filter code muni
        if (nrow(df_prob) > 0) {
          lookup_filter <- df |>
            dplyr::filter(name_muni_formatted %in% df_prob$name_muni_formatted)
        }
      }



      # erro, muni nao encontrado
      if (nrow(lookup_filter) == 0) {
        cli::cli_abort("Please insert a valid municipality name.")
        }

      # Delete formatted column
      lookup_filter$name_muni_formatted <- NULL

      return(lookup_filter)
      }


  # search code -----------------------------------------------------------------------

  return(.lookup_muni_code(df, code_muni, year))

}

.lookup_muni_code <- function(df, code_muni, year) {
  invalid_code <- function() {
    cli::cli_abort("Please insert a valid municipality code")
  }

  if (length(code_muni) != 1L || is.na(code_muni) ||
      !(is.numeric(code_muni) || is.character(code_muni))) {
    invalid_code()
  }

  if (is.numeric(code_muni)) {
    if (!is.finite(code_muni) || code_muni != trunc(code_muni)) {
      invalid_code()
    }
    code <- format(code_muni, scientific = FALSE, trim = TRUE)
  } else {
    code <- trimws(code_muni)
  }

  if (!grepl("^[0-9]{6,7}$", code)) {
    invalid_code()
  }

  raw_codes <- df$code_muni
  if (is.factor(raw_codes)) {
    raw_codes <- as.character(raw_codes)
  }
  codes <- suppressWarnings(as.numeric(raw_codes))
  valid <- !is.na(codes) & is.finite(codes) & codes == trunc(codes)
  matches <- if (nchar(code) == 6L) {
    valid & codes %/% 10 == as.numeric(code)
  } else {
    valid & codes == as.numeric(code)
  }
  out <- df[which(matches), , drop = FALSE]

  if (nchar(code) == 6L && nrow(out) > 1L) {
    cli::cli_abort(paste0(
      "The 6-digit code ", code, " matches ", nrow(out),
      " municipalities in ", year, ". Please use the 7-digit code."
    ))
  }
  if (nrow(out) == 0L) {
    invalid_code()
  }
  out
}
