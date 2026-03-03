library(targets)
library(crew)
library(tarchetypes)

dotenv::load_dot_env()
ncpus <- future::availableCores() - 1

# Ensure single threaded within targets
Sys.setenv(R_DATATABLE_NUM_THREADS = 1)
Sys.setenv(OMP_NUM_THREADS = 1)
Sys.setenv(MKL_NUM_THREADS = 1)
Sys.setenv(OPENBLAS_NUM_THREADS = 1)

# Set target options:
tar_option_set(
  packages = c(
    "data.table",
    "Hmisc",
    "compositions",
    "mice",
    "ggplot2",
    "rms",
    "survival"
  ),
  controller = crew_controller_local(
    workers = ncpus
  ),
  format = "qs",
  seed = 20260202
)

# Run the R scripts in the R/ folder
tar_source()

## pipeline
list(
)
