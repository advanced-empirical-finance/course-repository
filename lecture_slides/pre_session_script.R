Sys.setlocale("LC_TIME", "English")
Sys.setenv(LANG = "en")
Sys.setenv(TZ = 'GMT')

library(tidyverse)
library(kableExtra)

theme_set(theme_bw() + theme(legend.position = "bottom"))

def.chunk.hook <- knitr::knit_hooks$get("chunk")
knitr::knit_hooks$set(chunk = function(x, options) {
  x <- def.chunk.hook(x, options)
  ifelse(
    options$size != "normalsize",
    paste0("\n \\", options$size, "\n\n", x, "\n\n \\normalsize"),
    x
  )
})
