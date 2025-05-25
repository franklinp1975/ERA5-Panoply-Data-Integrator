# ERA5-Panoply-Data-Integrator

This R workflow automates the integration and processing of ERA5 monthly climate data exported from the Panoply data viewer. It takes multiple single-variable text files, merges them, performs unit conversions, and outputs a clean, unified dataset in Excel format.

## 🌦️ Overview

Climate data analysis often begins with data scattered across multiple files, each representing a different variable over time and space. This script addresses this challenge by providing a pipeline to:

1.  **Load** multiple `.txt` files containing ERA5 data.
2.  **Process** each file individually to extract relevant columns and format dates.
3.  **Merge** all individual datasets into a single `data.table`.
4.  **Transform** data by converting units (e.g., Kelvin to Celsius, m/day to mm/day) and encoding categorical variables (e.g., soil type).
5.  **Structure** the final dataset with a specific column order.
6.  **Export** the final integrated dataset to an `.xlsx` file.

## ✨ Features

* **Automated Loading:** Automatically installs and loads required R packages.
* **Directory Management:** Sets up input and output directories and cleans the output directory before processing.
* **Efficient Processing:** Uses the `data.table` package for fast data manipulation.
* **Robust File Handling:** Includes error handling for file processing.
* **Data Cleaning:** Formats dates, extracts day/month/year, and handles variable naming.
* **Unit Conversion:** Applies standard conversions for temperature and hydrological variables.
* **Categorical Encoding:** Converts numerical soil type codes into descriptive labels.
* **Unified Output:** Generates a single Excel file with all variables integrated.

## ⚙️ Prerequisites

* **R:** A working installation of R (version 4.x or later recommended).
* **R Packages:** The script will attempt to install the following packages if they are not already present:
    * `data.table`
    * `lubridate`
    * `stringr`
    * `openxlsx`
* **Input Data:** Tab-separated text files (`.txt`) exported from Panoply, containing ERA5 monthly data. Each file should represent one variable.
    * **Crucially**, all input files *must* have the same number of rows, and their `latitude`, `longitude`, and `valid_time` columns must align perfectly row by row.
    * The script assumes the actual data variable is in the **4th column** of each input file.
    * The data source mentioned is [ERA5 monthly averaged data on single levels from 1940 to present](https://goo.su/6XZSK).

## 🛠️ Setup & Configuration

1.  **Clone the Repository (if applicable):**
    ```bash
    git clone <your-repository-url>
    cd <your-repository-name>
    ```
2.  **Directory Structure:** Create the following directory structure:
    ```
    ONCC_panoply_integrater/
    ├── Input/
    ├── Outcome/
    └── 1_panoply_csv_integrator.R
    ```
    * Place all your `.txt` input files inside the `Input/` directory.
    * The script will create the output file in the `Outcome/` directory.
3.  **Environment Variable (Optional):** You can set an environment variable `ONCC_MAIN` to point to your main project directory. If not set, it defaults to `C:/ONCC_panoply_integrater`.
    ```R
    # Example in R
    Sys.setenv(ONCC_MAIN = "path/to/your/project/directory")
    ```

## 🚀 Usage

1.  **Open R or RStudio.**
2.  **Set your working directory** (or ensure the script can find the `ONCC_MAIN` path).
3.  **Run the script:**
    ```R
    source("1_panoply_csv_integrator.R")
    ```
4.  The script will:
    * Install necessary packages.
    * Clean the `Outcome/` directory.
    * Process each `.txt` file in `Input/`.
    * Merge the data.
    * Perform transformations.
    * Save `master_database.xlsx` in the `Outcome/` directory.
5.  Check the R console for progress messages and any potential warnings.

## 📜 Workflow Breakdown

1.  **Package Loading:** Ensures all required R packages are available.
2.  **Configuration:** Defines the main project directory and input/output subdirectories.
3.  **Helper Functions:**
    * `cleanMem()`: Performs garbage collection to free up memory.
    * `clean_directory()`: Removes files based on patterns (not used in the main pipeline but available).
    * `delete_contents()`: Clears a directory.
    * `process_era5_file()`: Reads a single `.txt` file, extracts the variable (4th column), formats the date, and selects key columns.
    * `split_date()`: Splits a date column into day, month, and year.
4.  **Main Processing:**
    * Identifies all `.txt` files in the input folder.
    * Clears any previous results from the output folder.
    * Iterates through each input file, processing it with `process_era5_file()`.
    * Merges the processed data tables. This assumes a consistent structure and order across all files, combining `date`, `lon`, `lat` from the first file with the variable columns from all files.
    * Adds `day`, `month`, and `year` columns.
    * Applies **Unit Corrections & Transformations**:
        * Temperatures: K to °C.
        * Soil Type: Numerical codes to text labels.
        * Hydrological variables: m/day to mm/day.
    * Reorders the columns into a predefined final structure.
    * Saves the `master_database` as an Excel file.
5.  **Cleanup:** Clears the R workspace and temporary files.

## 📊 Output

The script generates a single Excel file named `master_database.xlsx` within the `Outcome/` directory. This file contains a sheet named `ERA5_master_database` with the integrated, cleaned, and transformed data, ready for analysis. The columns are ordered as specified in the script.

---
