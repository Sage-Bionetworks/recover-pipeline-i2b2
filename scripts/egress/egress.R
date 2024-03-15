cat("Beginning egress: storing output concepts, input concept map, and input variable list in Synapse\n")

synapser::synLogin()

# Write the following to Synapse: 1) the final output concepts data, 2) the input data used in this pipeline
latest_commit <- 
  gh::gh(
    endpoint = "/repos/:owner/:repo/commits/prod", 
    owner = "Sage-Bionetworks", 
    repo = "recover-pipeline-i2b2"
  )

latest_commit_tree_url <- 
  latest_commit$html_url %>% 
  stringr::str_replace("commit", "tree")

recoverSummarizeR::store_in_syn(
  synFolderID = synFolderID, 
  filepath = file.path(outputConceptsDir, "output_concepts.csv"), 
  used_param = c(ontologyFileID, parquetDirID, selectedVarsFileID), 
  executed_param = latest_commit_tree_url
)
cat(glue::glue("Output concepts stored at {synFolderID}"), "\n\n")

file_name <- "concepts_map.csv"
write.csv(concept_map, file = file_name, row.names = F)
store_in_syn(synFolderID, file_name, used_param = ontologyFileID)
cat(glue::glue("The input concept map used was stored at {synFolderID} as '{file_name}'"), "\n\n")

file_name <- "selected_vars.csv"
write.csv(selected_vars, file = file_name, row.names = F)
store_in_syn(synFolderID, file_name, used_param = selectedVarsFileID)
cat(glue::glue("The input variable list used was stored at {synFolderID} as '{file_name}'"), "\n\n")

rm(latest_commit,
   latest_commit_tree_url,
   file_name
)

cat("Finished egress\n\n")