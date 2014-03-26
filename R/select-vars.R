#' Select variables.
#'
#' @param vars A character vector of existing column names.
#' @param ... Expressions to compute
#' @param include,exclude Character vector of column names to always
#'   include/exclude.
#' @export
#' @keywords internal
#' @return A named character vector. Values are existing column names,
#'   names are new names.
#' @examples
#' # Keep variables
#' select_vars(names(iris), starts_with("Petal"))
#' select_vars(names(iris), ends_with("Width"))
#' select_vars(names(iris), contains("etal"))
#' select_vars(names(iris), matches(".t."))
#' select_vars(names(iris), Petal.Length, Petal.Width)
#'
#' df <- as.data.frame(matrix(runif(100), nrow = 10))
#' df <- df[c(3, 4, 7, 1, 9, 8, 5, 2, 6, 10)]
#' select_vars(names(df), num_range("V", 4:6))
#'
#' # Drop variables
#' select_vars(names(iris), -starts_with("Petal"))
#' select_vars(names(iris), -ends_with("Width"))
#' select_vars(names(iris), -contains("etal"))
#' select_vars(names(iris), -matches(".t."))
#' select_vars(names(iris), -Petal.Length, -Petal.Width)
#'
#' # Rename variables
#' select_vars(names(iris), petal_length = Petal.Length)
#' select_vars(names(iris), petal = starts_with("Petal"))
select_vars <- function(vars, ..., env = parent.frame(),
  include = character(), exclude = character()) {

  select_vars_q(vars, dots(...), env = env, include = include,
    exclude = exclude)
}

#' @rdname select_vars
#' @export
select_vars_q <- function(vars, args, env = parent.frame(),
  include = character(), exclude = character()) {
  if (length(args) == 0) {
    vars <- setdiff(union(vars, include), exclude)
    return(setNames(vars, vars))
  }

  if (is.character(args)) {
    args <- lapply(args, as.name)
  }

  names_list <- setNames(as.list(seq_along(vars)), vars)
  names_env <- list2env(names_list, parent = env)

  # No non-standard evaluation - but all names mapped to their position.
  # Keep integer semantics: include = +, exclude = -
  # How to document starts_with, ends_with etc?

  select_funs <- list(
    starts_with = function(match, ignore.case = TRUE) {
      stopifnot(is.string(match), !is.na(match))

      if (ignore.case) match <- tolower(match)
      n <- nchar(match)

      if (ignore.case) vars <- tolower(vars)
      which(substr(vars, 1, n) == match)
    },
    ends_with = function(match, ignore.case = TRUE) {
      stopifnot(is.string(match), !is.na(match))

      if (ignore.case) match <- tolower(match)
      n <- nchar(match)

      if (ignore.case) vars <- tolower(vars)
      length <- nchar(vars)

      which(substr(vars, pmax(1, length - n + 1), length) == match)
    },
    contains = function(match, ignore.case = TRUE) {
      stopifnot(is.string(match))

      grep(match, vars, ignore.case = ignore.case)
    },
    matches = function(match, ignore.case = TRUE) {
      stopifnot(is.string(match))

      grep(match, vars, ignore.case = ignore.case)
    },
    num_range = function(prefix, range, width = NULL) {
      if (!is.null(width)) {
        range <- sprintf(paste0("%0", width, "d"), range)
      }
      match(paste0(prefix, range), vars)
    }
  )
  select_env <- list2env(select_funs, names_env)

  ind_list <- lapply(args, eval, env = select_env)
  names(ind_list) <- names2(args)

  ind <- unlist(ind_list)
  incl <- ind[ind > 0]
  if (length(incl) == 0) {
    incl <- seq_along(vars)
  }
  # Remove dupliates (unique loses names)
  incl <- incl[!duplicated(incl)]

  # Remove variables to be excluded (setdiff loses names)
  excl <- abs(ind[ind < 0])
  incl <- incl[match(incl, excl, 0L) == 0L]

  # Include/exclude specified variables
  sel <- setNames(vars[incl], names(incl))
  sel <- c(setdiff2(include, sel), sel)
  sel <- setdiff2(sel, exclude)

  # Ensure all output vars named
  unnamed <- names2(sel) == ""
  names(sel)[unnamed] <- sel[unnamed]

  sel
}

setdiff2 <- function(x, y) {
  x[match(x, y, 0L) == 0L]
}
