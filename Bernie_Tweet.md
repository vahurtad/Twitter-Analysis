BernieTweet
================

``` r
library(rtweet)
library(stringr)
library(dplyr)
library(tidyverse)
library(lubridate)
library(scales)
library(tidytext)
```

## Get user timeline

tmls \<- get\_timelines(‘BernieSanders’, n = 3200) tweets \<- tmls %\>%
select(status\_id, source, text, created\_at) tweets \<-
mutate(tweets,source
=ifelse(str\_detect(tweets\(source,'(?<=Twitter )[^.]*')==TRUE,str_match(tweets\)source,
’(?\<=Twitter )\[^.\]\*‘),
tweets\(source)) tweets tweets\)source\[tweets$source == ’for iPad’\]
\<-’iPad’ tweets\(source[tweets\)source == ‘for iPhone’\] \<-‘iPhone’
tweets\(source[tweets\)source == ‘for Android’\] \<-‘Android’
tweets\(source<- gsub(" ","",tweets\)source) tweets\_count \<-tweets
%\>% count(source) tweets\_count

## Including Code

You can include R code in the document as follows:

``` r
summary(cars)
```

    ##      speed           dist       
    ##  Min.   : 4.0   Min.   :  2.00  
    ##  1st Qu.:12.0   1st Qu.: 26.00  
    ##  Median :15.0   Median : 36.00  
    ##  Mean   :15.4   Mean   : 42.98  
    ##  3rd Qu.:19.0   3rd Qu.: 56.00  
    ##  Max.   :25.0   Max.   :120.00

## Including Plots

You can also embed plots, for example:

![](Bernie_Tweet_files/figure-gfm/pressure-1.png)<!-- -->

Note that the `echo = FALSE` parameter was added to the code chunk to
prevent printing of the R code that generated the plot.
