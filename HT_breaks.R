library(tidyverse)

HT_breaks <- function(x, k) {
  if (k > 1) {
    x0 <- vector("list", k)
    xm0 <- vector("list", (k-1))
    x0[[1]] <- x
    for (i in 1:(k-1)) {
      xm0[[i]] <- mean(x0[[i]])
      x0[[(i+1)]] <- x0[[i]][x0[[i]] > xm0[[i]]]
      if (length(x0[[(i+1)]]) <= 2) break
    }
    xbid <- c(min(x), unlist(xm0), max(x))
    xmem <- as.integer(cut(x,  breaks = xbid, label = c(1:k), include.lowest = TRUE))
    xsize <- as.integer(table(xmem))
    return(
      list(
        bin = xbid,
        size = xsize,
        member = xmem
      )
    )
  } else {
    return(NULL)
  }
}
