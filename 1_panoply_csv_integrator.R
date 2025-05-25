# This script organizes data from the Copernicus reanalysis, which has been extracted as CSV file in Panoply 
# Product name: ERA5 monthly averaged data on single levels from 1940 to present
# Dataset source: https://goo.su/6XZSK

# SECTION 1: PACKAGE LOADING ----
#///////////////////////////////////////////////////////////////////////////////
required_packages <- c(
  "data.table", "lubridate", "stringr", "openxlsx")
install_and_load <- function(pkgs) {
  to_install <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
  if (length(to_install) > 0) {
    install.packages(to_install, repos = "https://cloud.r-project.org")
  }
  invisible(lapply(pkgs, library, character.only = TRUE))
}
install_and_load(required_packages)

# SECTION 2: CONFIGURATION ----
#///////////////////////////////////////////////////////////////////////////////
# Define main directories
dir_main   <- normalizePath(Sys.getenv("ONCC_MAIN", "C:/ONCC_panoply_integrater"), mustWork = FALSE)
dir_config <- list(
  input  = file.path(dir_main, "Input"),
  output = file.path(dir_main, "Outcome")
)

# SECTION 3: PROCESSING FUNCTIONS ----
#///////////////////////////////////////////////////////////////////////////////
# Function to free the memory used by the R session
cleanMem <- function(n = 10) { for (i in 1:n) gc() }

# Function to clean up temporary files
clean_directory <- function(path, patterns) {
  files <- list.files(path, pattern = paste(patterns, collapse = "|"), full.names = TRUE)
  if (length(files) > 0) file.remove(files)
}

# Function to delete files and folders
delete_contents <- function(folder) {
  if (!dir.exists(folder)) stop("Folder does not exist: ", folder)
  all_items <- list.files(folder, full.names = TRUE)
  if (length(all_items) > 0) {
    unlink(all_items, recursive = TRUE, force = TRUE)
  }
}

# Function to extract data from the txt files
process_era5_file <- function(file_path) {
  cat("Processing file:", basename(file_path), "\n")

  # Attempt to read the file using fread for efficiency
  tryCatch({
    dt <- fread(file_path, header = TRUE, sep = "\t", check.names = TRUE) # `check.names=TRUE` handles special characters in headers

    # Identify the variable column. We assume it's the 4th column.
    if (ncol(dt) < 4) {
      warning(paste("File", basename(file_path), "has fewer than 4 columns. Skipping."))
      return(NULL)
    }
    
    # Extract variable name from the filename (e.g., "Escorrentía" from "Escorrentía.txt")
    variable_name <- tools::file_path_sans_ext(basename(file_path))
    variable_name <- make.names(variable_name) # Cleans the name

    # The actual data is assumed to be in the 4th column.
    original_var_col_name <- names(dt)[4]
    setnames(dt, old = original_var_col_name, new = variable_name)
    
    # Convert to date format
		date <- as.POSIXct(dt$valid_time, origin = "1970-01-01", tz = "UTC")
		
		# Format the date as day-month-year
		formatted_date <- format(date, "%d-%m-%Y")
		
    # Add day, month, year columns
    dt[, date := formatted_date]
    dt[, valid_time := NULL] # Remove the original timestamp column

    # Select and reorder columns: datetime, latitude, longitude, and the new variable column
    dt[, lat := as.numeric(dt$latitude)]
    dt[, lon := as.numeric(dt$longitude)]
    
    # Keep only the necessary columns
    cols_to_keep <- c("date", "lon", "lat", variable_name)
    dt <- dt[, ..cols_to_keep]

    cat("Successfully processed:", basename(file_path), "- Variable:", variable_name, "\n")
    return(dt)

  }, error = function(e) {
    warning(paste("Error processing file", basename(file_path), ":", e$message))
    return(NULL)
  })
}

# Function to split date into day, month, and year
split_date <- function(data, date_column) {
  # Convert the character date to a Date object
  data$date <- dmy(data[[date_column]])

  # Extract day, month, and year
  data$day <- day(data$date)
  data$month <- month(data$date)
  data$year <- year(data$date)

  # Remove the temporary date column
  data$date <- NULL

  return(data)
}

# //////////////////////////////////////////////////////////////////////////////
# SECTION 4: MAIN PROCESSING PIPELINE ----
# //////////////////////////////////////////////////////////////////////////////
# 4.1 Load Area of Interest
message("Loading txt files...")
txt_files  <- list.files(dir_config$input, pattern = "\\.txt$", full.names = TRUE)

# 4.2 Clear previous outputs
message("Cleaning output directory: ", dir_config$output)
delete_contents(dir_config$output)

# 4.3 Process each file and store the resulting data.tables in a list
message("Processing input data...")
list_of_data_tables <- lapply(txt_files, process_era5_file)
cat("\014");cleanMem()

# 4.4 Combine all data.tables into one
message("Merging processed files...\n")
# Extract the base data (first 3 columns) from the first table
master_dt <- list_of_data_tables[[1]][, 1:3]
# Extract the 4th column (the variable) from each table in the list
variable_cols_list <- lapply(list_of_data_tables, `[[`, 4)
# Extract the names for these variable columns (from the 4th column of each table)
variable_names <- sapply(list_of_data_tables, function(dt) names(dt)[4])
# Combine the list of variable columns into a single data.table
variables_dt <- as.data.table(variable_cols_list)
# Set the names for the newly combined variable columns
setnames(variables_dt, variable_names)
# Combine the base identifier columns with the variable columns
master_database <- cbind(master_dt, variables_dt)

# 4.5 Generate date for each row
master_database <- split_date(master_database, "date")

# 4.6 Correction of units per variable
cat("\014");cleanMem()
str(master_database)
master_database$Temperatura2m <- master_database$Temperatura2m - 273.15 # Convert from Kelvin to Celsius
master_database$TemperaturaSueloNivel1  <- master_database$TemperaturaSueloNivel1 - 273.15 # Convert from Kelvin to Celsius
master_database$TemperaturaSueloNivel2  <- master_database$TemperaturaSueloNivel2 - 273.15 # Convert from Kelvin to Celsius
master_database$TemperaturaSueloNivel3  <- master_database$TemperaturaSueloNivel3 - 273.15 # Convert from Kelvin to Celsius
master_database$TemperaturaSueloNivel4  <- master_database$TemperaturaSueloNivel4 - 273.15 # Convert from Kelvin to Celsius
master_database$TemperaturaSuperficieMar  <- master_database$TemperaturaSuperficieMar - 273.15 # Convert from Kelvin to Celsius
master_database$TipoSuelo <- ifelse(master_database$TipoSuelo == 0, "non-land", 
	ifelse(master_database$TipoSuelo == 1, "coarse", 
		ifelse(master_database$TipoSuelo == 2, "medium", 
			ifelse(master_database$TipoSuelo == 3, "medium_fine", 
				ifelse(master_database$TipoSuelo == 4, "fine", 
					ifelse(master_database$TipoSuelo == 5, "very_fine", 
						ifelse(master_database$TipoSuelo == 6, "organic", 
							ifelse(master_database$TipoSuelo == 7, "tropical organic", NA))))))))
master_database$Escorrentia <- master_database$Escorrentia * 1000 # Convert from m/day to mm/day
master_database$EscorrentiaSubsuperficial <- master_database$EscorrentiaSubsuperficial * 1000 # Convert from m/day to mm/day
master_database$EscorrentiaSuperficial <- master_database$EscorrentiaSuperficial * 1000 # Convert from m/day to mm/day
master_database$Evaporacion <- master_database$Evaporacion * 1000 # Convert from m/day to mm/day
master_database$EvaporacionPotencial <- master_database$EvaporacionPotencial * 1000 # Convert from m/day to mm/day
master_database$PrecipitacionTotal  <- master_database$PrecipitacionTotal * 1000 # Convert from m/day to mm/day

# 4.7 Reorder columns
setcolorder(master_database, c("lon", "lat", "day", "month", "year",
	"Temperatura2m", "TemperaturaSueloNivel1", "TemperaturaSueloNivel2", 
	"TemperaturaSueloNivel3", "TemperaturaSueloNivel4", "TemperaturaSuperficieMar",
	"TipoSuelo", "Escorrentia", "EscorrentiaSubsuperficial", 
	"EscorrentiaSuperficial", "Evaporacion", "EvaporacionPotencial",
	"PrecipitacionTotal","VolumenAguaSueloNivel1", "VolumenAguaSueloNivel2",
	"VolumenAguaSueloNivel3", "VolumenAguaSueloNivel4", "RadiacionSolar", 
	"PresionAtmosfericaSuperficial"))

# 4.8 Save the master database to a xlxs file
message("Saving the master database to an Excel file...")
output_file <- file.path(dir_config$output, "master_database.xlsx")

write.xlsx(master_database, output_file, overwrite = TRUE, 
	sheetName = "ERA5_master_database", tabColour = "blue",
	creator = "ONCC")

# //////////////////////////////////////////////////////////////////////////////
# End of script
# //////////////////////////////////////////////////////////////////////////////
rm(list = ls());cat("\014")
d <- tempfile();dir.create(d);setwd(d);unlink("d", recursive=TRUE);rm(d)
quit(save = "no", status = 0)
