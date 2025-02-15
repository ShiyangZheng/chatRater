# chatRater
 A Tool for Rating Text Using Large Language Models
 
# How to install chatRater?
```
remotes::install_github("ShiyangZheng/chatRater")
```

# How to use it?
See folder: _man/example.R_ for details.

```
remotes::install_github("ShiyangZheng/chatRater")

library(tidyverse)
library(chatRater)

stim <- 'bare your soul'
stim_list <- list('buy the farm', 'beat the clock')

model <-'gpt-4' # or 'deepseek-chat'
prompt <- 'You are a native English speaker.'
question <- 'A list of idioms is given below.
            To what extent do you agree with the following statement:
            The figurative meaning of this idiom had a lot in common with its literal meaning.
            Please rate according to the 5-point scale explained below.
            1 = Completely disagree;
            3 = Neither agree nor disagree;
            5 = Fully agree.
            Please limit your answer to numbers.'
top_p <- 1
temp <- 0
n_iterations <- 5
api_key <- ""

set.seed(56475764)

res <- generate_ratings(model, stim, prompt, question, top_p, temp, n_iterations, api_key)
res1 <- generate_ratings_for_all(model, stim_list, prompt, question, top_p, temp, n_iterations, api_key)

# write the results in a CSV file
write.csv(res, "idiom_ratings_3.csv", row.names = FALSE)
write.csv(res1, "idiom_ratings_4.csv", row.names = FALSE)
```
# An alternative
You can also experience all the functionalities of chatRater in an interactive Rshiny app.

> (chatRaterShiny)[https://shiyangzheng.shinyapps.io/chatRaterShiny/]


# Citation info
To cite package ‘chatRater’ in publications use:

  > Zheng, S. (2025). _chatRater: A Tool for Rating Text Using Large Language Models (Version 1.0.0)_ [R package]. Retrieved from https://github.com/ShiyangZheng/chatRater


A BibTeX entry for LaTeX users is

  > @Manual{,
    title = {chatRater: A Tool for Rating Text Using Large Language Models},
    author = {Shiyang Zheng},
    year = {2025},
    note = {R package version 1.0.0},
  }

