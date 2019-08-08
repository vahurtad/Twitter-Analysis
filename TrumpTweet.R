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
tweets <- mutate(tweets,source =ifelse(str_detect(tweets$source,'(?<=Twitter )[^.]*')==TRUE,str_match(tweets$source, '(?<=Twitter )[^.]*'), tweets$source))
tweets
tweets$source[tweets$source == 'for iPad'] <-'iPad'
tweets$source[tweets$source == 'for iPhone'] <-'iPhone'
tweets$source[tweets$source == 'for Android'] <-'Android'
tweets$source<- gsub(" ","",tweets$source)
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
tweets

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
tweet_words
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

tweet_words_count <- tweet_words %>%
  count(source, word, sort = TRUE) %>%
  ungroup()
tweet_words_count

total_words <- tweet_words_count %>%
  group_by(source) %>%
  summarize(total = sum(n))
total_words

tweet_words_count <- left_join(tweet_words_count, total_words)
tweet_words_count

tweet_words_count <- tweet_words_count %>%
  bind_tf_idf(word, source, n)
tweet_words_count

tweet_words_count %>%
  select(-total) %>%
  arrange(desc(tf_idf))

tweet_important <- tweet_words_count %>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word))))
tweet_important

tweet_important %>%
  head(50)%>%
  group_by(source) %>%
  slice(1:15) %>%
  ggplot(aes(word, tf_idf, fill = source)) +
  geom_bar(alpha = 0.8, stat = "identity") +
  labs(title = "Highest tf-idf words in @realDonalTrump",
       subtitle = "Top 50 ",
       x = NULL, y = "tf-idf") +
  coord_flip()

#tweet ratios
tweet_ratios <- tweet_words %>%
  count(word, source) %>%
  filter(sum(n) >= 5) %>%
  spread(source, n, fill = 0) %>%
  ungroup() %>%
  mutate_each(funs((. + 1) / sum(. + 1)), -word) %>%
  mutate(logratio = log2(iPhone/MediaStudio)) 
tweet_ratios

tweet_ratios %>%
  group_by(logratio > 0) %>%
  top_n(15, abs(logratio)) %>%
  ungroup() %>%
  mutate(word = reorder(word, logratio)) %>%
  ggplot(aes(word, logratio, fill = logratio < 0)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  ylab("iPhone /Media Studio log ratio") +
  scale_fill_manual(name = "", labels = c("MediaStudio", "iPhone"),
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
### eight emotion (anger, fear, anticipation, trust, surprise, sadness,
### joy, and disgust) and two sentiment (negative and positive)

wd <- "C:\\Users\\vanea\\Desktop\\Projects\\Twitter\\DrumpfTweet"
emolex <- read_table2(
  file.path(wd,"NRC-emotion-lexicon-wordlevel-alphabetized-v0.92.txt"),
  col_names = FALSE,
  skip = 45)
colnames(emolex) <- c("word", "emotion", "value")
# remove values with 0
emolex <- emolex %>%  filter(value > 0)

nrc <-emolex %>%
  select(word, emotion)


#hourly
tweet_words %>% 
  inner_join(nrc, by = "word")%>%
  count(emotion, hour=hour(with_tz(created_at, "EST"))) %>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(hour, percent, color = emotion)) +
  geom_line() + geom_path(size = 1) +
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Hour of day (EST)",
       y = "% of tweets",
       color = "")

#weekly
tweet_words %>% 
  inner_join(nrc, by = "word")%>%
  count(emotion, week=week(with_tz(created_at, "EST"))) %>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(week, percent, color = emotion)) +
  geom_line() + geom_path(size = 1) +
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Week (EST)",
       y = "% of tweets",
       color = "")

#monthly
tweet_words %>% 
  inner_join(nrc, by = "word")%>%
  count(emotion, month=month(with_tz(created_at, "EST"))) %>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(month, percent, color = emotion)) +
  geom_line() +geom_path(size = 1)+
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Monthly (EST)",
       y = "% of tweets",
       color = "") 

tweet_words%>% 
  inner_join(nrc, by = "word")  %>%
  count(emotion, month=date(created_at))%>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(month, percent, color = emotion)) +
  geom_line() +
  scale_y_continuous(labels = percent_format()) +
  labs(x = "Monthly (EST)",
       y = "% of tweets",
       color = "") 

tweet_words%>% 
  inner_join(nrc, by = "word")  %>%
  count(emotion, month=date(created_at))%>%
  mutate(percent = n / sum(n)) %>%
  ggplot(aes(y=percent ,x =emotion, fill=month)) + 
  geom_bar(width = 0.7, stat = "identity") + coord_flip()

by_source_sentiment <- tweet_words %>%
  inner_join(nrc, by = "word") %>%
  count(emotion, status_id) %>%
  ungroup() %>%
  complete(emotion, status_id, fill = list(n = 0)) %>%
  inner_join(sources, "status_id") %>%
  group_by(source, emotion, total_words) %>%
  summarize(words = sum(n)) %>%
  ungroup()

head(by_source_sentiment)

by_source_sentiment %>%
  ggplot(aes(source, words,fill=emotion)) + 
  geom_bar(width = 0.7, stat = "identity") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

by_source_sentiment %>%
  ggplot(aes(emotion, words,fill=source)) + 
  geom_bar(width = 0.7, stat = "identity") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

tweet_ratios %>%
  inner_join(nrc, by = "word") %>%
  filter(!emotion %in% c("positive", "negative")) %>%
  mutate(emotion = reorder(emotion, -logratio),
         word = reorder(word, -logratio))%>% 
  group_by(emotion) %>%
  top_n(10, abs(logratio))%>%
  ungroup() %>%
  ggplot(aes(word, logratio, fill = logratio < 0)) +
  facet_wrap(~ emotion, scales = "free", nrow = 2) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x = "", y = "MediaStudio / iPhone log ratio") +
  scale_fill_manual(name = "", labels = c("iPhone", "MediaStudio"),
                    values = c("red", "lightblue"))

tweet_important %>%
  inner_join(nrc, by = "word") %>%
  filter(!emotion %in% c("positive", "negative")) %>%
  mutate(emotion = reorder(emotion, -tf_idf),
         word = reorder(word, -tf_idf)) %>%
  group_by(emotion) %>%
  top_n(10, tf_idf) %>%
  ungroup() %>%
  ggplot(aes(word, tf_idf, fill = source)) +
  facet_wrap(~ emotion, scales = "free", nrow = 4) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x = "", y = "tf-idf") +
  scale_fill_manual(name = "", labels = c("iPhone", "MediaStudio","iPad", "WebApp"),
                    values = c("red", "lightblue","pink", "purple"))
tweet_important %>%
  inner_join(nrc, by = "word") %>%
  filter(!emotion %in% c("positive", "negative")) %>%
  filter(source %in% c("MediaStudio", "iPhone")) %>%
  mutate(emotion = reorder(emotion, -tf_idf),
         word = reorder(word, -tf_idf)) %>%
  group_by(emotion) %>%
  top_n(10, tf_idf) %>%
  ungroup() %>%
  ggplot(aes(word, tf_idf, fill = source)) +
  facet_wrap(~ emotion, scales = "free", nrow = 4) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x = "", y = "tf-idf") +
  scale_fill_manual(name = "", labels = c("iPhone", "MediaStudio"),
                    values = c("red", "lightblue"))


