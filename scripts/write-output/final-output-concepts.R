cat("Creating final output concepts\n")

# Read each dataset's (intermediate) i2b2 output concepts CSV file, combine 
# them, and de-duplicate data if it already exists (fitbit data is highest 
# priority, then healthkit, then other)
datasets <- selected_vars$Export %>% unique()
datasets[datasets %in% c("fitbitdevices")] <- "participant_devices"

output_concepts <- 
  sapply(datasets, function(x) {
    output_concepts_path <- file.path(outputConceptsDir, paste0(x, ".csv"))
    if (file.exists(output_concepts_path)) {
      read.csv(output_concepts_path, 
               stringsAsFactors = F,
               tryLogical = F,
               colClasses = "character")
    }
  })

output_concepts <- output_concepts[lengths(output_concepts) > 0]

fitbit_dfs <- output_concepts[grep("fitbit", names(output_concepts))]
healthkit_dfs <- output_concepts[grep("healthkit", names(output_concepts))]
device_dfs <- output_concepts[grep("device", names(output_concepts))]

combined_fitbit <- bind_rows(fitbit_dfs)
combined_fitbit <- combined_fitbit[!duplicated(combined_fitbit), ]

combined_healthkit <- bind_rows(healthkit_dfs)
combined_healthkit <- combined_healthkit[!duplicated(combined_healthkit), ]

combined_device <- bind_rows(device_dfs)
combined_device <- combined_device[!duplicated(combined_device), ]

combined_output_concepts <- bind_rows(combined_device, 
                                      combined_fitbit, 
                                      combined_healthkit)
combined_output_concepts <- combined_output_concepts[!duplicated(combined_output_concepts), ]

valid_participants <- 
  read.csv(file.path(outputConceptsDir, "participant_devices.csv")) %>% 
  distinct(participantidentifier) %>% 
  pull()

combined_output_concepts <- 
  combined_output_concepts %>% 
  filter(participantidentifier %in% valid_participants) %>% 
  group_by(participantidentifier) %>% 
  mutate(startdate = ifelse(concept=="mhp:device", min(startdate[concept != "mhp:device"], na.rm = TRUE), startdate)) %>%
  ungroup()

combined_output_concepts %>% 
  write.csv(file.path(outputConceptsDir, "output_concepts.csv"), row.names = F)
cat(glue::glue("output_concepts written to {file.path(outputConceptsDir, 'output_concepts.csv')}"),"\n")

# Remove objects created here from the global environment
rm(datasets,
   output_concepts,
   fitbit_dfs,
   healthkit_dfs,
   device_dfs,
   combined_fitbit,
   combined_healthkit,
   combined_device,
   combined_output_concepts
)

cat("Finished creating final output concepts\n\n")
