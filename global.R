# 1. Automatic Package Checker & Installer ----------------------------------

cran_packages <- c("shiny",
                   "shinydashboard",
                   "tidyverse",
                   "pheatmap",
                   "data.table",
                   "DT")
bioc_packages <- c("DESeq2", "GEOquery", "EnhancedVolcano")

if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
}

install_cran <- function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE))
        install.packages(pkg, dependencies = TRUE)
}

install_bioc <- function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE))
        BiocManager::install(pkg, update = FALSE, ask = FALSE)
}

invisible(lapply(cran_packages, install_cran))
invisible(lapply(bioc_packages, install_bioc))

# 2. Load Libraries --------------------------------------------------------

library(shiny)
library(shinydashboard)
library(DESeq2)
library(tidyverse)
library(GEOquery)
library(pheatmap)
library(EnhancedVolcano)
library(data.table)
library(DT)

# 3. Helper Functions ------------------------------------------------------

options(shiny.maxRequestSize = 100 * 1024^2)

# Helper function to invoke native OS Folder Explorer
choose_folder_native <- function() {
    os_type <- .Platform$OS.type
    res_dir <- NULL
    
    if (os_type == "windows") {
        cmd <- 'powershell -command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; if($f.ShowDialog() -eq \'OK\'){ $f.SelectedPath }"'
        res_dir <- suppressWarnings(system(cmd, intern = TRUE))
    } else {
        if (Sys.info()["sysname"] == "Darwin") {
            cmd <- "osascript -e 'POSIX path of (choose folder with prompt \"Select or Create Project Folder\")'"
            res_dir <- suppressWarnings(system(cmd, intern = TRUE))
        } else {
            if (nzchar(Sys.which("zenity"))) {
                res_dir <- suppressWarnings(system(
                    "zenity --file-selection --directory",
                    intern = TRUE
                ))
            } else if (nzchar(Sys.which("kdialog"))) {
                res_dir <- suppressWarnings(system("kdialog --getexistingdirectory", intern = TRUE))
            } else {
                res_dir <- tryCatch({
                    tcltk::tk_choose.dir(caption = "Select Folder")
                }, error = function(e)
                    NULL)
            }
        }
    }
    
    if (length(res_dir) > 0 && nzchar(res_dir[1])) {
        return(trimws(res_dir[1]))
    } else {
        return(NULL)
    }
}

# Auto-create project subfolders
setup_project_folders <- function(base_path) {
    if (!dir.exists(base_path)) {
        dir.create(base_path, recursive = TRUE)
    }
    
    folders <- c("data", "figures", "results")
    created_paths <- sapply(folders, function(f) {
        p <- file.path(base_path, f)
        if (!dir.exists(p))
            dir.create(p, recursive = TRUE)
        return(p)
    })
    
    return(created_paths)
}