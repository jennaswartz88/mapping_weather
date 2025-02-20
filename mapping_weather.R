#Preparation
install.packages("maps")
library(maps)
library(dplyr)
library(tidyverse)
library(ggplot2) 
install.packages("ggthemes")
library(ggthemes)
install.packages("remotes")
remotes::install_github("UrbanInstitute/urbnmapr")
library(urbnmapr)
library(sf)
library(leaflet)
library(RColorBrewer)
install.packages("geosphere")
library(geosphere)


#Loading in storm data
file_path <- "C:/Users/jenna/Documents/Data Viz/course materials/course_content/Exercises/07_severe_weather_GRADED/data/storms.csv"
storm_data <- read_csv(file_path)


#PART 1: DAMAGE FROM STORMS

# a) State Level Choropleth Maps

# Using maps package, which has geographic information on all U.S states
us.states <- map_data("state") %>%
  as_tibble(.) %>%
  dplyr::rename(state = region) %>%
  select(-subregion) %>%
  mutate(state = str_to_title(state))

# Add State Abbreviations and Centers
statenames <- as_tibble(
  cbind(state=state.name, state.abb = state.abb, 
        state.center.x = state.center$x, 
        state.center.y = state.center$y))
statenames #has state, state.abb, state.center.x and state.center.y
statenames <- statenames %>% mutate_each_(funs(as.numeric), #changing centers to numeric
                                          vars=c("state.center.x","state.center.y"))
us.states <- left_join(us.states, statenames)
us.states #took us.states and added state abb state center x and y
us.states <- us.states %>% #making title column all caps for easier merging
  rename(STATE = state)
us.states$STATE <- toupper(us.states$STATE) #making states all caps for easier merging

#now I will prepare a simple dataset with total money damage by state
storm_data_filtered <- select(storm_data, STATE, DAMAGE_PROPERTY_USD, DAMAGE_CROPS_USD)
storm_data_filtered <- storm_data_filtered %>%
  mutate(money_damage = DAMAGE_PROPERTY_USD + DAMAGE_CROPS_USD)
state_money_damages <- select(storm_data_filtered, -DAMAGE_PROPERTY_USD, -DAMAGE_CROPS_USD)

#merging sets
moneydamages.merged=left_join(state_money_damages, us.states, by='STATE')
moneydamages.merged

# First, I will replace all NAs with zeros in the "money_damage" column
# Next, group by the "STATE" column and summarize the "money_damage" variable so we see sum of total $ damage
# for that state between 2017 and 2022, for all weather events combined.
moneydamages.merged <- moneydamages.merged %>%
  mutate(money_damage = replace_na(money_damage, 0))
summarized_statedamages <- moneydamages.merged %>%
  group_by(STATE) %>%
  summarise(total_money_damage = sum(money_damage))

#now I'll merge the total money damage for each state with state info from us.states
merged_final_statedamages = left_join(summarized_statedamages, us.states, by='STATE')

#Setting format for my labels so it'll show $ in million, billion, trillion, etc.in the legend
label_format <- function(x) {
  ifelse(x >= 1e12, paste0(format(x / 1e12, scientific = FALSE), " trillion"),
         ifelse(x >= 1e9, paste0(format(x / 1e9, scientific = FALSE), " billion"),
                ifelse(x >= 1e6, paste0(format(x / 1e6, scientific = FALSE), " million"),
                format(x, scientific = FALSE))))
}

# Creating a plot with darkest purple being most money spent and light pink being least money spent
ggplot(merged_final_statedamages,
       aes(x = long, y = lat, group = group, label = state.abb, fill = total_money_damage)) +
  geom_polygon(color = "white") +
  scale_fill_gradientn(colours = c("pink", "purple4"), 
                       name = "Total Monetary Damage",
                       labels = label_format) +  # Using label formatting function
  ggtitle("Total Storm-Related Monetary Damage by State 2017-2022") +
  geom_text(aes(x = state.center.x, y = state.center.y, label = state.abb), color = "white", size = 3, inherit.aes = FALSE) +
  theme_map() +
  theme(
        text = element_text(family = "Times New Roman"),  # Change font to TNR
        plot.title = element_text(hjust = 0.5, size = 16, face = "bold")) +  # Centered title, size 16, bold
  coord_map(projection = "mercator") +
  guides(fill = guide_colorbar(barwidth = 2, barheight = 5,  # Adjust bar width and height
                               title.position = "top", 
                               label.position = "left")) +  # Adjust legend label position

#b) County Choropleth Maps
#Starting by getting counties map and info
uscounties_sf <- get_urbn_map("counties", sf = TRUE)
# changing county fips column name in uscounties_sf for ease of merging later
colnames(counties)[colnames(counties) == "county_name"] <- "CZ_NAME"
counties$CZ_NAME <- toupper(counties$CZ_NAME)

#now preparing simple dataset with money damage by county (for each incident)
storm_data_counties <- filter(storm_data, CZ_TYPE == "C") #only grabbing events that happened in counties
storm_data_filtered2 <- select(storm_data_counties, CZ_NAME, DAMAGE_PROPERTY_USD, DAMAGE_CROPS_USD)
storm_data_filtered2 <- storm_data_filtered2 %>%
  mutate(money_damage2 = DAMAGE_PROPERTY_USD + DAMAGE_CROPS_USD)
county_money_damages <- select(storm_data_filtered2, -DAMAGE_PROPERTY_USD, -DAMAGE_CROPS_USD)
# adding "COUNTY" at ends of county names to prep for merging
county_money_damages$CZ_NAME <- paste(county_money_damages$CZ_NAME, "COUNTY", sep = " ")

# Now I will join the counties info 
moneydamages.merged2 <- left_join(county_money_damages, counties, by = 'CZ_NAME')

# First, I will replace all NAs with zeros in the "money_damage2" column
#Next, I'll group by the "CZ_NAME" column and summarize the "money_damage2" variable so we see sum of total $
#damage for that county between 2017 and 2022 (combined from all the events)
moneydamages.merged2 <- moneydamages.merged2 %>%
  mutate(money_damage2 = replace_na(money_damage2, 0))
summarized_countydamages <- moneydamages.merged2 %>%
  group_by(CZ_NAME) %>%
  summarise(total_money_damage2 = sum(money_damage2))

#merging back total $ damages for each county with all the county info
merged_final_countydamages = left_join(summarized_countydamages, counties, by='CZ_NAME')

# Create the same plot as above but for counties. The darkest purple means most money spent and light pink means least money spent
ggplot(merged_final_countydamages,
       aes(x = long, y = lat, group = group, fill = total_money_damage2)) +
  geom_polygon(color = "white") +
  scale_fill_gradientn(colours = c("pink", "purple4"), 
                       name = "Total Monetary Damage",
                       labels = label_format) +  # Use custom formatting function
  ggtitle("Total Storm-Related Monetary Damage by County 2017-2022") +
  theme_map() +
  theme(
    text = element_text(family = "Times New Roman"),  # Change font to TNR
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold")) +  # Centered title, size 16, bold
  coord_map(projection = "mercator") +
  guides(fill = guide_colorbar(barwidth = 2, barheight = 5,  # Adjust bar width and height
                               title.position = "top", 
                               label.position = "left"))  # Adjust legend label position


#c) Density Map
#Below, I will map deaths associated with storms, creating a density map with each point
#representing a severe weather events that related in at least one death. The darker
#circles will represent more deaths caused by that storm and lighter circles with represent
#less deaths. I will combine both direct and indirect deaths to create a total deaths
#variable. 
#I believe the county-level monetary damage map (part b above) creates the best visualization
#of the distribution of destructive effects of the storms. The density map I create below
#is helpful because it pinpoints each event that results in at least one death and gives
#us an idea of how deadly each of these events was. However, I did filter out all the
#incidents where there were no deaths, so this portrays only a fraction of the event data.
#The state map in part a is a little too broad but the counties map gives a comprehensive
#summary of monetary damage for smaller areas of land so it allows us to zoom in a bit more.
#It also seems monetary damage is more common than deaths so we are able to use more data
#in that map to get a picture of the variation between counties.

#creating simple dataset with total deaths, lat and lon, state name
storm_data_filtered3 <- mutate(storm_data, total_deaths = DEATHS_DIRECT + DEATHS_INDIRECT)
storm_data_filtered3 <- select(storm_data_filtered3, BEGIN_LAT, BEGIN_LON, total_deaths, STATE)

# Filter out rows with missing latitude or longitude values and where there were zero deaths
storm_data_filtered3 <- storm_data_filtered3[complete.cases(storm_data_filtered3$BEGIN_LAT, storm_data_filtered3$BEGIN_LON), ]
storm_data_filtered3 <- filter(storm_data_filtered3, total_deaths != 0)


#I am only going to plot deaths on my map (in continental U.S.) So, I define the values I want to filter out 
#(those not on map of continental US aka filtering out non-first-48 states)
states_to_exclude <- c("PUERTO RICO", "ATLANTIC SOUTH", "ATLANTIC NORTH", "GULF OF MEXICO", "LAKE MICHIGAN", "ALASKA", "HAWAII", "GUAM", "LAKE ERIE")

# Filter out rows where the "state" column equals the specified states to exclude
storm_data_filtered3_continental <- filter(storm_data_filtered3, !(STATE %in% states_to_exclude))

# Load state map data
us.states <- map_data("state")

# Create the plot with state boundaries and storm data points
ggplot() + 
  geom_polygon(data = us.states, aes(x = long, y = lat, group = group), color = "grey", fill = "white") +
  geom_point(data = storm_data_filtered3_continental, aes(x = BEGIN_LON, y = BEGIN_LAT, color = total_deaths)) +
  geom_text(data = merged_final_statedamages, aes(x = state.center.x, y = state.center.y, label = state.abb), color = "black", size = 3) +
  scale_color_gradient(low = "lightgreen", high = "darkgreen", name = "Total Deaths") +
  ggtitle("Density Plotting of Death-Causing Storms") +
  theme_map() +
  theme(
    text = element_text(family = "Times New Roman"),  # Change font to TNR
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    panel.background = element_rect(fill = "white"),  # Set background color to white
    panel.border = element_blank(),  # Remove panel border
    panel.grid.major = element_blank(),  # Remove major gridlines
    panel.grid.minor = element_blank(),  # Remove minor gridlines
    legend.position = c(0.015, 0.015)) +  # Adjust legend position (x, y)
  coord_map(projection = "mercator") +
  guides(fill = guide_colorbar(barwidth = 2, barheight = 5,  # Adjust bar width and height
                               title.position = "top", 
                               label.position = "left"))  # Adjust legend label position

# PART 2 - Location of Severe Events
# a) Interactive Map of Severe Weather Events

#I'm going to alter the original dataset so that I'm only looking at the continental US (first 48 states)
#and also so I only include the incidents that resulted in a death

#first combine direct and indirect deaths
storm_data_alldeathscombined <- mutate(storm_data, total_deaths = DEATHS_DIRECT + DEATHS_INDIRECT)
#now only keeping rows where total death is not zero and getting rid of any rows with missing lat/lon
storm_data_deathsonly <- filter(storm_data_alldeathscombined, total_deaths != 0)
storm_data_deathsonly <- storm_data_deathsonly[complete.cases(storm_data_deathsonly$BEGIN_LAT, storm_data_deathsonly$BEGIN_LON), ]
#now only keeping incidents that happened in continental US (first 48 states)
storm_data_deathsonly_continental <- filter(storm_data_deathsonly, !(STATE %in% states_to_exclude))

#establishing popup content
popup_content <- paste("Type:",storm_data_deathsonly_continental$EVENT_TYPE,"<br/>",
                 "When:",storm_data_deathsonly_continental$MONTH_NAME," ",storm_data_deathsonly_continental$YEAR,"<br/>",
                 "State:",storm_data_deathsonly_continental$STATE,"<br/>",
                 "# of Deaths:",storm_data_deathsonly_continental$total_deaths,"<br/>")

# Defining a function to calculate radius based on zoom level
zoomToRadius <- function(zoom) {
  # Adjusting the multiplier as needed to control the rate of increase in radius with zoom
  base_radius <- 50000  
  radius <- base_radius / zoom
  return(radius)
}

#Using leaflet to add dots where there was at least one death, adding popup option
m <- leaflet(storm_data_deathsonly_continental) %>% 
  addTiles('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png') %>%
  addCircles(lng = ~BEGIN_LON, lat = ~BEGIN_LAT, col = "orange", radius = zoomToRadius(10), popup = popup_content)
m 

#b) Color by Type of Weather Event

unique(storm_data_deathsonly_continental$EVENT_TYPE) #checking the storm types
#let's combine flood/flash flood into a category, Hail/Heavy Rain, Thunderstorm Wind/Lightning/Marine Strong Wind,
#and keep Tornado and Debris Flow separate
target_flood <- c("Flood", "Flash Flood") 
storm_data_deathsonly_continental <- mutate(storm_data_deathsonly_continental,
                     EVENT_TYPE = ifelse(EVENT_TYPE %in% target_flood,
                                         "Flood or Flash Flood",
                                         EVENT_TYPE))
target_heavyrain <- c("Hail", "Heavy Rain") 
storm_data_deathsonly_continental <- mutate(storm_data_deathsonly_continental,
                                            EVENT_TYPE = ifelse(EVENT_TYPE %in% target_heavyrain,
                                                                "Hail or Heavy Rain",
                                                                EVENT_TYPE))
target_windthunlight <- c("Thunderstorm Wind", "Lightning", "Marine Strong Wind") 
storm_data_deathsonly_continental <- mutate(storm_data_deathsonly_continental,
                                            EVENT_TYPE = ifelse(EVENT_TYPE %in% target_windthunlight,
                                                                "Lightning, Thunderstorm Wind or Marine Strong Wind",
                                                                EVENT_TYPE))
#making sure we have 5 distinct categories of events now
unique(storm_data_deathsonly_continental$EVENT_TYPE)



#now preparing to add color
pal = colorFactor("Set1", domain = storm_data_deathsonly_continental$EVENT_TYPE) # Grab a palette
color_EVENT_TYPE = pal(storm_data_deathsonly_continental$EVENT_TYPE)

m2 <- leaflet(storm_data_deathsonly_continental) %>% 
  addTiles('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png') %>%
  addCircles(lng = ~BEGIN_LON, lat = ~BEGIN_LAT, col = color_EVENT_TYPE, radius = zoomToRadius(10), popup = popup_content) %>%
  addLegend(pal = pal, values = ~storm_data_deathsonly_continental$EVENT_TYPE, title = "Type of Death-Causing Event")
m2 

#c) Cluster

# Add marker clustering
m3 <- leaflet(storm_data_deathsonly_continental) %>% 
  addTiles('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png') %>%
  addCircles(lng = ~BEGIN_LON, lat = ~BEGIN_LAT, col = color_EVENT_TYPE, radius = zoomToRadius(10), popup = popup_content) %>%
  addMarkers(data = storm_data_deathsonly_continental, lng = ~BEGIN_LON, lat = ~BEGIN_LAT, clusterOptions = markerClusterOptions())
m3 

# 3. Severe Events and Cities

#Bringing in cities data
file_path2 <- "C:/Users/jenna/Downloads/us-cities-top-1k.csv"
cities_data <- read_csv(file_path2)
head(cities_data)


# Creating a function to calculate distance between any two points using geosphere::distGeo()
calculate_distance <- function(lat1, lon1, lat2, lon2) {
  dist <- distGeo(matrix(c(lon1, lat1), ncol = 2), matrix(c(lon2, lat2), ncol = 2))
  return(dist)
}

#let's create continental only set:
#first combine direct and indirect deaths
#storm_data_alldeathscombined <- mutate(storm_data, total_deaths = DEATHS_DIRECT + DEATHS_INDIRECT)
#now only keeping rows where total death is not zero and getting rid of any rows with missing lat/lon
#storm_data_deathsonly <- filter(storm_data_alldeathscombined, total_deaths != 0)
storm_data_continentalonly <- storm_data[complete.cases(storm_data$BEGIN_LAT, storm_data$BEGIN_LON), ]
#now only keeping incidents that happened in continental US (first 48 states)
storm_data_continentalonly <- filter(storm_data_continentalonly, !(STATE %in% states_to_exclude))

#When I was using my below distance-calculating algorithm, it was taking a really long time. So I'm just
#going to look at the first 10,000 storm entries for this question.
storm_data_subset <- storm_data_continentalonly[1:10000,]

# Iterate through each weather event in the subset and find the nearest city
for (i in 1:nrow(storm_data_subset)) {
  storm_lat <- storm_data_subset[i, "BEGIN_LAT"]
  storm_lon <- storm_data_subset[i, "BEGIN_LON"]
  
  # Calculate distances to all cities
  city_coords <- cities_data[, c("lat", "lon")]
  nn_result <- nn2(city_coords, matrix(c(storm_lat, storm_lon), ncol = 2), k = 1)
  
  # Get the index of the nearest city
  nearest_city_index <- nn_result$nn.idx
  
  # Get the distance to the nearest city
  nearest_city_distance <- nn_result$nn.dists
  
  # Assign the nearest city and its distance to the dataset
  storm_data_subset[i, "nearest_city"] <- cities_data$City[nearest_city_index]
  storm_data_subset[i, "distance_to_nearest_city"] <- nearest_city_distance
}



#Now lets add in population corresponding to each nearest city

# Clean city names in storm_data_subset before merging
storm_data_subset$clean_nearest_city <- tolower(trimws(storm_data_subset$nearest_city))

cities_data$clean_city <- tolower(trimws(cities_data$City))

# Merge storm_data_subset with cities_data based on clean_city
merged_data <- merge(storm_data_subset, cities_data, by.x = "clean_nearest_city", by.y = "clean_city", all.x = TRUE)

#Now, I'm good to go with my merged data
#This time I'll look at all the deaths and injuries combined resulting from each event

merged_data$alldeathsinjuries <- merged_data$DEATHS_INDIRECT + merged_data$DEATHS_DIRECT + merged_data$INJURIES_DIRECT + merged_data$INJURIES_INDIRECT
#let's get entries where there is at least one death or injury
merged_data_deaths_injuries_nonzero <- filter(merged_data, alldeathsinjuries != 0)

#PLOT
# Plot the merged data in one graph - again this is just using the first 10,000 from the original storm data
ggplot(data = merged_data_deaths_injuries_nonzero, aes(x = Population, y = alldeathsinjuries)) +
  geom_line(linewidth = .7) +
  labs(x = "Population of Nearest City (in thousands)", y = "Number or Deaths + Injuries") +  # Reme titles
  theme_minimal() +  #Apply minimal theme
  ggtitle("Effect of Nearest City Population on Deaths and Injuries") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(
    panel.grid.major = element_blank(),  # Remove major gridlines
    axis.line = element_line(color = "black"),  # Set axis line color
    legend.position = "top",  # Position legend at the top
    legend.title = element_text(size = 10),  # Set legend title size
    legend.text = element_text(size = 8)  # Set legend text size
  ) +
  scale_x_continuous(labels = scales::comma_format(scale = 1e-3))

#Let's do the same thing but with money damage from each event this time
merged_data$allmoneydamage <- merged_data$DAMAGE_PROPERTY_USD + merged_data$DAMAGE_CROPS_USD
merged_data <- merged_data %>%
  mutate(allmoneydamage = replace_na(allmoneydamage, 0))
#let's take out events where there was no money damage
merged_data_money_damage_nonzero <- filter(merged_data, allmoneydamage != 0)

#PLOT
ggplot(data = merged_data_money_damage_nonzero, aes(x = Population, y = allmoneydamage)) +
  geom_line(linewidth = .7) +
  labs(x = "Population of Nearest City (in millions)", y = "Amount of Monetary Damage (in millions)") +  
  theme_minimal() +  #Apply minimal theme
  ggtitle("Effect of Nearest City Population on Monetary Damage") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(
    panel.grid.major = element_blank(),  # Remove major gridlines
    axis.line = element_line(color = "black"),  # Set axis line color
    legend.position = "top",  # Position legend at the top
    legend.title = element_text(size = 10),  # Set legend title size
    legend.text = element_text(size = 8)  # Set legend text size
  ) +
  scale_x_continuous(labels = scales::comma_format(scale = 1e-6)) +
  scale_y_continuous(labels = scales::comma_format(scale = 1e-6))


#Let's check out the money damage effects by event type
unique(merged_data_money_damage_nonzero$EVENT_TYPE)

#Setting my collapsed categories
target_flood_rain_hail <- c("Flood", "Flash Flood", "Heavy Rain", "Hail") 
merged_data_money_damage_nonzero <- mutate(merged_data_money_damage_nonzero,
                                            EVENT_TYPE = ifelse(EVENT_TYPE %in% target_flood_rain_hail,
                                                                "Flood, Rain or Hail",
                                                                EVENT_TYPE))
#anything mentioning wind or dust or tornado
target_tornado_wind <- c("Tornado", "Thunderstorm Wind", "Dust Devil", "Marine Thunderstorm Wind", "Marine High Wind") 
merged_data_money_damage_nonzero <- mutate(merged_data_money_damage_nonzero,
                                            EVENT_TYPE = ifelse(EVENT_TYPE %in% target_tornado_wind,
                                                                "Wind, Dust, Tornado",
                                                                EVENT_TYPE))

#everything else
target_misc <- c("Funnel Cloud", "Lightning", "Debris Flow", "Waterspout") 
merged_data_money_damage_nonzero <- mutate(merged_data_money_damage_nonzero,
                      EVENT_TYPE = ifelse(EVENT_TYPE %in% target_misc,
                                          "Other",
                                          EVENT_TYPE))

#making sure we have 5 distinct categories of events now
unique(merged_data_money_damage_nonzero$EVENT_TYPE)

#PLOT
# Plot the merged data in one graph
ggplot(data = merged_data_money_damage_nonzero, aes(x = Population, y = allmoneydamage, color = EVENT_TYPE)) +
  geom_line(linewidth = .7) +
  scale_color_manual(values = c("#E69F00", "#56B4E9", "#009E73")) +
  labs(x = "Population of Nearest City (in millions)", y = "Amount of Monetary Damage (in millions)") +  # Reme titles
  theme_minimal() +  #Apply minimal theme
  ggtitle("Effect of Nearest City Population on Monetary Damage") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(
    panel.grid.major = element_blank(),  # Remove major gridlines
    axis.line = element_line(color = "black"),  # Set axis line color
    legend.position = "top",  # Position legend at the top
    legend.title = element_text(size = 10),  # Set legend title size
    legend.text = element_text(size = 8)  # Set legend text size
  ) +
  scale_x_continuous(labels = scales::comma_format(scale = 1e-6)) +
  scale_y_continuous(labels = scales::comma_format(scale = 1e-6))

#TEXT: In the above chart, we didn't see much of a clear trend. It does look like smaller cities (under a
#quarter million in population) tend to have the most "spikes" around 5-10 million dollars in damage.
#Mostly, these seem to be more flood, rain or hail (orange), with the highest damage spike also being 
#from this category. I want to see if we can zoom in a bit on these smaller cities and see more
#of a trend.

#Now just looking at cities with less than 0.5 million population
last_filtered_data <- merged_data_money_damage_nonzero[merged_data_money_damage_nonzero$Population < 500000,]
ggplot(data = last_filtered_data, aes(x = Population, y = allmoneydamage, color = EVENT_TYPE)) +
  geom_line(linewidth = .7) +
  scale_color_manual(values = c("#E69F00", "#56B4E9", "#009E73")) +
  labs(x = "Population of Nearest City (in thousands)", y = "Amount of Monetary Damage (in millions)") +  # Reme titles
  theme_minimal() +  #Apply minimal theme
  ggtitle("Effect of Nearest City Population on Monetary Damage)") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(
    panel.grid.major = element_blank(),  # Remove major gridlines
    axis.line = element_line(color = "black"),  # Set axis line color
    legend.position = "top",  # Position legend at the top
    legend.title = element_text(size = 10),  # Set legend title size
    legend.text = element_text(size = 8)  # Set legend text size
  ) +
  scale_x_continuous(labels = scales::comma_format(scale = 1e-3)) +
  scale_y_continuous(labels = scales::comma_format(scale = 1e-6))

#Still no real clear trend here, although orange (flood, rain, or hail) still seem to most frequently
#be the cause of significant monetary damage (with one large damage event being from the "other" category).
#We still see that the cluster of higher monetary damage spikes is towards the smaller population size
#end of the graph (left) so maybe smaller cities generally have less advanced infrastructure and funding
#to sufficiently prepare for the consequences of extreme weather events, result in more frequent high-cost damage.



