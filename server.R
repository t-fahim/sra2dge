function(input, output, session) {
    # Reactive storage object
    rv <- reactiveValues(
        base_dir = NULL,
        counts = NULL,
        meta = NULL,
        dds = NULL,
        res = NULL,
        res_df = NULL,
        contrasts_list = list()
    )
    
    # 1. Native OS Explorer Listener
    observeEvent(input$btn_open_native_explorer, {
        chosen_path <- choose_folder_native()
        
        if (!is.null(chosen_path) && dir.exists(chosen_path)) {
            rv$base_dir <- chosen_path
            paths <- setup_project_folders(chosen_path)
            
            output$dir_status <- renderText({
                paste0(
                    "Selected Working Directory: ",
                    chosen_path,
                    "\n\n",
                    "Subfolders auto-created/verified:\n",
                    " - Data Folder:    ",
                    paths["data"],
                    "\n",
                    " - Figures Folder: ",
                    paths["figures"],
                    "\n",
                    " - Results Folder: ",
                    paths["results"]
                )
            })
            
            showNotification("Folder set! Project directories created.", type = "message")
        }
    })
    
    # Helper function to auto-save matrices directly into data/
    auto_save_data <- function(counts_df,
                               meta_df,
                               counts_geo_id = NULL,
                               meta_geo_id = NULL) {
        target_dir <- if (!is.null(rv$base_dir))
            file.path(rv$base_dir, "data")
        else
            "data"
        if (!dir.exists(target_dir))
            dir.create(target_dir, recursive = TRUE)
        
        if (!is.null(counts_df)) {
            prefix <- if (!is.null(counts_geo_id))
                paste0(counts_geo_id, "_counts")
            else
                "uploaded_counts"
            write.csv(counts_df,
                      file.path(target_dir, paste0(prefix, ".csv")),
                      row.names = TRUE)
        }
        
        if (!is.null(meta_df)) {
            prefix <- if (!is.null(meta_geo_id))
                paste0(meta_geo_id, "_metadata")
            else
                "uploaded_metadata"
            write.csv(meta_df,
                      file.path(target_dir, paste0(prefix, ".csv")),
                      row.names = TRUE)
        }
    }
    
    # 2. Universal Data Processing (With Smart Remapping for Dots/Hyphens/GEO Accessions)
    observeEvent(input$btn_process_dataset, {
        counts_geo_used <- NULL
        meta_geo_used <- NULL
        
        withProgress(message = "Processing dataset inputs...", value = 0.1, {
            # --- A. PROCESS COUNTS MATRIX ---
            if (input$counts_src_type == "geo") {
                req(input$counts_geo_id)
                counts_geo_used <- input$counts_geo_id
                incProgress(0.3,
                            detail = paste(
                                "Fetching counts from GEO:",
                                input$counts_geo_id
                            ))
                
                download_target <- if (!is.null(rv$base_dir))
                    file.path(rv$base_dir, "data")
                else
                    tempdir()
                if (!dir.exists(download_target))
                    dir.create(download_target, recursive = TRUE)
                
                supp_files <- getGEOSuppFiles(
                    input$counts_geo_id,
                    makeDirectory = FALSE,
                    baseDir = download_target
                )
                count_file_path <- rownames(supp_files)[grep("count", rownames(supp_files), ignore.case = TRUE)][1]
                
                if (is.na(count_file_path)) {
                    count_file_path <- rownames(supp_files)[1]
                }
                
                counts_data <- fread(count_file_path, data.table = FALSE)
                rownames(counts_data) <- counts_data[[1]]
                counts_data <- counts_data[, -1]
                counts_data <- counts_data[, order(colnames(counts_data))]
                rv$counts <- counts_data
                
            } else {
                req(input$counts_file)
                incProgress(0.3, detail = "Reading uploaded counts file...")
                
                df_c <- fread(input$counts_file$datapath, data.table = FALSE)
                rownames(df_c) <- df_c[[1]]
                df_c <- df_c[, -1]
                df_c <- df_c[, order(colnames(df_c))]
                rv$counts <- df_c
            }
            
            # --- B. PROCESS METADATA ---
            if (input$meta_src_type == "geo") {
                req(input$meta_geo_id)
                meta_geo_used <- input$meta_geo_id
                incProgress(0.3,
                            detail = paste(
                                "Fetching metadata from GEO:",
                                input$meta_geo_id
                            ))
                
                gse <- getGEO(input$meta_geo_id, GSEMatrix = TRUE)
                pheno <- pData(gse[[1]])
                rv$meta <- pheno
                
            } else {
                req(input$meta_file)
                incProgress(0.3, detail = "Reading uploaded metadata file...")
                
                df_m <- fread(input$meta_file$datapath, data.table = FALSE)
                rownames(df_m) <- df_m[[1]]
                df_m <- df_m[, -1]
                rv$meta <- df_m
            }
            
            # --- C. ROBUST AUTOMATIC SAMPLE RE-MAPPING ---
            if (!is.null(rv$counts) && !is.null(rv$meta)) {
                cnt_cols <- colnames(rv$counts)
                
                clean_str <- function(x)
                    gsub("[^a-zA-Z0-9]", "", tolower(x))
                clean_cnt_cols <- clean_str(cnt_cols)
                
                candidate_cols <- c(
                    "title",
                    "geo_accession",
                    "description",
                    "sample_id",
                    "Sample_Name"
                )
                candidate_cols <- intersect(candidate_cols, colnames(rv$meta))
                
                matched_col <- NULL
                
                if (all(clean_cnt_cols %in% clean_str(rownames(rv$meta)))) {
                    names_map <- setNames(rownames(rv$meta), clean_str(rownames(rv$meta)))
                    rownames(rv$meta) <- names_map[clean_cnt_cols]
                } else {
                    for (col in candidate_cols) {
                        col_vals <- clean_str(as.character(rv$meta[[col]]))
                        if (all(clean_cnt_cols %in% col_vals)) {
                            matched_col <- col
                            break
                        }
                    }
                    
                    if (!is.null(matched_col)) {
                        matched_indices <- match(clean_cnt_cols,
                                                 clean_str(as.character(rv$meta[[matched_col]])))
                        rv$meta <- rv$meta[matched_indices, , drop = FALSE]
                        rownames(rv$meta) <- colnames(rv$counts)
                    }
                }
                
                if (all(colnames(rv$counts) %in% rownames(rv$meta))) {
                    rv$meta <- rv$meta[colnames(rv$counts), , drop = FALSE]
                }
            }
            
            # --- D. AUTO SAVE MATRICES TO DATA/ ---
            incProgress(0.2, detail = "Saving dataset files to project data/ folder...")
            auto_save_data(rv$counts,
                           rv$meta,
                           counts_geo_id = counts_geo_used,
                           meta_geo_id = meta_geo_used)
        })
        
        showNotification("Dataset loaded & re-aligned successfully!", type = "message")
        updateTabItems(session, "sidebar", "tab_overview")
    })
    
    # 3. Dynamic Top Navigation / Warning Alert UI
    output$top_nav_or_alert_ui <- renderUI({
        req(rv$counts, rv$meta)
        
        can_run <- all(colnames(rv$counts) %in% rownames(rv$meta)) &&
            identical(colnames(rv$counts), rownames(rv$meta))
        
        if (can_run) {
            actionButton(
                "btn_goto_deseq_top",
                "Proceed to DESeq2 Analysis",
                class = "btn-success btn-action-padded pull-right",
                icon = icon("arrow-right")
            )
        } else {
            div(
                class = "alert alert-danger",
                style = "margin-bottom: 0px; display: inline-block; float: right;",
                icon("exclamation-triangle"),
                tags$b(" Cannot perform analysis: "),
                "Sample IDs in count matrix and metadata do not match."
            )
        }
    })
    
    # 4. Streamlined Horizontal Alignment Status Checks
    output$sample_alignment_check_ui <- renderUI({
        req(rv$counts, rv$meta)
        
        res_all_in <- all(colnames(rv$counts) %in% rownames(rv$meta))
        res_identical <- identical(colnames(rv$counts), rownames(rv$meta))
        
        badge_all <- if (res_all_in)
            span(class = "badge-status-pill badge-success-pill", "MATCHED")
        else
            span(class = "badge-status-pill badge-danger-pill", "MISMATCHED")
        badge_id <- if (res_identical)
            span(class = "badge-status-pill badge-success-pill", "ALIGNED")
        else
            span(class = "badge-status-pill badge-danger-pill", "UNALIGNED")
        
        fluidRow(column(6, div(
            class = "metric-box-summary",
            span(class = "metric-box-label", "Count Samples Exist in Metadata"),
            badge_all
        )), column(6, div(
            class = "metric-box-summary",
            span(class = "metric-box-label", "Exact Sample Order Alignment"),
            badge_id
        )))
    })
    
    # 5. Compact 4-Column KPI Summary Cards
    output$dataset_metrics_summary_ui <- renderUI({
        req(rv$counts, rv$meta)
        
        mat <- as.matrix(rv$counts)
        total_reads <- sum(mat, na.rm = TRUE)
        mean_reads <- mean(colSums(mat, na.rm = TRUE))
        zero_counts <- sum(mat == 0, na.rm = TRUE)
        pct_zeros <- round((zero_counts / length(mat)) * 100, 1)
        
        fluidRow(column(3, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Dataset Dimensions"),
                div(class = "metric-box-val", paste0(
                    format(nrow(rv$counts), big.mark = ","), " × ", ncol(rv$counts)
                ))
            ),
            icon("dna", style = "font-size:22px; color:#6b21a8; opacity:0.6;")
        )),
        column(3, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Total Read Depth"),
                div(class = "metric-box-val", paste0(round(
                    total_reads / 1e6, 1
                ), "M"))
            ),
            icon("layer-group", style = "font-size:22px; color:#2563eb; opacity:0.6;")
        )),
        column(3, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Mean Depth / Sample"),
                div(class = "metric-box-val", paste0(round(
                    mean_reads / 1e6, 2
                ), "M"))
            ),
            icon("vials", style = "font-size:22px; color:#059669; opacity:0.6;")
        )),
        column(3, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Sparsity (Zero-Count)"),
                div(class = "metric-box-val", paste0(pct_zeros, "%"))
            ),
            icon("chart-pie", style = "font-size:22px; color:#d97706; opacity:0.6;")
        )))
    })
    
    # 6. Count Matrix Preview Only
    output$counts_preview_5rows <- renderDT({
        req(rv$counts)
        datatable(
            head(rv$counts, 5),
            options = list(
                scrollX = TRUE,
                dom = 't',
                ordering = FALSE
            ),
            rownames = TRUE
        )
    })
    
    # 7. Navigation Listeners
    observeEvent(input$btn_back_to_setup, {
        updateTabItems(session, "sidebar", "tab_setup_load")
    })
    observeEvent(input$btn_goto_deseq_top, {
        updateTabItems(session, "sidebar", "tab_deseq")
    })
    observeEvent(input$btn_back_to_overview, {
        updateTabItems(session, "sidebar", "tab_overview")
    })
    observeEvent(input$btn_back_to_deseq, {
        updateTabItems(session, "sidebar", "tab_deseq")
    })
    
    # 8. Dynamic UI for Group Selection
    output$condition_col_ui <- renderUI({
        req(rv$meta)
        selectInput("design_var",
                    "Select Disease/Group Column:",
                    choices = colnames(rv$meta))
    })
    
    output$recode_ui <- renderUI({
        req(rv$meta, input$design_var)
        vec <- unique(rv$meta[[input$design_var]])
        selectInput("ref_level",
                    "Select Reference Baseline (Control):",
                    choices = vec)
    })
    
    # 9. Run DESeq2 Pipeline (With Error Catching for No Replicates)
    observeEvent(input$run_analysis, {
        req(rv$counts, rv$meta, input$design_var, input$ref_level)
        
        withProgress(message = "Executing DESeq2 Analysis...", value = 0.3, {
            colData <- rv$meta
            colData$condition <- as.factor(colData[[input$design_var]])
            colData$condition <- relevel(colData$condition, ref = input$ref_level)
            
            cnt_matrix <- as.matrix(rv$counts)
            if (any(cnt_matrix %% 1 != 0, na.rm = TRUE)) {
                showNotification(
                    "Non-integer count values detected. Rounding counts to nearest integer...",
                    type = "warning"
                )
                cnt_matrix <- round(cnt_matrix)
            }
            storage.mode(cnt_matrix) <- "integer"
            
            table_cond <- table(colData$condition)
            has_replicates <- all(table_cond >= 2)
            
            tryCatch({
                if (!has_replicates) {
                    showNotification(
                        "Warning: No replicates found per group! Fitting dispersion without replicates (exploratory mode).",
                        type = "warning",
                        duration = 10
                    )
                    
                    dds <- DESeqDataSetFromMatrix(
                        countData = cnt_matrix,
                        colData = colData,
                        design = ~ 1
                    )
                    dds <- dds[rowSums(counts(dds)) >= input$min_counts, ]
                    dds <- estimateSizeFactors(dds)
                    dds <- estimateDispersionsGeneEst(dds)
                    dispersions(dds) <- mcols(dds)$dispGeneEst
                    dds <- nbinomWaldTest(dds)
                    
                } else {
                    dds <- DESeqDataSetFromMatrix(
                        countData = cnt_matrix,
                        colData = colData,
                        design = ~ condition
                    )
                    dds <- dds[rowSums(counts(dds)) >= input$min_counts, ]
                    dds <- DESeq(dds)
                }
                
                rv$dds <- dds
                
                levels_found <- levels(colData$condition)
                combos <- combn(levels_found, 2, simplify = FALSE)
                contrast_names <- sapply(combos, function(cb)
                    paste0(cb[2], " vs ", cb[1]))
                rv$contrasts_list <- setNames(combos, contrast_names)
                
                showNotification(
                    "DESeq2 Model Built Successfully! Navigating to Visualizations...",
                    type = "message"
                )
                updateTabItems(session, "sidebar", "tab_results")
                
            }, error = function(e) {
                showNotification(
                    paste0("DESeq2 Error: ", e$message),
                    type = "error",
                    duration = 15
                )
            })
        })
    })
    
    # 10. Conditional Post-Analysis Log & Summary Box
    output$deseq_summary_box_ui <- renderUI({
        req(rv$dds)
        
        total_genes_before <- nrow(rv$counts)
        genes_after_filter <- nrow(rv$dds)
        filtered_out <- total_genes_before - genes_after_filter
        num_contrasts <- length(rv$contrasts_list)
        
        fluidRow(
            box(
                title = "Model Execution Log & Analysis Summary",
                width = 12,
                status = "primary",
                solidHeader = TRUE,
                fluidRow(
                    column(3, div(
                        class = "metric-box-summary",
                        div(
                            div(class = "metric-box-label", "Genes Retained"),
                            div(class = "metric-box-val", format(genes_after_filter, big.mark =
                                                                     ","))
                        ),
                        icon("dna", style = "font-size:20px; color:#059669; opacity:0.6;")
                    )),
                    column(3, div(
                        class = "metric-box-summary",
                        div(
                            div(class = "metric-box-label", "Low-Count Filtered"),
                            div(class = "metric-box-val", format(filtered_out, big.mark =
                                                                     ","))
                        ),
                        icon("filter", style = "font-size:20px; color:#d97706; opacity:0.6;")
                    )),
                    column(3, div(
                        class = "metric-box-summary",
                        div(
                            div(class = "metric-box-label", "Factor Levels"),
                            div(class = "metric-box-val", length(unique(rv$meta[[input$design_var]])))
                        ),
                        icon("tags", style = "font-size:20px; color:#2563eb; opacity:0.6;")
                    )),
                    column(3, div(
                        class = "metric-box-summary",
                        div(
                            div(class = "metric-box-label", "Auto Contrasts"),
                            div(class = "metric-box-val", num_contrasts)
                        ),
                        icon("sliders-h", style = "font-size:20px; color:#6b21a8; opacity:0.6;")
                    ))
                ),
                hr(),
                tags$h5(tags$b("DESeqDataSet Object Summary:")),
                verbatimTextOutput("deseq_summary")
            )
        )
    })
    
    output$deseq_summary <- renderPrint({
        req(rv$dds)
        rv$dds
    })
    
    # 11. Results Tab UI - Dynamic Contrast Dropdown
    output$contrast_selector_ui <- renderUI({
        req(rv$contrasts_list)
        selectInput(
            "selected_contrast_str",
            "Choose Comparison Contrast:",
            choices = names(rv$contrasts_list)
        )
    })
    
    # 12. Reactive Contrast Result Evaluation
    active_contrast_res <- reactive({
        req(rv$dds,
            input$selected_contrast_str,
            rv$contrasts_list)
        
        cb <- rv$contrasts_list[[input$selected_contrast_str]]
        
        res <- tryCatch({
            results(rv$dds, contrast = c(input$design_var, cb[2], cb[1]))
        }, error = function(e) {
            results(rv$dds)
        })
        
        res_df <- as.data.frame(res) %>%
            rownames_to_column("Gene_id") %>%
            arrange(padj)
        
        list(
            res = res,
            res_df = res_df,
            label = input$selected_contrast_str
        )
    })
    
    # 13. DEG Up-Regulated and Down-Regulated KPI Ribbon
    output$deg_kpi_metrics_ui <- renderUI({
        req(active_contrast_res(), input$padj_cut, input$lfc_cut)
        
        df <- active_contrast_res()$res_df
        
        total_degs <- sum(
            !is.na(df$padj) &
                df$padj < input$padj_cut & abs(df$log2FoldChange) >= input$lfc_cut
        )
        up_degs <- sum(
            !is.na(df$padj) &
                df$padj < input$padj_cut & df$log2FoldChange >= input$lfc_cut
        )
        down_degs <- sum(
            !is.na(df$padj) &
                df$padj < input$padj_cut & df$log2FoldChange <= -input$lfc_cut
        )
        
        fluidRow(column(4, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Total Significant DEGs"),
                div(class = "metric-box-val", format(total_degs, big.mark =
                                                         ","))
            ),
            icon("layer-group", style = "font-size:22px; color:#6b21a8; opacity:0.6;")
        )), column(4, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Up-Regulated Genes"),
                div(class = "metric-box-val-up", paste0(
                    "↑ ", format(up_degs, big.mark = ",")
                ))
            ),
            icon("arrow-circle-up", style = "font-size:22px; color:#16a34a; opacity:0.6;")
        )), column(4, div(
            class = "metric-box-summary",
            div(
                div(class = "metric-box-label", "Down-Regulated Genes"),
                div(class = "metric-box-val-down", paste0(
                    "↓ ", format(down_degs, big.mark = ",")
                ))
            ),
            icon("arrow-circle-down", style = "font-size:22px; color:#dc2626; opacity:0.6;")
        )))
    })
    
    # 14. Interactive Results Table
    output$results_table <- renderDT({
        req(active_contrast_res())
        datatable(
            active_contrast_res()$res_df,
            options = list(pageLength = 10, scrollX = TRUE),
            rownames = FALSE
        ) %>%
            formatSignif(columns = c("pvalue", "padj", "log2FoldChange"),
                         digits = 4)
    })
    
    # 15. Default Plot Renderers
    render_volcano_plot <- reactive({
        req(active_contrast_res())
        data <- active_contrast_res()
        EnhancedVolcano(
            data$res_df,
            lab = data$res_df$Gene_id,
            x = "log2FoldChange",
            y = "padj",
            pCutoff = input$padj_cut,
            FCcutoff = input$lfc_cut,
            pointSize = 1.5,
            labSize = 3.0,
            subtitle = NULL,
            title = paste(data$label)
        )
    })
    
    output$volcano_plot <- renderPlot({
        render_volcano_plot()
    })
    
    render_ma_plot <- reactive({
        req(active_contrast_res())
        data <- active_contrast_res()
        plotMA(data$res,
               ylim = c(-5, 5),
               main = paste(data$label))
    })
    
    output$ma_plot <- renderPlot({
        render_ma_plot()
    })
    
    # 16. Save Figures and Results into Project Folders
    observeEvent(input$save_to_disk, {
        req(active_contrast_res(), rv$base_dir)
        
        results_dir <- file.path(rv$base_dir, "results")
        figures_dir <- file.path(rv$base_dir, "figures")
        
        data <- active_contrast_res()
        clean_label <- gsub(" ", "_", data$label)
        
        write.csv(data$res_df,
                  file.path(
                      results_dir,
                      paste0("DESeq2_ALL_", clean_label, ".csv")
                  ),
                  row.names = FALSE)
        
        sig_df <- data$res_df %>% filter(!is.na(padj),
                                         padj < input$padj_cut,
                                         abs(log2FoldChange) >= input$lfc_cut)
        write.csv(sig_df, file.path(
            results_dir,
            paste0("DESeq2_SIG_", clean_label, ".csv")
        ), row.names = FALSE)
        
        ggsave(
            file.path(figures_dir, paste0("Volcano_", clean_label, ".png")),
            plot = render_volcano_plot(),
            width = 8,
            height = 7,
            dpi = 300
        )
        
        png(
            file.path(figures_dir, paste0("MA_", clean_label, ".png")),
            width = 2000,
            height = 1800,
            res = 300
        )
        render_ma_plot()
        dev.off()
        
        showNotification(paste0("Figures and results saved to ", rv$base_dir, "!"),
                         type = "message")
    })
    
    # 17. Download Handler
    output$download_sig <- downloadHandler(
        filename = function() {
            clean_label <- gsub(" ", "_", active_contrast_res()$label)
            paste0("DESeq2_SIG_", clean_label, ".csv")
        },
        content = function(file) {
            data <- active_contrast_res()
            sig_df <- data$res_df %>% filter(!is.na(padj),
                                             padj < input$padj_cut,
                                             abs(log2FoldChange) >= input$lfc_cut)
            write.csv(sig_df, file, row.names = FALSE)
        }
    )
}