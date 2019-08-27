library(googlesheets)
library(rtweet)
library(openxlsx)


## get user timeline
tmls <- get_timelines('BernieSanders', n = 3200)
glimpse(tmls)
users_data(tmls)
tweets <- tmls %>% select(status_id, source, text, created_at, bbox_coords,
                          favorite_count, retweet_count,location) %>%
  filter(!tmls$is_retweet)
tweets <- mutate(tweets,source =ifelse(str_detect(tweets$source,'(?<=Twitter )[^.]*')==TRUE,str_match(tweets$source, '(?<=Twitter )[^.]*'), tweets$source))

#rename values for source column
tweets$source[tweets$source == 'for iPad'] <-'iPad'
tweets$source[tweets$source == 'for iPhone'] <-'iPhone'
tweets$source[tweets$source == 'for Android'] <-'Android'
tweets$source<- gsub(" ","",tweets$source)
tweets_count <-tweets %>% count(source)

write.xlsx(tweets, file = "Bdata.xlsx", colNames = TRUE, borders = "columns")
gap_ss <- gs_gap()
bernie_ss <- gs_read(gap_ss,ws = "BernieSanders_data")


