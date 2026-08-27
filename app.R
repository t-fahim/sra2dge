library(shiny)
library(bslib)
library(DESeq2)
library(ggplot2)
library(plotly)
library(DT)
library(airway)

# Custom CSS for UI enhancements
custom_css <- "
  .sidebar { background-color: #f8f9fa; border-right: 1px solid #e9ecef; }
  .card { border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
  .btn-primary { background-color: #2c3e50; border-color: #2c3e50; font-weight: 600; }
  .btn-primary:hover { background-color: #1a252f; border-color: #1a252f; }
  .value-box { border-radius: 8px; }
"

# UI Definition with Bslib modern theme
ui <- page_navbar(
    title = "RNA-seq Explorer",
    theme = bs_theme(
        version = 5,
        bootswatch = "flatly",
        primary = "#2c3e50",
        secondary = "#18bc9c"
    ),
    header = tags$head(tags$style(custom_css)),
    
    sidebar = sidebar(
        title = "Controls & Parameters",
        width = 300,
        numericInput("min_counts", "Min Read Threshold:", value = 10, min = 0),
        sliderInput("alpha_cutoff", "FDR Threshold (alpha):", min = 0.001, max = 0.2, value = 0.05, step = 0.005),
        sliderInput("lfc_cutoff", "Log2 Fold Change Threshold:", min = 0, max = 3, value = 1, step = 0.25),
        hr(),
        actionButton("run_analysis", "Run Pipeline", class = "btn-primary w-100", icon = icon("play"))
    ),
    
    nav_panel(
        title = "Overview & Data",
        icon = icon("table"),
        layout_columns(
            fill = FALSE,
            card(
                card_header("Experiment Metadata"),
                tableOutput("sample_table")
            ),
            card(
                card_header("Raw Read Counts Preview"),
                dataTableOutput("counts_table")
            )
        )
    ),
    
    nav_panel(
        title = "Differential Expression",
        icon = icon("chart-line"),
        
        # Dynamic Summary KPI Boxes
        layout_columns(
            fill = FALSE,
            value_box(
                title = "Total Filtered Genes",
                value = textOutput("vb_total"),
                showcase = icon("dna"),
                theme = "light"
            ),
            value_box(
                title = "Upregulated Genes",
                value = textOutput("vb_up"),
                showcase = icon("arrow-up"),
                theme = "danger"
            ),
            value_box(
                title = "Downregulated Genes",
                value = textOutput("vb_down"),
                showcase = icon("arrow-down"),
                theme = "info"
            )
        ),
        
        layout_columns(
            col_widths = c(6, 6),
            card(
                card_header("MA Plot"),
                plotOutput("ma_plot", height = "500px")
            ),
            card(
                card_header("Volcano Plot"),
                plotlyOutput("volcano_plot", height = "500px")
            )
        ),
        
        card(
            card_header("Interactive Results Table"),
            dataTableOutput("results_table")
        )
    )
)

# Server Logic
server <- function(input, output, session) {
    
    # Load and prepare data on startup
    raw_data <- reactive({
        data(airway)
        
        sample_info <- as.data.frame(colData(airway))[, c(2, 3)]
        sample_info$dex <- gsub('trt', 'treated', sample_info$dex)
        sample_info$dex <- gsub('untrt', 'untreated', sample_info$dex)
        names(sample_info) <- c('cellLine', 'dexamethasone')
        sample_info$dexamethasone <- factor(sample_info$dexamethasone, levels = c("untreated", "treated"))
        
        counts_data <- assay(airway)
        list(sample_info = sample_info, counts_data = counts_data)
    })
    
    output$sample_table <- renderTable({
        raw_data()$sample_info
    }, rownames = TRUE)
    
    output$counts_table <- renderDataTable({
        datatable(
            raw_data()$counts_data[1:100, ], 
            options = list(pageLength = 6, scrollX = TRUE, dom = 'tip')
        )
    })
    
    # Run DESeq2 Pipeline
    deseq_results <- eventReactive(input$run_analysis, {
        req(raw_data())
        
        dat <- raw_data()
        dds <- DESeqDataSetFromMatrix(
            countData = dat$counts_data,
            colData = dat$sample_info,
            design = ~ dexamethasone
        )
        
        keep <- rowSums(counts(dds)) >= input$min_counts
        dds <- dds[keep, ]
        dds$dexamethasone <- relevel(dds$dexamethasone, ref = "untreated")
        
        dds <- DESeq(dds)
        res <- results(dds, alpha = input$alpha_cutoff)
        
        list(dds = dds, res = res)
    })
    
    # KPI Calculations
    output$vb_total <- renderText({
        req(deseq_results())
        format(nrow(deseq_results()$res), big.mark = ",")
    })
    
    output$vb_up <- renderText({
        req(deseq_results())
        res <- as.data.frame(deseq_results()$res)
        up <- sum(res$padj < input$alpha_cutoff & res$log2FoldChange > input$lfc_cutoff, na.rm = TRUE)
        format(up, big.mark = ",")
    })
    
    output$vb_down <- renderText({
        req(deseq_results())
        res <- as.data.frame(deseq_results()$res)
        down <- sum(res$padj < input$alpha_cutoff & res$log2FoldChange < -input$lfc_cutoff, na.rm = TRUE)
        format(down, big.mark = ",")
    })
    
    # MA Plot
    output$ma_plot <- renderPlot({
        req(deseq_results())
        par(mar = c(4.5, 4.5, 2, 1))
        plotMA(
            deseq_results()$res, 
            main = "",
            colNonSig = "gray60",
            colSig = "#e74c3c",
            colLine = "#2c3e50"
        )
    })
    
    # Volcano Plot (Interactive)
    output$volcano_plot <- renderPlotly({
        req(deseq_results())
        df <- as.data.frame(deseq_results()$res)
        df$Gene <- rownames(df)
        df <- na.omit(df)
        
        df$Expression <- "Not Significant"
        df$Expression[df$padj < input$alpha_cutoff & df$log2FoldChange > input$lfc_cutoff] <- "Upregulated"
        df$Expression[df$padj < input$alpha_cutoff & df$log2FoldChange < -input$lfc_cutoff] <- "Downregulated"
        
        p <- ggplot(df, aes(x = log2FoldChange, y = -log10(padj), text = Gene, color = Expression)) +
            geom_point(alpha = 0.6, size = 1.5) +
            scale_color_manual(values = c("Upregulated" = "#e74c3c", "Downregulated" = "#3498db", "Not Significant" = "gray70")) +
            geom_vline(xintercept = c(-input$lfc_cutoff, input$lfc_cutoff), linetype = "dashed", color = "black") +
            geom_hline(yintercept = -log10(input$alpha_cutoff), linetype = "dashed", color = "black") +
            theme_minimal() +
            labs(x = "Log2 Fold Change", y = "-Log10 Adjusted P-value")
        
        ggplotly(p, tooltip = c("text", "x", "y"))
    })
    
    # Interactive Datatable
    output$results_table <- renderDataTable({
        req(deseq_results())
        res_df <- as.data.frame(deseq_results()$res)
        res_df <- cbind(GeneID = rownames(res_df), res_df)
        
        datatable(
            res_df,
            rownames = FALSE,
            extensions = 'Buttons',
            options = list(
                pageLength = 10,
                scrollX = TRUE,
                dom = 'Bfrtip',
                buttons = c('copy', 'csv', 'excel'),
                order = list(list(6, 'asc'))
            )
        ) %>% 
            formatSignif(columns = c("pvalue", "padj"), digits = 3) %>%
            formatRound(columns = c("baseMean", "log2FoldChange", "lfcSE", "stat"), digits = 3)
    })
}

shinyApp(ui = ui, server = server)