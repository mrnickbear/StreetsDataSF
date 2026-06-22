library(shiny)
library(leaflet)
library(mapview)

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "excavator.css"),
    tags$script(HTML('
      (function() {
        // WORKAROUND for GitHub issue #9: Posit Connect injects a LaunchDarkly SDK
        // that calls document.featurePolicy.features() (Chrome Feature Policy API)
        // and logs "Unrecognized feature" warnings for deprecated feature names (vr,
        // ambient-light-sensor) that some Chrome versions still enumerate.
        // This is a platform-level issue in Posit Connect; the workaround patches
        // the Feature Policy API and console.warn so the warnings do not surface.
        // Remove this block once Posit Connect updates their LaunchDarkly SDK.
        //
        // These Feature Policy names were deprecated/removed from the W3C Permissions
        // Policy specification but remain enumerated by some Chrome releases.
        // See: https://github.com/w3c/webappsec-permissions-policy/
        // Update this list if new deprecated names appear in future browser versions.
        var _deprecated = ["vr", "ambient-light-sensor"];

        // Patch FeaturePolicy.prototype.features (Chrome Feature Policy API)
        if (window.FeaturePolicy && FeaturePolicy.prototype &&
            typeof FeaturePolicy.prototype.features === "function") {
          var _origFeatures = FeaturePolicy.prototype.features;
          FeaturePolicy.prototype.features = function() {
            return _origFeatures.call(this).filter(function(f) {
              return _deprecated.indexOf(f) === -1;
            });
          };
        }

        // Belt-and-suspenders: suppress console.warn messages that contain
        // "Unrecognized feature" together with one of the known deprecated names.
        // Using substring matching so the filter survives minor SDK message changes.
        var _origWarn = console.warn;
        console.warn = function() {
          var msg = arguments.length > 0 ? String(arguments[0]) : "";
          if (msg.indexOf("Unrecognized feature") !== -1) {
            for (var i = 0; i < _deprecated.length; i++) {
              if (msg.indexOf(_deprecated[i]) !== -1) {
                // Intentionally suppress: this is a known platform warning, not
                // an application error.  See the WORKAROUND comment above.
                return;
              }
            }
          }
          return _origWarn.apply(console, arguments);
        };
      })();
    '))
  ),
  titlePanel("SF Streets Explorer"),
  tabsetPanel(
    id = "main_tabs",

    # ── Map tab (existing) ──────────────────────────────────────────────────
    tabPanel(
      "\U0001f5fa\ufe0f Map",
      br(),
      div(
        h4("Arterial Streets from DataSF"),
        uiOutput("tab")
      ),
      leafletOutput("map", width = "100%", height = 800)
    ),

    # ── SQL Curriculum tab ──────────────────────────────────────────────────
    tabPanel(
      "\U0001f4da SQL Curriculum",
      div(
        class = "curriculum-container",

        # Excavator character + narrative
        div(
          class = "excavator-area",
          tags$img(
            class      = "excavator-img",
            src        = "ExcavatorEmoji.png",
            alt        = "Digger the Excavator",
            height     = "130px"
          ),
          div(
            class = "narrative-wrap",
            div(class = "step-counter-wrap", textOutput("step_counter")),
            h4(class  = "step-title",        textOutput("step_title")),
            div(class = "speech-bubble",     textOutput("step_narrative"))
          )
        ),

        # SQL input
        div(
          class = "sql-input-area",
          textAreaInput(
            inputId     = "sql_input",
            label       = "SQL Query \u2014 modify and run:",
            value       = "SELECT * FROM streets_df LIMIT 5",
            rows        = 5,
            width       = "100%"
          ),
          actionButton("run_sql", "\u25b6 Run Query",
                       class = "btn btn-success btn-run")
        ),

        # SQL output
        div(
          class = "sql-output-area",
          h5("Results:"),
          div(class = "results-table-wrap", tableOutput("sql_output")),
          verbatimTextOutput("sql_error")
        ),

        # Navigation
        div(
          class = "nav-area",
          actionButton("prev_step", "\u25c4 Previous", class = "btn btn-default"),
          uiOutput("step_progress"),
          actionButton("next_step", "Next \u25ba",     class = "btn btn-primary")
        )
      )
    )
  )
)