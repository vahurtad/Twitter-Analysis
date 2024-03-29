## load rtweet package
library(rtweet)
library(stringr)
library(dplyr)
library(tidyverse)
library(lubridate)
library(scales)
library(tidytext)


## get user timeline
tmls <- get_timelines('realDonaldTrump', n = 3200)
tweets <- tmls %>% select(status_id, source, text, created_at) 
tweets <- mutate(tweets,source =str_match(tweets$source, '(?<=Twitter )[^.]*'))
tweets
tweets$source[tweets$source == 'for iPad'] <-'iPad'
tweets$source[tweets$source == 'for iPhone'] <-'iPhone'
tweets$source[tweets$source == 'for Android'] <-'Android'
tweets_count <-tweets %>% count(source)
tweets_count

#bar plot
tweets_count %>% ggplot(aes(y =n ,x =source, fill = source)) + 
  geom_bar(width = 1, stat = "identity")

#hourly
tweets %>%
  count(source, hour=hour(with_tz(created_at, "EST")))%>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(hour, percent, color = source)) +
  geom_line() +
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Hour of day (EST)",
       y = "% of tweets",
       color = "")
#quotes
tweet_picture_counts <- tweets %>%
  filter(!str_detect(text, '^"')) %>%
  count(
    source, 
    picture = ifelse(
      str_detect(text, "t.co"),"Picture/link", "No picture/link"))

ggplot(tweet_picture_counts, aes(source, n, fill = picture)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(x = "", y = "Number of tweets", fill = "")


#word sentiment
##separate into individual tokens
reg <- "([^A-Za-z\\d#@']|'(?![A-Za-z\\d#@]))"
tweet_words <- tweets %>%
  filter(!str_detect(text, '^"')) %>%
  mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
  unnest_tokens(word, text, token = "regex", pattern = reg) %>%
  filter(!word %in% stop_words$word,
         str_detect(word, "[a-z]"))

common_words <- tweet_words %>% count(word, sort=TRUE) %>% head(.,45)
common_words %>% ggplot(aes(y =n ,x =reorder(word,+n))) + 
  geom_bar(width = 0.7, stat = "identity") + coord_flip()

tweet_words %>%
  count(word, sort = TRUE) %>%
  head(20) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word, n)) +
  geom_bar(stat = "identity") +
  ylab("Occurrences") +
  coord_flip()

#tweet ratios
tweet_ratios <- tweet_words %>%
  count(word, source) %>%
  filter(sum(n) >= 5) %>%
  spread(source, n, fill = 0) %>%
  ungroup() %>%
  mutate_each(funs((. + 1) / sum(. + 1)), -word) %>%
  mutate(logratio = log2(iPhone/iPad)) %>%
  arrange(desc(logratio))

tweet_ratios %>%
  group_by(logratio > 0) %>%
  top_n(15, abs(logratio)) %>%
  ungroup() %>%
  mutate(word = reorder(word, logratio)) %>%
  ggplot(aes(word, logratio, fill = logratio < 0)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  ylab("iPhone / iPad log ratio") +
  scale_fill_manual(name = "", labels = c("iPad", "iPhone"),
                    values = c("red", "lightblue"))


#analysis
sources <- tweet_words %>%
  group_by(source) %>%
  mutate(total_words = n()) %>%
  ungroup() %>%
  distinct(status_id, source, total_words)

sources[order(sources$total_words, decreasing = TRUE),]

tweet_words %>%
  group_by(source)%>%
  mutate(total_words = n())%>%
  ungroup() %>%
  distinct(status_id, source, total_words) 


#website down, download from http://saifmohammad.com/Lexicons/
wd <- "C:\\Users\\vanea\\Desktop\\Projects\\Twitter\\DrumpfTweet"
emolex <- read_table2(
  file.path(wd,"NRC-emotion-lexicon-wordlevel-alphabetized-v0.92.txt"),
  col_names = FALSE,
  skip = 45)
colnames(emolex) <- c("word", "sentiment", "value")
nrc <-emolex %>%
  select(word, sentiment)

by_source_sentiment <- tweet_words %>%
  inner_join(nrc, by = "word") %>%
  count(sentiment, status_id) %>%
  ungroup() %>%
  complete(sentiment, status_id, fill = list(n = 0)) %>%
  inner_join(sources) %>%
  group_by(source, sentiment, total_words) %>%
  summarize(words = sum(n)) %>%
  ungroup()

head(by_source_sentiment)

library(broom)

sentiment_differences <- by_source_sentiment %>%
  group_by(sentiment) %>%
  do(tidy(poisson.test(.$words, .$total_words)))

sentiment_differences


by_source_sentiment %>%
  group_by(sentiment) %>%
  do(tidy(poisson.test(.$words, .$total_words)))







