dataset <- c("fitbitdevices", "healthkitv2samples")

cat(paste0("\n----", glue::glue("Transforming data for datasets: {dataset[1]}, {dataset[2]}"), "----\n"))

# Get variables for this dataset
vars <- list(fitbitdevices = c("ParticipantIdentifier", 
                               "Device"),
             healthkitv2samples = c("ParticipantIdentifier", 
                                    "Device_Model", 
                                    "Device_Manufacturer"))

# Load the desired subset of this dataset in memory
df <- 
  lapply(dataset, function(x) {
    tmp <- vars[[x]]
    arrow::open_dataset(s3$path(str_subset(dataset_paths, x))) %>% 
      select(all_of(tmp)) %>% 
      dplyr::rename_with(tolower) %>% 
      collect()
  }) %>% 
  setNames(dataset)

# Get lists of participants that i2b2 summaries are already generated for and 
# add a variable to indicate device type
fitbit_participants <- read.csv(file.path(outputConceptsDir, "fitbit_participants.csv"))

df$fitbitdevices <- 
  df$fitbitdevices %>% 
  dplyr::filter(participantidentifier %in% fitbit_participants$participantidentifier) %>%
  dplyr::mutate(type = ifelse(is.na(device) | device == "", NA, "Fitbit"))

hk_participants <- read.csv(file.path(outputConceptsDir, "hk_participants.csv"))

df$healthkitv2samples <- 
  df$healthkitv2samples %>% 
  dplyr::filter(participantidentifier %in% hk_participants$participantidentifier) %>%
  dplyr::filter(device_model != "iPhone") %>% 
  mutate(type = case_when(device_manufacturer %in% c("Apple", "Apple Inc.") ~ "Apple Watch",
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
  mutate(value = case_when(
    stringr::str_detect(value, stringr::regex("Apple Watch", ignore_case = TRUE)) ~ "Apple Watch",
    stringr::str_detect(value, stringr::regex("Garmin", ignore_case = TRUE)) ~ "Garmin",
    stringr::str_detect(value, stringr::regex("Polar", ignore_case = TRUE)) ~ "Polar",
    stringr::str_detect(value, stringr::regex("HRM808S", ignore_case = TRUE)) ~ "HRM808S",
    .default = value
  )) %>% 
  filter(!stringr::str_detect(value, stringr::regex("Other", ignore_case = TRUE))) %>% 
  select(all_of(c("participantidentifier", "concept", "value"))) %>% 
  ungroup()

# Add i2b2 columns from concept map (ontology file) and clean the output
concept_map_concepts <- "CONCEPT_CD"
concept_map_units <- "UNITS_CD"
cat("recoverutils::process_df()....")
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
cat("OK\n")

# Write the output
output_concepts %>% 
  write.csv(file.path(outputConceptsDir, "participant_devices.csv"), row.names = F)
cat(glue::glue("participant_devices written to {file.path(outputConceptsDir, 'participant_devices.csv')}"), "\n")

cat("----Finished----\n")

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
