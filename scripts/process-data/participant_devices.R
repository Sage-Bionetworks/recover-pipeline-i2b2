library(dplyr)

dataset <- c("fitbitdevices", "healthkitv2samples")

cat(glue::glue("Transforming device data for {dataset}"),"\n")

# Get variables for this dataset
vars <- list(fitbitdevices = c("ParticipantIdentifier", 
                               "Device"),
             healthkitv2samples = c("ParticipantIdentifier", 
                                    "Device_Model", 
                                    "Device_Manufacturer"))

# Load the desired subset of this dataset in memory
df <- 
  sapply(dataset, function(x) {
    tmp <- vars[[x]]
    arrow::open_dataset(file.path(downloadLocation, glue::glue("dataset_{x}"))) %>% 
      select(all_of(tmp)) %>% 
      collect()
  })

df <- 
  lapply(df, function(x) {
    colnames(x) <- tolower(colnames(x))
    return(x)
  })

# Get lists of participants that i2b2 summaries are already generated for and 
# add a variable to indicate device type
fitbit_participants <- read.csv(file.path(outputConceptsDir, "fitbit_participants.csv"))

df$fitbitdevices <- 
  df$fitbitdevices %>% 
  dplyr::filter(participantidentifier %in% fitbit_participants$participantidentifier) %>%
  dplyr::mutate(type = ifelse(is.na(device) | device == "", NA, "fitbit"))

hk_participants <- read.csv(file.path(outputConceptsDir, "hk_participants.csv"))

df$healthkitv2samples <- 
  df$healthkitv2samples %>% 
  dplyr::filter(participantidentifier %in% hk_participants$participantidentifier) %>%
  mutate(type = case_when(device_manufacturer %in% c("Apple", "Apple Inc.") ~ "Apple",
                          device_manufacturer %in% c("Garmin") ~ "Garmin",
                          device_manufacturer %in% c("Polar Electro Oy") ~ "Polar",
                          device_model %in% c("HRM808S") ~ "HRM808S",
                          .default = "Other"))

# Merge the fitbit and healthkit device data frames above into a single data 
# frame and summarise the unique device types for each participant into i2b2 summary format
df_joined <- 
  bind_rows(df$fitbitdevices %>% 
              select(all_of(c("participantidentifier", "type"))), 
            df$healthkitv2samples %>% 
              select(all_of(c("participantidentifier", "type")))) %>% 
  group_by(participantidentifier) %>% 
  summarise(type = toString(sort(unique(type)))) %>% 
  mutate(concept = "mhp:device") %>% 
  rename(value = type) %>% 
  select(all_of(c("participantidentifier", "concept", "value"))) %>% 
  ungroup()

# Add i2b2 columns from concept map (ontology file) and clean the output
concept_map_concepts <- "CONCEPT_CD"
concept_map_units <- "UNITS_CD"
output_concepts <- 
  df_joined %>% 
  dplyr::mutate(valtype_cd = dplyr::case_when(class(value) == "numeric" ~ "N", 
                                              class(value) == "character" ~ "T")) %>%
  dplyr::mutate(nval_num = as.numeric(dplyr::case_when(valtype_cd == "N" ~ value)),
                tval_char = as.character(dplyr::case_when(valtype_cd == "T" ~ value))) %>%
  dplyr::select(dplyr::setdiff(names(.), "value")) %>%
  dplyr::left_join(dplyr::select(concept_map, dplyr::all_of(c(concept_map_concepts, concept_map_units))),
                   by = c("concept" = concept_map_concepts)) %>% 
  tidyr::drop_na(valtype_cd) %>% 
  dplyr::arrange(concept) %>% 
  dplyr::mutate(dplyr::across(.cols = dplyr::everything(), .fns = as.character)) %>% 
  replace(is.na(.), "<null>") %>% 
  dplyr::filter(nval_num != "<null>" | tval_char != "<null>") %>% 
  mutate(startdate = "<null>", enddate = "<null>") %>% 
  dplyr::select(participantidentifier, startdate, enddate, 
                concept, valtype_cd, nval_num, tval_char, UNITS_CD) %>% 
  dplyr::rename(units_cd = UNITS_CD)
cat("recoverSummarizeR::process_df() completed.\n")

# Write the output
output_concepts %>% 
  write.csv(file.path(outputConceptsDir, "participant_devices.csv"), row.names = F)
cat(glue::glue("participant_devices written to {file.path(outputConceptsDir, 'participant_devices.csv')}"), "\n")

cat(glue::glue("Finished tansforming device data for {dataset}"),"\n\n")

# Remove objects created here from the global environment
rm(dataset,
   vars,
   df,
   fitbit_participants,
   hk_participants,
   df_joined,
   concept_map_concepts, 
   concept_map_units,
   output_concepts)
