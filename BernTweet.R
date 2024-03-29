## load rtweet package
library(rtweet)
library(stringr)
library(dplyr)
library(tidyverse)
library(lubridate)
library(scales)
library(tidytext)
library(ggplot2)
library(ggmap)


## get user timeline
tmls <- get_timelines('BernieSanders', n = 3200)
glimpse(tmls)
tweets <- tmls %>% select(status_id, source, text, created_at, favorite_count, retweet_count) %>%
  filter(!tmls$is_retweet)
tweets <- mutate(tweets,source =ifelse(str_detect(tweets$source,'(?<=Twitter )[^.]*')==TRUE,str_match(tweets$source, '(?<=Twitter )[^.]*'), tweets$source))

#rename values for source column
tweets$source[tweets$source == 'for iPad'] <-'iPad'
tweets$source[tweets$source == 'for iPhone'] <-'iPhone'
tweets$source[tweets$source == 'for Android'] <-'Android'
tweets$source<- gsub(" ","",tweets$source)
tweets_count <-tweets %>% count(source)
tweets_count
tweets

#favorites
tweets[which.max(tweets$favorite_count), ]$text

tweets[which.min(tweets$favorite_count), ]$text
fav_tweets <- tweets %>% filter(favorite_count > mean(tweets$favorite_count))
fav_tweets$text


#retweet
tweets[which.max(tweets$retweet_count), ]$text
tweets[which.min(tweets$retweet_count), ]$text
re_tweets <- tweets %>% filter(retweet_count > mean(tweets$retweet_count))
re_tweets$text


#bar plot
tweets_count %>% ggplot(aes(y =n ,x =source, fill = source)) + 
  geom_bar(width = 1, stat = "identity")

#hourly
tweets %>%
  count(source, hour=hour(with_tz(created_at, "EST"))) %>%
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
# bar plot for picture/no picture
ggplot(tweet_picture_counts, aes(source, n, fill = picture)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(x = "", y = "Number of tweets", fill = "")

## hashtags
tweet_hashtag_counts <- tweets %>%
  unnest_tokens(word,text, token = 'tweets') %>%
  count(source, hashtag =ifelse(
    str_detect(word,'^#'), 'yes', 'no')) 

ggplot(tweet_hashtag_counts, aes(source, n, fill=hashtag)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(x = "", y = "Number of tweets", fill = "") 

tweets %>% 
  unnest_tokens(word,text, token = 'tweets') %>%
  filter(str_detect(word, '^#')) %>%
  count(word, sort = TRUE) %>% head(5)


glimpse(tweets)

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
common_words <- tweet_words %>% count(word, sort=TRUE) %>% head(.,20)
common_words %>% ggplot(aes(y =n ,x =reorder(word,+n))) +  
  ylab("Occurrences") + xlab('Word') +
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

tweet_words_count %>% filter(source %in% c('iPhone','TweetDeck')) %>% head(50) %>%
  ggplot(aes(y =n ,x =reorder(word,+n), fill=source)) + 
  geom_bar(width = 0.7, stat = "identity") + coord_flip()


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
  head(30)%>%
  group_by(source) %>%
  slice(1:15) %>%
  ggplot(aes(word, tf_idf, fill = source)) +
  geom_bar(alpha = 0.8, stat = "identity") +
  labs(title = "Highest tf-idf words in @BernieSanders",
       subtitle = "Top 15 ",
       x = NULL, y = "tf-idf") +
  coord_flip()

#tweet ratios
tweet_ratios <- tweet_words %>%
  count(word, source) %>%
  filter(sum(n) >= 5) %>%
  spread(source, n, fill = 0) %>%
  ungroup() %>%
  mutate_each(funs((. + 1) / sum(. + 1)), -word) %>%
  mutate(logratio = log2(iPhone/WebClient)) 
tweet_ratios

tweet_ratios %>%
  group_by(logratio > 0) %>%
  top_n(15, abs(logratio)) %>%
  ungroup() %>%
  mutate(word = reorder(word, logratio)) %>%
  ggplot(aes(word, logratio, fill = logratio < 0)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  ylab("iPhone / Web Client log ratio") +
  scale_fill_manual(name = "", labels = c("WebClient", "iPhone"),
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
wd <- getwd()
#wd <- "C:\\Users\\van\\Desktop\\Projects\\Twitter-Analysis"
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

# after july 2019
tweet_words%>% 
  inner_join(nrc, by = "word")  %>%
  count(emotion, month=date(created_at)) %>%
  filter(month > as.Date('2019-08-01')) %>%
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
  labs(x = "", y = "WebClient / iPhone log ratio") +
  scale_fill_manual(name = "", labels = c("WebClient", "iPhone"),
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
  scale_fill_manual(name = "", labels = c("WebClient", "iPhone",'MediaStudio',
                          'Periscope', 'TweetDeck','VITAppforiOS','WebApp'),
                    values = c("red", "lightblue","pink", "purple", "orange", 'yellow', "blue"))

tweet_important %>%
  inner_join(nrc, by = "word") %>%
  filter(!emotion %in% c("positive", "negative")) %>%
  filter(source %in% c("WebClient", "iPhone")) %>%
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
  scale_fill_manual(name = "", labels = c("WebClient", "iPhone"),
                    values = c("red", "lightblue"))


#library(broom)

#compare
library(reshape2)
library(wordcloud)

donfrump <- get_timelines('realDonaldTrump', n = 3200)
dft <- donfrump %>% select(status_id, source, text, created_at) 
dft <- mutate(dft,source =ifelse(str_detect(dft$source,'(?<=Twitter )[^.]*')==TRUE,str_match(dft$source, '(?<=Twitter )[^.]*'), dft$source))
dft
dft$source[dft$source == 'for iPad'] <-'iPad'
dft$source[dft$source == 'for iPhone'] <-'iPhone'
dft$source[dft$source == 'for Android'] <-'Android'
dft$source<- gsub(" ","",dft$source)

df_token <- dft %>% filter(!str_detect(text, '^"')) %>%
  mutate(text = str_replace_all(text, "https://t.co/[A-Za-z\\d]+|&amp;", "")) %>%
  unnest_tokens(word, text, token = "regex", pattern = reg) %>%
  filter(!word %in% stop_words$word,
         str_detect(word, "[a-z]"))

bind_rows(Bernie = tweet_words, Trump = df_token, .id = "person") %>%
  count(word, person) %>%
  acast(word ~ person, value.var = "n", fill = 0) %>%
  comparison.cloud(max.words = 100, colors = c("blue", "red"))

