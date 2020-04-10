# make q12 ES response/driver matrix figures
# author(s): ctw
# initiated: apr 2020


# script purpose:
# make following figs:
## 1) word cloud response (or driver) variables
## 2) alluvial diagram ES driver to ES response to ES


# notes
# R package options for wordcloud:
# 1) base R-based: wordcloud, wordcloud2
# https://cran.r-project.org/web/packages/wordcloud/wordcloud.pdf
# tutorial: https://towardsdatascience.com/create-a-word-cloud-with-r-bde3e7422e8a

# 2) ggplot-based: ggwordcloud, ggwordcloud2
# https://cran.r-project.org/web/packages/ggwordcloud/vignettes/ggwordcloud.html
## > if use gg version, borrow ctw climate QA code to panel ggplots in same graphing window
## > ctw thinks ggwordcloud = more annoying (e.g. need to create col to angle words, but ctw also doesn't like base R plot functionality)

# Rpackage options for alluvial diagram:
# 1) base R-based: network3D, flipPlots, alluvial (see link in #2 below)
# network3D: https://www.displayr.com/sankey-diagrams-r/
# flipPlots: https://www.r-bloggers.com/how-to-create-sankey-diagrams-from-tables-data-frames-using-r/

# 2) ggplot-based: ggalluvial
# ak has used this and recommends
# https://www.r-bloggers.com/data-flow-visuals-alluvial-vs-ggalluvial-in-r-2/

# other:




# -- SETUP -----
rm(list=ls()) # clean up environment
library(tidyverse)
library(wordcloud)
#library(ggwordcloud)
library(ggalluvial)
options(stringsAsFactors = F)
na_vals <- c("NA", "NaN", ".", "", " ", NA, NaN)
theme_set(theme_classic())


# read in latest metareview data
rawdat <- read.csv("round2_metareview/data/cleaned/prelim_singlereview.csv", na.strings = na_vals)
# check read in as expected
glimpse(rawdat)


# function for breaking out comma separated answers
splitcom <- function(df, keepcols = c("Title", "answer")){
  df <- df[keepcols] %>%
    #dplyr::select_vars(keepcols) %>%
    distinct() %>%
    # break out answers by comma
    separate(answer, paste0("v",1:20), ",") %>% # <- this will throw warning, fine. pad with extra cols for up to 20 comma-separated answers just in case
    # remove cols that are all na
    dplyr::select(names(.)[sapply(., function(x) !(all(is.na(x))))]) %>%
    # gather to tidy
    gather(num, answer, v1:ncol(.)) %>%
    mutate(answer = trimws(answer)) %>%
    # make number of answers numeric
    mutate(num = parse_number(num)) %>%
    # remove any NAs in answer
    filter(!(is.na(answer)|answer %in% c("", " "))) # dat still tidy at this point
  return(df)
}

# for reference, ctw code for paneling ggplots in single window
# function to panel plot flagged data
#visual_qa <- function(dat, qadat, sorttime = "date", add_fourth = NA){
  # initiate list for storing ggplots
  plot_list <- list()
  # id temperature cols in reference data frame
  tempcols <- colnames(dat)[grepl("temp", colnames(dat))]
  
  for(m in c("airtemp_max", "airtemp_min")){
    tempdf <- qadat[qadat$met == m,] %>% as.data.frame()
    # order by preferred time sort (default is date)
    tempdf <- tempdf[order( tempdf[,which(colnames(tempdf) == sorttime)]),]
    
    for(d in as.character(tempdf$date)){
      d <- as.Date(d, format = "%Y-%m-%d")
      tempplot <- ggplot(data = subset(dat, met == m & date %in% seq(as.Date(d)-10, as.Date(d)+10, 1))) +
        geom_line(aes(date, main)) +
        geom_point(aes(date, main)) +
        # circle the flagged value in red
        geom_point(data = subset(dat, met == m & date == as.Date(d)),
                   aes(date, main), col = "red", pch  = 1, size = 3) +
        labs(y = gsub("airtemp_", "T", m),
             x = d) +
        # add sdl chart temp for comparison (purple dots)
        geom_line(aes(date, comp1), col = "purple") +
        geom_point(aes(date, comp1), col = "purple", pch = 1) +
        geom_line(aes(date, comp2), col = "steelblue2") +
        geom_point(aes(date, comp2), col = "steelblue4", pch = 1) +
        geom_line(aes(date, comp3), col = "forestgreen") +
        geom_point(aes(date, comp3), col = "darkgreen", pch = 1) +
        theme_bw()
      
      if(!is.na(add_fourth)){
        colnames(dat)[colnames(dat) == add_fourth] <- "comp4"
        tempplot <- tempplot + 
          geom_line(data = subset(dat, met == m & date %in% seq(as.Date(d)-10, as.Date(d)+10, 1)), 
                    aes(date, comp4), col = "goldenrod1") + 
          geom_point(data = subset(dat, met == m & date %in% seq(as.Date(d)-10, as.Date(d)+10, 1)), 
                     aes(date, comp4), col = "goldenrod1", pch = 1)
      }
      
      # store plot in a list
      plot_list[length(plot_list)+1] <- list(tempplot)
    }
  }
  return(plot_list)
}



# -- PREP DATA -----
# remove any titles that were excluded (yes in q3)
excludetitles <- with(rawdat, Title[(qnum == "Q3" & grepl("yes", answer, ignore.case = T))]) 
checkexcluded <- subset(rawdat, Title %in% excludetitles) # looks good
rm(checkexcluded)

# remove excluded papers
dat <- subset(rawdat, !Title %in% excludetitles)
# pull out q12 only
q12dat <- subset(dat, qnum == "Q12")



# -- FIGURES -----
# 1) WORD CLOUDS ----
# pull drivers info from q12
drivers <-  subset(q12dat, grepl("driver", abbr, ignore.case = T)) %>%
  # for now, ignore ES and "Other" entered in answer for abbr == "Driver" (should be entered in abbr "Other driver")
  filter(!(answer == "Other" | is.na(answer))) %>%
  # remove "Other" checked for abbr == "Driver"
  mutate(answer = gsub("Other,", "", answer),
         answer = gsub(",Other[,]?", "", answer),
         # also edit canned "Exploitation (hunting, fishing)" since it has a comma and will mess up counts
         answer = gsub("hunting, fishing)", "hunting or fishing)", answer),
         answer = trimws(casefold(answer))) #nailed it
# remove whitespace in answers and remove any blanks

# now trim cols and un-comma respnoses
drivers_summary <- splitcom(drivers, keepcols = c("Title", "ES", "Group", "answer")) %>%
  # rename Group factors
  #mutate(Group = recode(Group, "Anthro" = "Human", "Bio" = "Biotic", "Env" = "Environmental")) %>%
  arrange(answer)# ES for "OtherDriver" not supplied..
 
otherdrivers <- subset(q12dat, grepl("Other", answer)) %>%
  dplyr::select(Title, ES, Group, answer) %>% distinct() %>%
  rename_at(vars(ES, answer), function(x)paste0("other",x)) %>%
  left_join(subset(drivers_summary, Title %in% unique(otherdrivers$Title) & is.na(ES))) %>%
  # get rid of things that shouldn't have been split
  filter(!answer %in% (c("city 2])", "not esp)"))) %>%
  # filter any ES that didn't join for simplicity sake
  filter(!is.na(otherES)) # <--this doesn't work as expected, leaves some vars out (e.g. see Conservation tillage mitigates the negative effect of landscape simplification on biological control)
# i think that might happen when only one ES? may need to fill down.. revisit


# lump unique drivers by group, ignore ES for now..
drivers_grouped <- drivers_summary %>%
  mutate(Group = recode(Group, "Anthro" = "Human", "Bio" = "Biotic", "Env" = "Environmental")) %>%
  group_by(Group, answer) %>%
  summarise(count = length(Title)) %>%
  ungroup() %>%
  # clean up ESP text in answer
  mutate(answer = gsub(" [(]q17[)]", "", answer))


# make single word cloud
sort(sapply(split(response_summary3$yresponse, response_summary3$ES), function(x) length(unique(x))))
ES <- "SoilProtect"
response_summary_simple <- group_by(response_summary3, ES, yresponse) %>% summarise(count = sum(count)) %>% ungroup() %>%
  filter(yresponse != "")

# environmental drivers
png("round2_metareview/figs/envdrivers_wordcloud.png",width = 5, height = 5, units = "in", res = 300)
wordcloud(words = drivers_grouped$answer[drivers_grouped$Group == "Environmental"], freq = drivers_grouped$count[drivers_grouped$Group == "Environmental"], 
          min.freq = 1, max.words=200, random.order=FALSE,
          colors=brewer.pal(8, "Dark2")) # scale = c(2, 0.4),
title(sub = "Environmental Drivers")
dev.off()

# human drivers
png("round2_metareview/figs/humandrivers_wordcloud.png",width = 5, height = 5, units = "in", res = 300)
wordcloud(words = drivers_grouped$answer[drivers_grouped$Group == "Human"], freq = drivers_grouped$count[drivers_grouped$Group == "Human"], 
          min.freq = 1, max.words=200, random.order=FALSE,
          colors=brewer.pal(8, "Dark2")) # scale = c(2, 0.4),
title(sub = "Human Drivers")
dev.off()

# biotic drivers
png("round2_metareview/figs/bioticdrivers_wordcloud.png",width = 5, height = 5, units = "in", res = 300)
wordcloud(words = drivers_grouped$answer[drivers_grouped$Group == "Biotic"], freq = drivers_grouped$count[drivers_grouped$Group == "Biotic"], 
          min.freq = 1, max.words=200, scale = c(3, 0.5), random.order=FALSE,
          colors=brewer.pal(8, "Dark2")) # scale = c(2, 0.4),
title(sub = "Biotic Drivers")
dev.off()

par(mfrow = c(4,4))
for(v in unique(response_summary_simple$ES)){
  tempdat <- subset(response_summary_simple, ES == v)
  wordcloud(words = tempdat$yresponse, freq = tempdat$count, main = v, 
            min.freq = 1, scale = c(2, 0.4), max.words=200, random.order=FALSE, rot.per=0.35,
            colors=brewer.pal(8, "Dark2"))
  title(sub = v)
}

plot_clouds <- function(dat, splitvar){
  # initiate list for storing ggplots
  plot_list <- list()
  
  for(v in splitvar){
    tempdat <- subset(dat, ES == v)
    tempplot <- wordcloud(words = tempdat$yresponse, freq = tempdat$count, main = v, 
                          min.freq = 1, scale = c(2, 0.4), max.words=200, random.order=FALSE, rot.per=0.35,
                          colors=brewer.pal(8, "Dark2"))
    # store plot in a list
    plot_list[length(plot_list)+1] <- list(tempplot)
  }
  return(plot_list)
  
}

quartz()
responseclouds <- plot_clouds(response_summary_simple, unique(response_summary_simple$ES))
par(mfrow = c(1,1))
wordtest <- plot_grid(plotlist = responseclouds, nrow = 4, ncol = 4)
ggsave("figs/wordcloud_response.pdf", wordtest, scale = 3)

quartz()
ggplot(subset(response_summary_simple, ES %in% c("HabCreate", "CulturePsych")), aes(label = yresponse, size = count/5)) +
  geom_text_wordcloud(eccentricity = 1) +
  scale_size_area(max_size = 40) +
  theme_minimal() +
  facet_wrap(~ES)


# 2) ES DRIVERS FIG -------



# 3) ALLUVIAL DIAGRAM -----
