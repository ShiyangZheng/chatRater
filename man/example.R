remotes::install_github("ShiyangZheng/chatRater")
library(chatRater)
library(tidyverse)

stim <- 'bare your soul'
stim_list <- list('buy the farm', 'beat the clock')

model <-'gpt-3.5-turbo'
prompt <- 'You are a native English speaker.'
question <- 'A list of idioms is given below.
            I would like to find out how close you think their literal meaning and figurative meanings are.
            Again, there are no right or wrong answers. I just want to know what you think about the idioms.
            Please read and rate each idiom according to the scale explained below.
            Circle the appropriate number following each idiom:
            1 = Literal and nonliteral meanings are closely related.
            2 = Literal and nonliteral meanings are somewhat related.
            3 = Literal and nonliteral meanings are not related.
            Please answer all of the questions. Try to work quickly but carefully. Please limit your answer to numbers.'
temp = 0
n_iterations = 1
api_key <- "xxxx"

generate_ratings(model, stim, prompt, question, temp, n_iterations, api_key)
res <- generate_ratings_for_all(model, stim_list, prompt, question, temp, n_iterations, api_key)

# write the results in a CSV file
write.csv(res, "idiom_ratings_30times.csv", row.names = FALSE)
