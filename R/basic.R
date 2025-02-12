#' Basic forecasting (mean, median, random walk)
#'
#' Basic forecasting functions for multivariate time series
#'
#' @param y A multivariate time series of class \code{ts} or a matrix
#' @param h Forecasting horizon
#' @param level Confidence level for prediction intervals
#' @param method forecasting method, either "mean", "median", or random walk ("rw")
#' @param type_pi type of prediction interval currently, "gaussian" or "bootstrap"
#' @param seed reproducibility seed for \code{type_pi == 'bootstrap'}
#' @param B Number of bootstrap replications for \code{type_pi == 'bootstrap'}
#'
#' @return
#' @export
#'
#' @examples
#'
#' res <- ahead::basicf(fpp::insurance, h=10)
#' par(mfrow=c(1, 2))
#' plot(res, "TV.advert")
#' plot(res, "Quotes")
#'
#'
#' res <- ahead::basicf(fpp::insurance, method="rw", h=10)
#' par(mfrow=c(1, 2))
#' plot(res, "TV.advert")
#' plot(res, "Quotes")
#'
#'
basicf <- function(y,
                   h = 5,
                   level = 95,
                   method = c("mean", "median", "rw"),
                   type_pi = c("gaussian", "bootstrap"),
                   seed = 1,
                   B = 100)
{
  if (!is.ts(y))
  {
    y <- ts(y)
  }

  method <- match.arg(method)
  stopifnot(!is.null(ncol(y)))
  n_series <- ncol(y)
  series_names <- colnames(y)
  n_inputs <- nrow(y)
  type_pi <- match.arg(type_pi)
  freq_x <- frequency(y)
  start_x <- start(y)
  start_preds <- tsp(y)[2] + 1 / freq_x

  # point forecast depending on the method
  point_forecast <- switch(method,
                           mean = colMeans(y),
                           median = apply(y, 2, median),
                           rw = y[nrow(y), ])

  # in sample
  fits <- ts(t(replicate(n = n_inputs, expr = point_forecast)),
             start = start_x, frequency = freq_x)
  resids <- y - fits

  # out-of-sample
  fcast <- ts(t(replicate(n = h, expr = point_forecast)),
              start = start_preds, frequency = freq_x)

  if (type_pi == "gaussian")
  {
    # strong Gaussian assumption
    sds <- apply(resids, 2, sd)
    qtsd <- -qnorm(0.5 - level / 200) * sds
    qtsd <- t(replicate(h, qtsd))

    # Forecast from fit_obj
    out <- list(
      mean = fcast,
      lower = fcast - qtsd,
      upper = fcast + qtsd,
      sims = NULL,
      x = y,
      level = level,
      method = method,
      residuals = resids
    )

    return(structure(out, class = "mtsforecast"))
  }

  if (type_pi == "bootstrap")
  {
    sims <- vector("list", length = B)
    for (i in 1:B)
    {
      # sampling from the residuals
      set.seed(seed + i*100 + nchar(method))
      idx <- sample.int(n = nrow(resids),
                        size = h, replace = TRUE)

      sims[[i]] <- ts(as.matrix(fcast) + as.matrix(resids[idx, ]),
                      start = start_preds,
                      frequency = freq_x)
    }

    preds_upper <- matrix(0, ncol = n_series, nrow = h)
    preds_lower <- matrix(0, ncol = n_series, nrow = h)
    colnames(preds_upper) <- series_names
    colnames(preds_lower) <- series_names

    for (j in 1:n_series)
    {
      sims_series_j <- sapply(1:B, function(i)
        sims[[i]][, j])
      preds_upper[, j] <-
        apply(sims_series_j, 1, function(x)
          quantile(x, probs = 1 - (1 - level / 100) / 2))
      preds_lower[, j] <-
        apply(sims_series_j, 1, function(x)
          quantile(x, probs = (1 - level / 100) / 2))
    }

    # return
    out <- list(
      mean = fcast,
      lower = ts(
        data = preds_lower,
        start = start_preds,
        frequency = freq_x
      ),
      upper = ts(
        data = preds_upper,
        start = start_preds,
        frequency = freq_x
      ),
      sims = sims,
      x = y,
      level = level,
      method = method,
      residuals = resids
    )

    return(structure(out, class = "mtsforecast"))
  }

}
