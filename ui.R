dashboardPage(
    skin = "purple",
    dashboardHeader(title = "DGE Pipeline", tags$li(class = "dropdown", tags$head(tags$style(
        HTML(
            "
          /* Header Styling */
          .main-header .sidebar-toggle {
            float: left !important;
            color: #ffffff !important;
          }
          .main-header .logo {
            float: left !important;
            text-align: left !important;
            padding-left: 15px !important;
            font-weight: 700 !important;
            letter-spacing: 0.5px !important;
            color: #ffffff !important;
            background-color: #4c1d95 !important;
          }

          /* Global Deep Purple & White Theme */
          .skin-purple .main-header .navbar {
            background-color: #581c87 !important;
          }
          .skin-purple .sidebar-menu > li.active > a {
            background-color: #6b21a8 !important;
            color: #ffffff !important;
            border-left-color: #e9d5ff !important;
            font-weight: 600;
          }
          .skin-purple .sidebar-menu > li:hover > a {
            background-color: #7e22ce !important;
            color: #ffffff !important;
          }

          /* Dashboard Boxes Uniform Theme (Purple Header with White Text) */
          .box.box-solid.box-primary > .box-header {
            background-color: #6b21a8 !important;
            color: #ffffff !important;
          }
          .box.box-solid.box-primary {
            border: 1px solid #e2e8f0 !important;
            border-radius: 8px !important;
            box-shadow: 0 2px 5px rgba(0,0,0,0.06) !important;
          }
          .box-title {
            color: #ffffff !important;
            font-weight: 700 !important;
          }

          /* Uniform Padded Action Buttons */
          .btn-action-padded {
            padding: 10px 22px !important;
            font-size: 14px !important;
            font-weight: 600 !important;
            border-radius: 6px !important;
            margin-right: 8px !important;
            margin-bottom: 8px !important;
            border: none !important;
            box-shadow: 0 2px 4px rgba(107, 33, 168, 0.2) !important;
            transition: all 0.2s ease-in-out !important;
          }
          .btn-primary.btn-action-padded {
            background-color: #6b21a8 !important;
            color: #ffffff !important;
          }
          .btn-primary.btn-action-padded:hover {
            background-color: #581c87 !important;
            transform: translateY(-1px) !important;
          }
          .btn-success.btn-action-padded {
            background-color: #059669 !important;
            color: #ffffff !important;
          }
          .btn-success.btn-action-padded:hover {
            background-color: #047857 !important;
            transform: translateY(-1px) !important;
          }
          .btn-default.btn-action-padded {
            background-color: #f1f5f9 !important;
            color: #334155 !important;
            border: 1px solid #cbd5e1 !important;
          }
          .btn-default.btn-action-padded:hover {
            background-color: #e2e8f0 !important;
            transform: translateY(-1px) !important;
          }

          /* Metric Summary Ribbon Box */
          .metric-box-summary {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 14px 18px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.04);
            display: flex;
            align-items: center;
            justify-content: space-between;
          }
          .metric-box-label {
            font-size: 11px;
            text-transform: uppercase;
            color: #64748b;
            letter-spacing: 0.5px;
            font-weight: 700;
          }
          .metric-box-val {
            font-size: 20px;
            color: #0f172a;
            font-weight: bold;
          }
          .metric-box-val-up {
            font-size: 20px;
            color: #16a34a;
            font-weight: bold;
          }
          .metric-box-val-down {
            font-size: 20px;
            color: #dc2626;
            font-weight: bold;
          }
          .badge-status-pill {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 700;
          }
          .badge-success-pill {
            background-color: #dcfce7;
            color: #15803d;
            border: 1px solid #bbf7d0;
          }
          .badge-danger-pill {
            background-color: #fee2e2;
            color: #b91c1c;
            border: 1px solid #fecaca;
          }
        "
        )
    )))),
    
    dashboardSidebar(
        sidebarMenu(
            id = "sidebar",
            menuItem(
                "1. Setup & Data Import",
                tabName = "tab_setup_load",
                icon = icon("folder-open")
            ),
            menuItem(
                "2. Data Overview",
                tabName = "tab_overview",
                icon = icon("chart-pie")
            ),
            menuItem(
                "3. DESeq2 Analysis",
                tabName = "tab_deseq",
                icon = icon("cogs")
            ),
            menuItem(
                "4. Results & Visuals",
                tabName = "tab_results",
                icon = icon("chart-bar")
            )
        )
    ),
    
    dashboardBody(tabItems(
        # --- TAB 1: COMBINED SETUP & DATA LOADING ---
        tabItem(tabName = "tab_setup_load", fluidRow(
            box(
                title = "1. Select Output Directory",
                width = 12,
                status = "primary",
                solidHeader = TRUE,
                p(
                    "Click below to open file explorer and pick or create your project directory:"
                ),
                actionButton(
                    "btn_open_native_explorer",
                    "Open File Explorer...",
                    class = "btn-primary btn-action-padded",
                    icon = icon("folder-open")
                ),
                hr(),
                verbatimTextOutput("dir_status")
            )
        ), fluidRow(
            box(
                title = "2. Hybrid Data Input Configuration",
                width = 12,
                status = "primary",
                solidHeader = TRUE,
                p(
                    "Mix and match GEO accessions and file uploads according to your dataset setup:"
                ),
                
                fluidRow(column(
                    6,
                    wellPanel(
                        tags$h4(icon("dna"), " Counts Matrix Source"),
                        radioButtons(
                            "counts_src_type",
                            "Counts Source:",
                            choices = c(
                                "Download via GEO Accession" = "geo",
                                "Upload Local File" = "file"
                            ),
                            inline = TRUE
                        ),
                        conditionalPanel(
                            condition = "input.counts_src_type == 'geo'",
                            textInput("counts_geo_id", "Counts GEO Accession ID:", value = "GSE231693")
                        ),
                        conditionalPanel(
                            condition = "input.counts_src_type == 'file'",
                            fileInput(
                                "counts_file",
                                "Upload Counts Matrix (.tsv, .csv, .txt)",
                                accept = c(".tsv", ".csv", ".txt")
                            )
                        )
                    )
                ), column(
                    6,
                    wellPanel(
                        tags$h4(icon("list-alt"), " Metadata Source"),
                        radioButtons(
                            "meta_src_type",
                            "Metadata Source:",
                            choices = c(
                                "Download via GEO Accession" = "geo",
                                "Upload Local File" = "file"
                            ),
                            inline = TRUE
                        ),
                        conditionalPanel(
                            condition = "input.meta_src_type == 'geo'",
                            textInput("meta_geo_id", "Metadata GEO Accession ID:", value = "GSE231693")
                        ),
                        conditionalPanel(
                            condition = "input.meta_src_type == 'file'",
                            fileInput(
                                "meta_file",
                                "Upload Metadata (.csv, .tsv, .txt)",
                                accept = c(".csv", ".tsv", ".txt")
                            )
                        )
                    )
                )),
                
                fluidRow(column(
                    12,
                    br(),
                    actionButton(
                        "btn_process_dataset",
                        "Load Dataset & Show Overview",
                        class = "btn-success btn-action-padded btn-block",
                        icon = icon("play-circle")
                    )
                ))
            )
        )),
        
        # --- TAB 2: DATA OVERVIEW ---
        tabItem(
            tabName = "tab_overview",
            # Top Action Button Row (Back & Next Navigation)
            fluidRow(column(
                12,
                actionButton(
                    "btn_back_to_setup",
                    "Back to Setup",
                    class = "btn-default btn-action-padded",
                    icon = icon("arrow-left")
                ),
                uiOutput("top_nav_or_alert_ui", inline = TRUE),
                br(),
                br()
            )),
            
            # Compact KPI Summary Ribbon
            uiOutput("dataset_metrics_summary_ui"),
            br(),
            
            # Alignment Status Checks
            fluidRow(
                box(
                    title = "Sample Alignment Checks",
                    width = 12,
                    status = "primary",
                    solidHeader = TRUE,
                    uiOutput("sample_alignment_check_ui")
                )
            ),
            
            # Count Matrix Preview Only
            fluidRow(
                box(
                    title = "Counts Matrix Preview (First 5 Rows)",
                    width = 12,
                    status = "primary",
                    solidHeader = TRUE,
                    DTOutput("counts_preview_5rows")
                )
            )
        ),
        
        # --- TAB 3: DESEQ2 ANALYSIS ---
        tabItem(
            tabName = "tab_deseq",
            fluidRow(column(
                12,
                actionButton(
                    "btn_back_to_overview",
                    "Back to Overview",
                    class = "btn-default btn-action-padded",
                    icon = icon("arrow-left")
                ),
                br(),
                br()
            )),
            fluidRow(
                box(
                    title = "Experimental Design & Analysis Parameters",
                    width = 12,
                    status = "primary",
                    solidHeader = TRUE,
                    fluidRow(
                        column(4, uiOutput("condition_col_ui")),
                        column(4, uiOutput("recode_ui")),
                        column(
                            4,
                            numericInput(
                                "min_counts",
                                "Filter Low-Count Genes (Min Read Sum):",
                                value = 10,
                                min = 0
                            )
                        )
                    ),
                    hr(),
                    fluidRow(column(
                        12,
                        actionButton(
                            "run_analysis",
                            "Execute DESeq2 Pipeline",
                            class = "btn-success btn-action-padded btn-lg btn-block",
                            icon = icon("play-circle")
                        )
                    ))
                )
            ),
            # Dynamically loaded only AFTER analysis completes
            uiOutput("deseq_summary_box_ui")
        ),
        
        # --- TAB 4: RESULTS & VISUALIZATIONS ---
        tabItem(
            tabName = "tab_results",
            fluidRow(column(
                12,
                actionButton(
                    "btn_back_to_deseq",
                    "Back to DESeq2 Setup",
                    class = "btn-default btn-action-padded",
                    icon = icon("arrow-left")
                ),
                br(),
                br()
            )),
            
            # Dynamic Contrast Dropdown Bar
            fluidRow(
                box(
                    title = "Contrast & Visual Selection",
                    width = 12,
                    status = "primary",
                    solidHeader = TRUE,
                    fluidRow(
                        column(6, uiOutput("contrast_selector_ui")),
                        column(
                            3,
                            numericInput(
                                "padj_cut",
                                "Adjusted p-value Cutoff:",
                                value = 0.05,
                                step = 0.01
                            )
                        ),
                        column(
                            3,
                            numericInput(
                                "lfc_cut",
                                "|log2FoldChange| Cutoff:",
                                value = 1,
                                step = 0.25
                            )
                        )
                    )
                )
            ),
            
            # DEG Count KPI Metrics Ribbon
            uiOutput("deg_kpi_metrics_ui"),
            br(),
            
            # Side-by-Side MA Plot and Volcano Plot
            fluidRow(
                box(
                    title = "Volcano Plot",
                    width = 6,
                    status = "primary",
                    solidHeader = TRUE,
                    plotOutput("volcano_plot", height = "450px")
                ),
                box(
                    title = "MA Plot",
                    width = 6,
                    status = "primary",
                    solidHeader = TRUE,
                    plotOutput("ma_plot", height = "450px")
                )
            ),
            
            # Results Data Table
            fluidRow(
                box(
                    title = "Differential Gene Expression Results Table",
                    width = 12,
                    status = "primary",
                    solidHeader = TRUE,
                    fluidRow(column(
                        6,
                        actionButton("save_to_disk", "Save Figures & Results to Output Folders", class = "btn-success btn-action-padded")
                    ), column(
                        6,
                        downloadButton("download_sig", "Download Significant DEGs (.csv)", class = "btn-primary btn-action-padded pull-right")
                    )),
                    hr(),
                    DTOutput("results_table")
                )
            )
        )
    ))
)