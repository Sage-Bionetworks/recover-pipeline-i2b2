# Fetch data
tictoc::tic(msg = "INFO: Fetch data")
source("scripts/fetch-data/fetch_data.R")
tictoc::toc()

# Process data
tictoc::tic(msg = "INFO: Process data")
source("scripts/process-data/fitbitactivitylogs.R")
source("scripts/process-data/fitbitdailydata.R")
source("scripts/process-data/fitbitintradaycombined.R")
source("scripts/process-data/fitbitsleeplogs.R")
source("scripts/process-data/healthkitv2samples.R")
source("scripts/process-data/healthkitv2statistics.R")
source("scripts/process-data/participant_devices.R")
tictoc::toc()

# Create final output concepts
tictoc::tic(msg = "INFO: Create final output concepts")
source("scripts/write-output/final-output-concepts.R")
tictoc::toc()

# Egress
tictoc::tic(msg = "INFO: Store in Synapse")
source("scripts/egress/egress.R")
tictoc::toc()
