#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(dplyr)
library(tidyverse)
library(vroom) #fast reading of csv files
library(sf) #spatial data
library(tigris) #geojoining
library(leaflet) #interactive maps
library(htmlwidgets) #interactive map labels
library(plotly)
library(fontawesome)

#read in data
SMUrestaurants<-vroom("https://raw.githubusercontent.com/xinyit/SMU_Exchange/main/SMURestaurants.csv")
SMUdf= data.frame(SMUrestaurants)

#Cuisines
by_price<- SMUdf%>% group_by(price)
cheap<-


FarrerRestaurants<-vroom("https://raw.githubusercontent.com/xinyit/SMU_Exchange/main/FarrerRestaurants.csv")
Farrerdf= data.frame(FarrerRestaurants)

cuisines=sort(unique(SMUdf$cuisine))

# Define UI for application
ui <- fluidPage(
    
    # Application title
    titlePanel("SMU Exchange Restaurant Finder"),
    
    # Sidebar
    sidebarLayout(
        
        sidebarPanel(
        # Checkboxes for Cuisine
        checkboxGroupInput("checkCuisines", label = h3("Cuisine"), 
                           choices = cuisines,
                           selected = "Singaporean"),
        
        selectInput("Price",
                    "Select a price category ($, $$, $$$)",
                    choices=sort(unique(SMUrestaurants$price)),
                    selected="$"),
        
        #add how it is measured
        sliderInput("weightPopularity", "How much does a restaurant's popularity matter to you?", 1, 10, 5),
        
        print("Note: Restaurant popularity is based on no. of reviews")
        
        ),
        
        # Main Panel
        mainPanel(
            tabsetPanel(
                tabPanel("Around SMU",  
                         fluidRow(column(12,leafletOutput("SMUMap"))),
                         #fluidRow(column(12,plotOutput("bar"))),
                         fluidRow(column(12,plotlyOutput("SMUbar")))),
                tabPanel("Farrer Park", 
                         fluidRow(column(12, leafletOutput("FarrerMap"))),
                         fluidRow(column(12, plotlyOutput("Farrerbar"))))
            )
            )
    )

)




# Define server logic
server <- function(input, output) {
    
    #possibly use an icon of a university instead
    SMUicon <- icons(
        iconUrl = "https://icons.iconarchive.com/icons/icons8/windows-8/512/Science-University-icon.png",
        iconWidth = 30, iconHeight = 30
    )
    
    uniIcon <- makeAwesomeIcon(
        icon = "building-columns",
        markerColor = "blue",
        library = "fa"
    )
    
    output$bar<-renderPlot({
        df<-SMUfiltered_by_price()
        groupbyCuisine<- df%>% count(cuisine)
        barplot(as.integer(groupbyCuisine$n), 
                names.arg=groupbyCuisine$cuisine,
                xlab="Cuisine", 
                ylab='Number of restaurants',
                col="darkred")
    })
    
    output$SMUbar<-renderPlotly({
        df<-SMUfiltered_by_price()
        groupbyCuisine<- df%>% count(cuisine)
        fig <- plot_ly(type = 'bar', width=500) 
        fig <- fig %>%
            add_trace(
                x = groupbyCuisine$cuisine, 
                y = groupbyCuisine$n,
                #text = groupbyCuisine$cuisine,
                hoverinfo = groupbyCuisine$cuisine,
                name= paste0("Restaurants By Cuisine (", input$Price, ")"),
                width=0.8,
                showlegend=FALSE
            )
        fig <- fig %>% layout(xaxis=list(title="",tickangle=-35))
    })
    
    output$Farrerbar<-renderPlotly({
        df<-Farrerfiltered_by_price()
        groupbyCuisine<- df%>% count(cuisine)
        fig <- plot_ly(type = 'bar', width=500) 
        fig <- fig %>%
            add_trace(
                x = groupbyCuisine$cuisine, 
                y = groupbyCuisine$n,
                #text = groupbyCuisine$cuisine,
                hoverinfo = groupbyCuisine$cuisine,
                name= paste0("Restaurants By Cuisine (", input$Price, ")"),
                width=0.8,
                showlegend=FALSE
            )
        fig <- fig %>% layout(xaxis=list(title="",tickangle=-35))
    })
    
    
    output$SMUMap <- renderLeaflet({
        
        cuisine_df <- SMUfiltered_restaurants()
        pal <- colorNumeric(palette = c("Red", "Green"), domain = cuisine_df$rating)

        labels <- sprintf("<strong>%s</strong><br/> Restaurants around SMU",
                          input$checkCuisines)%>%
            lapply(htmltools::HTML)
        
        if(length(cuisine_df$name)==0) {
            map_interactive<- cuisine_df %>%
                leaflet() %>%
                setView(lng = 103.8502, lat = 1.2963, zoom = 15.3) %>%
                addProviderTiles(providers$OpenStreetMap) %>%
                addMarkers(lng= 103.8502, lat= 1.2963, popup= "SMU", label= "SMU", icon=SMUicon)
        }
        else {
            map_interactive<- cuisine_df %>%
                leaflet() %>%
                setView(lng = 103.8502, lat = 1.2963, zoom = 15.3) %>%
                addProviderTiles(providers$OpenStreetMap) %>%
                addCircles(lng= 103.8502, lat= 1.2963, radius=1000, color="White", opacity=1, label= "Within 1km of SMU", labelOptions=labelOptions(noHide=F, direction='top'))%>%
                addCircleMarkers(data= cuisine_df, lng = ~longitude, lat = ~latitude, popup = paste0("Restaurant name: ", as.character(cuisine_df$name),"<br>Price: ", cuisine_df$price, "<br>Cuisine: ", cuisine_df$cuisine, "<br>Rating: ", cuisine_df$rating, "<br>Address: ", cuisine_df$address), label = ~as.character(name), radius= ~(10*(review_count)^(input$weightPopularity/20)), color=~pal(rating), fillOpacity=0.95, clusterOptions=markerClusterOptions()) %>%
                addMarkers(lng= 103.8502, lat= 1.2963, popup= "SMU", label= "SMU", icon=SMUicon) %>%
                addLegend("bottomright", pal= pal, values = ~rating, title= "Rating")
            }

    })

    output$FarrerMap <- renderLeaflet({
        
        Farrercuisine_df <- Farrerfiltered_restaurants()
        
        pal <- colorNumeric(palette = c("Red", "Green"), domain = Farrercuisine_df$rating)
        
        labels <- sprintf("<strong>%s</strong><br/> Restaurants around Farrer Park",
                          input$checkCuisines)%>%
            lapply(htmltools::HTML)
        
        #use a conditional statement to print basemap or a display message to tell users to select an cuisine if no choices are selected
        #if there are no restaurants found, provide a message instead of the default error msg (e.g. for Indian)
        if(length(Farrercuisine_df$name)==0){
            map_interactive<- Farrercuisine_df %>%
                leaflet() %>%
                setView(lng=103.8542, lat = 1.3124, zoom = 16) %>%
                addProviderTiles(providers$OpenStreetMap) %>%
                addMarkers(lng= 103.8542, lat= 1.3124, label= "Farrer Park MRT", labelOptions = labelOptions(noHide=T, direction='top'))
        }
        else{
            map_interactive<- Farrercuisine_df %>%
                leaflet() %>%
                setView(lng = 103.8542, lat = 1.3124, zoom = 15) %>%
                addProviderTiles(providers$OpenStreetMap) %>%
                addCircles(lng= 103.8542, lat= 1.3124, radius=1000, color="White", opacity=1, label= "Within 1km of Farrer park MRT", labelOptions=labelOptions(noHide=F, direction='top'))%>%
                addCircleMarkers(data= Farrercuisine_df, lng = ~longitude, lat = ~latitude, popup = paste0("Restaurant name: ", as.character(Farrercuisine_df$name),"<br>Price: ", Farrercuisine_df$price, "<br>Cuisine: ", Farrercuisine_df$cuisine, "<br>Rating: ", Farrercuisine_df$rating, "<br>Address: ", Farrercuisine_df$address), label = ~as.character(name), radius= ~(10*(review_count)^(input$weightPopularity/20)), color=~pal(rating), fillOpacity=0.9,clusterOptions=markerClusterOptions()) %>%
                addMarkers(lng= 103.8542, lat= 1.3124, label= "Farrer Park MRT", labelOptions = labelOptions(noHide=T, direction='top')) %>%
                addLegend("bottomright", pal= pal, values = ~rating, title= "Rating")
        }
    })
    
    SMUfiltered_restaurants <- reactive({
        SMUdf %>% dplyr::filter(cuisine%in%input$checkCuisines) %>% filter(price==input$Price)
    })
    
    SMUfiltered_by_price<- reactive({
        SMUdf%>%dplyr::filter(price==input$Price)
    })
    
    Farrerfiltered_restaurants <- reactive({
        Farrerdf %>% dplyr::filter(cuisine%in%input$checkCuisines) %>% filter(price==input$Price)
    })
    
    Farrerfiltered_by_price<- reactive({
        Farrerdf%>%dplyr::filter(price==input$Price)
    })
    
    
}

# Run the application 
shinyApp(ui = ui, server = server)
