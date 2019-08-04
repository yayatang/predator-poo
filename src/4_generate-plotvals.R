library(tidyverse)
library(plotly)
source(here::here('src/yaya_fxns.R'))

imported_data <- readRDS("results/3_data_to_graph.rds") %>% 
  filter(trt != 'R')
trt_key <- unique(imported_data$trt)

#========
# all_plots <- function(graph_data, max_p1) {

# rename vars for clarity
graph_data <- imported_data %>% 
  filter(trt!='WN')
# rename(tube_net = tube_diff,
#        infer_tube_daily_gross = infer_tube_total_daily,
#        infer_tube_daily_net = infer_tube_diff_daily,
#        by.tube_cumul_gross = by_tube_total_cumul,
#        by.trt_daily_gross = by_trt_daily_mean,
#        by.trt_daily_se = by_trt_daily_se,
#        by.trt_cumul_gross = by_trt_cumul_mean,
#        by.trt_cumul_se = by_trt_cumul_se)

# graph_data <- imported_data %>% 
#   filter(trt== 'MA' | trt=='WA')

#=====
# prepping data into two tables for graphing
# tube table
# 0) daily values ready
# 1) calculate cumulative vals, 
# 2) calculate phase cumulative vals

by_tube <- graph_data %>%
  group_by(tubeID) %>%
  arrange(exp_count) %>%
  mutate(cumul_gross = order_by(exp_count, cumsum(infer_tube_total_daily)),
         cumul_diff = order_by(exp_count, cumsum(infer_tube_diff_daily))) %>%
  rename(tube_se = ctrl_se) %>% # *** check cumul variable names
  group_by(tubeID, phase) %>%
  mutate(cumul_phase_gross = order_by(exp_count, cumsum(infer_tube_total_daily)),
         cumul_phase_diff = order_by(exp_count, cumsum(infer_tube_diff_daily))) %>% 
  ungroup()

saveRDS(by_tube, here::here('results/4_tubes_to_plot.rds'))

#------------------------------------

# treatment table
# 1) generate mean daily gross values, and se by treatment
# 2) sum up cumulative values by phase and by exp_count
tubes_meta <- unique(by_tube[,c('trt', 'ghop_fate', 'exp_count', 'real_data')])

# filter (inferred) daily data for control tubes only
c_tube_daily <- by_tube %>% 
  filter(trt == 'C') %>% 
  rename(c_daily_gross = infer_tube_total_daily,
         c_cumul_gross = by_tube_total_cumul, # c_cumul_phase = cumul_phase_gross,
         c_daily_se = tube_se) %>% 
  select(tubeID, ghop_fate, trt, exp_count, phase, phase_count, real_data, 
         c_daily_gross, c_cumul_gross, c_daily_se) %>% 
  ungroup() %>% 
  add_phase()


 # calculate avg control tube daily values
c_trt_daily <- c_tube_daily %>%
  group_by(trt, exp_count) %>%
  # summarise(c_daily_mean = mean(c_daily_gross))
  summarise_each(list(~mean(., na.rm=TRUE), ~se), c_daily_gross) %>% 
  rename(c_daily_mean = mean,
         c_daily_se = se)

# calculate avg cumulative CO2 for control tubes
c_trt_cumul <- c_tube_daily%>% 
  group_by(trt, exp_count) %>% 
  summarise_each(list(~mean(., na.rm=TRUE), ~se), c_cumul_gross) %>% 
  rename(c_cumul_mean = mean,
         c_cumul_se = se) %>% 
  ungroup()

# merge cumulative values with daily values for a mega control table
c_trt_summarized <- c_trt_cumul %>% 
  left_join(tubes_meta) %>% 
  left_join(c_trt_daily) %>%
  select(-trt)

by_trt_daily <- by_tube %>% 
  group_by(trt, exp_count) %>% 
  summarise_each(list(~mean(., na.rm=TRUE), ~se), infer_tube_total_daily) %>% 
  rename(trt_daily_gross = mean,
         trt_daily_se = se) %>% 
  left_join(c_trt_summarized)

by_trt_cumul <- by_tube %>% 
  group_by(trt, exp_count) %>% 
  summarise_each(list(~mean(., na.rm=TRUE), ~se), cumul_gross) %>% 
  rename(trt_cumul_gross = mean,
         trt_cumul_se = se)

trt_summ <- full_join(by_trt_daily, by_trt_cumul) 
trt_summ <- trt_summ %>% 
  left_join(tubes_meta) 

trt_summ <- trt_summ %>%
  left_join(c_trt_cumul) %>%  # merge control trt data
  mutate(trt_daily_net = trt_daily_gross - c_daily_mean,
         trt_cumul_net = trt_cumul_gross - c_cumul_mean) %>% 
  select(trt, exp_count, ghop_fate, everything()) %>% 
  ungroup()

trt_summ[trt_summ$real_data == FALSE,]$c_cumul_se <- NA
trt_summ[trt_summ$real_data == FALSE,]$trt_daily_se <- NA
trt_summ[trt_summ$real_data == FALSE,]$trt_cumul_se <- NA

saveRDS(trt_summ, here::here('results/4_trts_to_plot.rds'))