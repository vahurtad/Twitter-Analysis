install.packages("dplyr")
install.packages("purrr")
install.packages("twitteR")
library(dplyr)
library(purrr)
library(twitteR)
library(tidyr)
library(lubridate)
library(scales)

options(
  twitter_consumer_key = 'zDXW12NvVEs8Kvn1rBFWHcZdq',
  twitter_consumer_secret ='mkZ3DSG00oFimD1QDQYe6DiYKYqoLRGJPTc8NEkejx1JhanvQp',
  twitter_access_token = '840119918976630785-vIQFyr4X81p6J1zjplJ3Lg0avbfopBj',
  twitter_access_token_secret ='agw7Yy29GDELq0MGwVkKU3iyGggQUHdtgCFQMTXHdawse'
  )


# Setup oauth 
setup_twitter_oauth(
  getOption("twitter_consumer_key"),
  getOption("twitter_consumer_secret"),
  getOption("twitter_access_token"),
  getOption("twitter_access_token_secret")
  )

tmls <- userTimeline('realDonaldTrump', n = 3200)
tweets <- tmls %>% select(id, statusSource, text, created) 
tweets <- mutate(tweets,source =str_extract(tweets$statusSource, '(?<=Twitter for )[^.]*')) 

tweets
tmls$id


# We can request only 3200 tweets at a time; it will return fewer
# depending on the API
trump_tweets <- userTimeline('realDonaldTrump', n = 200)
length(trump_tweets)
as_tibble(trump_tweets)
trump_tweets_df <- tbl_df(map_df(trump_tweets, as.data.frame))
as_tibble(trump_tweets_df)


tweets <- trump_tweets_df %>%
  select(id, statusSource, text, created) %>%
  extract(statusSource, "source", "Twitter for (.*?)<") %>%
  filter(source %in% c("iPhone", "Android"))

tweets %>%
  count(source)
tweets

trump_tweets_df %>% 
  extract(statusSource, "source", "Twitter for (.*?)<") %>% source



