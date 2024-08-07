library(dplyr)

dataset <- "healthkitv2activitysummaries"

vars <- 
  selected_vars %>% 
  filter(grepl(dataset, Export, ignore.case = TRUE)) %>% 
  pull(Variable)

df <- 
  arrow::open_dataset(file.path(downloadLocation, glue::glue("dataset_{dataset}"))) %>% 
  select(all_of(vars)) %>% 
  collect()

colnames(df) <- tolower(colnames(df))

excluded_concepts <- c("participantidentifier", "startdate", "enddate")

approved_concepts_summarized <- 
  setdiff(
    tolower(selected_vars$Variable[selected_vars$Export==dataset]),
    excluded_concepts
  )

df[approved_concepts_summarized] <- lapply(df[approved_concepts_summarized], as.numeric)

bounds <- 
  selected_vars %>% 
  filter(grepl(dataset, Export, ignore.case = TRUE),
         tolower(Variable) %in% approved_concepts_summarized) %>% 
  select(Variable, Lower_Bound, Upper_Bound) %>% 
  mutate(Variable = tolower(Variable))

df_filtered <- df
for (col_name in names(df_filtered)) {
  if (col_name %in% bounds$Variable) {
    lower_bound <- bounds$Lower_Bound[bounds$Variable == col_name]
    upper_bound <- bounds$Upper_Bound[bounds$Variable == col_name]
    
    df_filtered[[col_name]] <- ifelse(df_filtered[[col_name]] < lower_bound |
                                        df_filtered[[col_name]] > upper_bound,
                                      NA,
                                      df_filtered[[col_name]])
  }
}

df_melted_filtered <- 
  df_filtered %>% 
  recoverutils::melt_df(excluded_concepts = excluded_concepts) %>% 
  select(if("participantidentifier" %in% colnames(.)) "participantidentifier",
         dplyr::matches("(?<!_)date(?!_)", perl = T),
         if("concept" %in% colnames(.)) "concept",
         if("value" %in% colnames(.)) "value") %>% 
  tidyr::drop_na("value") %>% 
  mutate(value = as.numeric(value))
cat("recoverutils::melt_df() completed.\n")

df_summarized <- 
  df_melted_filtered %>% 
  rename(startdate = dplyr::any_of(c("date", "datetime"))) %>% 
  mutate(enddate = if (!("enddate" %in% names(.))) NA else enddate) %>% 
  select(all_of(c("participantidentifier", "startdate", "enddate", "concept", "value"))) %>% 
  recoverutils::stat_summarize() %>% 
  distinct()
cat("recoverutils::stat_summarize() completed.\n")

output_concepts <- 
  recoverutils::process_df(df_summarized, concept_map, concept_replacements_reversed, concept_map_concepts = "CONCEPT_CD", concept_map_units = "UNITS_CD") %>% 
  dplyr::mutate(nval_num = signif(nval_num, 9)) %>% 
  dplyr::arrange(concept) %>% 
  dplyr::mutate(dplyr::across(.cols = dplyr::everything(), .fns = as.character)) %>% 
  replace(is.na(.), "<null>") %>% 
  dplyr::filter(nval_num != "<null>" | tval_char != "<null>")
cat("recoverutils::process_df() completed.\n")

output_concepts %>% 
  write.csv(file.path(outputConceptsDir, glue::glue("{dataset}.csv")), row.names = F)
cat(glue::glue("output_concepts written to {file.path(outputConceptsDir, '{dataset}.csv')}\n"))

rm(dataset,
   vars, 
   df, 
   excluded_concepts, 
   approved_concepts_summarized, 
   bounds,
   df_filtered,
   col_name,
   lower_bound,
   upper_bound,
   df_melted_filtered, 
   df_summarized, 
   output_concepts)
