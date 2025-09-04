---
title: "Building an NFL Over/Under Prediction Model with Machine Learning"
date: 2025-09-04T18:25:59-05:00
categories: ["machine learning", "data science"]
tags: ["nfl", "python", "data scraping", "predictive modeling"]
draft: false
---

The NFL betting market is massive, with billions of dollars wagered annually on everything from game outcomes to point spreads. While professional sportsbooks employ teams of analysts and sophisticated models, the challenge of accurately predicting NFL spreads remains notoriously difficult.

In this project, I set out to build my own machine learning model for predicting NFL point spreads, following along with a [Kerry Sports Analyst YouTube tutorial](https://www.youtube.com/watch?v=03D-1HXcoIM&list=WL&index=18) as my starting point. What began as a simple replication exercise quickly evolved into a comprehensive data science project that involved web scraping, model generation, and API development.

The goal wasn't just to build another prediction model, but to understand the entire pipeline from raw data collection to deployable predictions. Over the course of this project, I scraped 15 years of NFL game data (2009-2024), enhanced it with stadium-specific information, and created a simple API to make predictions accessible.

While the model's accuracy is still being tweaked and adjusted, the process taught me valuable lessons about data science workflows, machine learning, and the challenges of sports prediction.

## Data Collection

The first challenge in building any machine learning model is obtaining quality data. For NFL spread prediction, I needed historical game data including scores, point spreads, and other relevant statistics. Following the [Kerry Sports Analyst tutorial](https://www.youtube.com/watch?v=03D-1HXcoIM&list=WL&index=18), I began by scraping NFL scores and spread data from [Pro-Football-Reference.com](https://www.pro-football-reference.com/). The site provides detailed game logs for every NFL season going back to 2009, including:

- Game scores
- Offensive and defensive team stats
- Point spreads and over/under totals

### Scraping Process

I implemented a two-step approach to ensure data reliability and reproducibility:

1. **Raw HTML Collection**: First, I created a script to systematically download and save the raw HTML from Pro-Football-Reference for each season from 2009-2024. This approach had several advantages:
   - **Rate limiting compliance**: Avoided overwhelming the server with rapid requests
   - **Data preservation**: Ensured I had a local copy of the data in case the site structure changed
   - **Reproducibility**: Could re-parse the data multiple times without re-scraping

2. **Data Parsing**: Using a Jupyter notebook, I then parsed the saved HTML files to extract the relevant game data and generate a clean CSV file. This separation of concerns made the process more manageable and allowed for iterative improvements to the parsing logic.

The scraping covered approximately 15 years of NFL data (2009-2024), which was the full historical dataset available from Pro-Football-Reference. This resulted in thousands of games with comprehensive statistics, providing sufficient training data while focusing on the modern NFL era with consistent rules and playing styles.

### Data Cleaning

Once I had the raw HTML data, the next step was cleaning and preparing the data for machine learning. The initial dataset required several transformations to make it usable:

**Field Renaming**: After using BeautifulSoup to parse the HTML and loading the data into a pandas DataFrame, several columns had generic names like 'Unnamed: 0' that needed to be renamed:
- `Unnamed: 5` → `win` (game outcome)
- `Unnamed: 8` → `away` (away team indicator)
- Similar renaming for other statistical columns to improve readability

**Removing Bye Weeks**: NFL teams have a bye week during the regular season where they don't play. These entries were filtered out since they don't represent actual games and would skew the model training.

**Adding Temporal Features**: To help the model identify potential patterns and trends, I added several time-based columns that could serve as predictive features:
- **Day of Week**: Extracted from game dates to identify if games were played on Thursday, Sunday, or Monday
- **After Bye Week**: Created a boolean column tracking whether each team was coming off a bye week, as teams often perform differently after rest periods

**Data Merging**: One of the more complex aspects of data preparation was merging the game statistics with Vegas betting lines. The initial scraping provided game scores and team stats, but I needed to combine this with historical point spreads and betting data. This required:

- Matching games by date and team names across different data sources
- Ensuring betting line data was available for the corresponding game dates
- Dealing with missing or incomplete betting data for certain games

These cleaning steps transformed the raw scraped data into a structured dataset ready for feature engineering and model training. The process also involved handling missing values, standardizing team names across different seasons, and ensuring consistent data types for all columns. I then saved the data to a clean CSV file with the columns below:

```bash
RangeIndex: 8690 entries, 0 to 8689
Data columns (total 34 columns):
 #   Column             Non-Null Count  Dtype  
---  ------             --------------  -----  
 0   Season             8690 non-null   int64  
 1   Team               8690 non-null   object 
 2   Opp                8690 non-null   object 
 3   Away               8690 non-null   int64  
 4   Week               8690 non-null   object 
 5   AfterBye           8690 non-null   int64  
 6   Playoff            8690 non-null   int64  
 7   Day                8690 non-null   object 
 8   DayOfWeek          8690 non-null   int64  
 9   Date               8690 non-null   object 
 10  Month              8690 non-null   int64  
 11  Time               8690 non-null   object 
 12  Win                8690 non-null   int64  
 13  OT                 8690 non-null   int64  
 14  Rec                8690 non-null   object 
 15  PtsScored          8690 non-null   int64  
 16  PtsAllowed         8690 non-null   int64  
 17  Off1stD            8690 non-null   int64  
 18  OffTotYd           8690 non-null   int64  
 19  OffPassY           8690 non-null   int64  
 20  OffRushY           8690 non-null   int64  
 21  OffTO              8690 non-null   int64  
 22  Def1stD            8690 non-null   int64  
 23  DefTotYd           8690 non-null   int64  
 24  DefPassY           8690 non-null   int64  
 25  DefRushY           8690 non-null   int64  
 26  DefTO              8690 non-null   int64  
 27  ExpPoints_Offense  8690 non-null   float64
 28  ExpPoints_Defense  8690 non-null   float64
 29  G#                 8690 non-null   int64  
 30  Spread             8690 non-null   float64
 31  OU                 8690 non-null   float64
 32  SpreadWin          8690 non-null   int64  
 33  OUWin              8690 non-null   object
```

## Initial Model Training

With the cleaned dataset ready, I moved to the model training phase. I loaded the generated CSV file into a Jupyter Lab notebook using pandas and began the process of preparing the data for machine learning.

### Feature Selection

I started by selecting only the columns I wanted to train on, focusing on the most relevant features for spread prediction:

```python
selected_columns = ['Season', 'Week', 'AfterBye', 'Date', 'Month', 'DayOfWeek', 
                   'Tm_Name', 'Tm_Pts', 'Away', 'Opp_Name', 'Opp_Pts', 'Spread', 'Total']
```

I then performed several key data transformations:

**Over/Under Classification**: I added columns to track betting outcomes:
- **Over/Under Result**: Created a column indicating whether the total points scored was over, under, or push (exactly equal to the total line)

**Data Sorting**: Sorted the data by season and then by week to ensure proper chronological order for time-series analysis.

**Training Data Filtering**: Applied specific filters to create the training dataset:
- **Time Period**: Only games from 2018 onwards to focus on recent NFL trends
- **Away Games Only**: Since each game appears twice in the dataset (once for each team), I filtered to only away games to avoid data duplication
- **Feature Set**: Trained the model on three key features:
  - `Spread`: The point spread for the game
  - `Total`: The over/under total points line
  - `AfterBye`: Whether the team was coming off a bye week
- **Prediction Target**: The model was trained to predict games for "Under the total" - identifying when the total points scored would be under the Vegas over/under line

### Model Implementation

For the initial model, I used a K-Nearest Neighbors classifier with 7 neighbors:

```python
from sklearn.neighbors import KNeighborsClassifier
model = KNeighborsClassifier(n_neighbors=7)
```

**Results Validation**: Following Kerry's approach, I generated a confusion matrix to visualize the model's performance and compared my results with what Kerry achieved in his tutorial. This validation step was crucial to ensure I had correctly implemented the same methodology.

**Historical Comparison**: Kerry's video only covered data up until 2023, so my 2024 predictions represented new territory not covered in the original tutorial. This provided an opportunity to test the model's performance on completely unseen data and compare the accuracy.

**Prediction Accuracy Results**: The model's performance for predicting "Under the total" across different years:

- **2021**: 54% accurate
- **2022**: 59% accurate  
- **2023**: 53% accurate
- **2024**: 48% accurate

The results show the model performed reasonably well in the 2021-2023 period, with 2022 being the strongest year at 59% accuracy. The 2024 performance dropped to 48%, highlighting the challenges of sports prediction and the importance of continuous model refinement.


## Enhanced Data Collection

After validating the initial model, I decided to enhance the dataset with additional environmental and venue-specific information that could potentially improve prediction accuracy. I scraped additional data from [NFLWeather](https://nflweather.com/) for each game including:

- **Weather conditions**: Temperature, precipitation, wind speed, and other weather factors that could affect game outcomes
- **Stadium type**: Whether the game was played in a dome (indoor) or open-air stadium
- **Grass type**: Whether the playing surface was artificial turf or natural grass
- **Location**: Whether games were played in the US or internationally (London, Mexico, etc.)

Once I had collected this additional information, I combined it with the existing game stats data from the previous dataset. This integration required:

- **Matching games**: Ensuring the weather and stadium data corresponded to the correct games in the original dataset
- **Data validation**: Verifying that the additional information was accurate and complete
- **Feature engineering**: Creating new columns to represent the environmental factors in a format suitable for machine learning

The enhanced dataset now included both the original game statistics and the new environmental variables, providing a more comprehensive foundation for model training and potentially better prediction accuracy. The final dataset contained 4,158 entries with 53 columns, including the original game data plus the new stadium and weather information:

```bash
RangeIndex: 4158 entries, 0 to 4157
Data columns (total 53 columns):
 #   Column                    Non-Null Count  Dtype  
---  ------                    --------------  -----  
 0   Season                    4158 non-null   int64  
 1   Team                      4158 non-null   object 
 2   Opp                       4158 non-null   object 
 3   Away                      4158 non-null   int64  
 4   Week                      4158 non-null   int64  
 5   AfterBye                  4158 non-null   int64  
 6   Playoff                   4158 non-null   int64  
 7   Day                       4158 non-null   object 
 8   DayOfWeek                 4158 non-null   int64  
 9   Date                      4158 non-null   object 
 10  Month                     4158 non-null   int64  
 11  Time                      4158 non-null   object 
 12  Win                       4158 non-null   int64  
 13  OT                        4158 non-null   int64  
 14  Rec                       4158 non-null   object 
 15  PtsScored                 4158 non-null   int64  
 16  PtsAllowed                4158 non-null   int64  
 17  Off1stD                   4158 non-null   int64  
 18  OffTotYd                  4158 non-null   int64  
 19  OffPassY                  4158 non-null   int64  
 20  OffRushY                  4158 non-null   int64  
 21  OffTO                     4158 non-null   int64  
 22  Def1stD                   4158 non-null   int64  
 23  DefTotYd                  4158 non-null   int64  
 24  DefPassY                  4158 non-null   int64  
 25  DefRushY                  4158 non-null   int64  
 26  DefTO                     4158 non-null   int64  
 27  ExpPoints_Offense         4158 non-null   float64
 28  ExpPoints_Defense         4158 non-null   float64
 29  G#                        4158 non-null   int64  
 30  Spread                    4158 non-null   float64
 31  OU                        4158 non-null   float64
 32  SpreadWin                 4158 non-null   int64  
 33  OUWin                     4158 non-null   object 
 34  Stadium                   4158 non-null   object 
 35  City                      4158 non-null   object 
 36  State                     4158 non-null   object 
 37  International             4158 non-null   int64  
 38  Grass                     4158 non-null   object 
 39  Dome                      4158 non-null   int64  
 40  Capacity                  4158 non-null   int64  
 41  Address                   4158 non-null   object 
 42  Zipcode                   4158 non-null   int64  
 43  kickoffWeatherOverview    4158 non-null   object 
 44  kickoffWeatherTemp        4158 non-null   int64  
 45  kickoffWeatherAirSpeed    4158 non-null   int64  
 46  kickoffWeatherAirGust     4158 non-null   int64  
 47  kickoffWeatherAirDir      4158 non-null   object 
 48  kickoffWeatherPrec        4158 non-null   int64  
 49  kickoffWeatherCloudCover  4158 non-null   int64  
 50  kickoffWeatherHumidity    4158 non-null   int64  
 51  kickoffWeatherDewPoint    4158 non-null   int64  
 52  kickoffWeatherVisability  4158 non-null   int64
```

### Model Retraining

With the enhanced dataset now including environmental and venue information, I retrained the model using the same K-Nearest Neighbors technique but with an expanded feature set. The new model incorporated the following features:

- `Spread`: The point spread for the game
- `Total`: The over/under total points line  
- `AfterBye`: Whether the team was coming off a bye week
- `Dome`: Whether the game was played in a dome (indoor) stadium

**Enhanced Model Results**: The retrained model's performance for predicting "Under the total" across different years:

- **2021**: 56% accurate
- **2022**: 57% accurate
- **2023**: 50% accurate
- **2024**: 47% accurate

The addition of the dome feature provided modest improvements in 2021 and 2022, with accuracy increasing by 2% and maintaining the 57% level respectively. However, the model still struggled with 2023 and 2024 predictions, with 2024 dropping to 47% accuracy - well below the profitable threshold. This suggests that while environmental factors can provide some predictive value, they may not be sufficient to overcome the inherent challenges of NFL prediction, particularly in more recent seasons.

## API Development

To make the model easily accessible for generating 2025 predictions, I created a simple Flask API server. This provided a convenient way to run the model without needing to load Jupyter notebooks or manage the data pipeline manually.

The Flask API accepts POST requests to the `/games` endpoint with an array of game objects. Each game object contains the following parameters:

- `Game`: The matchup (e.g., "Cowboys @ Eagles")
- `Spread`: The point spread for the game
- `Total`: The over/under total points line
- `AfterBye`: Whether the team is coming off a bye week (0 or 1)
- `Dome`: Whether the game is played in a dome stadium (0 or 1)

**Request Example**:
```bash
curl -X POST "http://localhost:7200/games" \
  -H "Content-Type: application/json" \
  -d '{
    "games": [
      {
        "AfterBye": 0,
        "Dome": 0,
        "Game": "Cowboys @ Eagles",
        "Spread": -8.5,
        "Total": 48.5
      }
    ]
  }'
```

**Response Example**:
```json
{
  "games": [
    {
      "Game": "Cowboys @ Eagles",
      "Prediction": "Under"
    }
  ]
}
```

This API design allows for easy integration with other applications or manual testing of specific game scenarios. The JSON format makes it simple to build frontend interfaces or integrate with other systems for automated prediction workflows.

## 2025 Week 1 Predictions

Based on my adjusted ML model, below are my predictions for games under the Vegas lines. The betting lines were pulled from FanDuel and represent the current spreads and totals for Week 1 of the 2025 NFL season.

| Game | Spread | Total |
|------|--------|-------|
| Cowboys @ Eagles | -8.5 | 48.5 |
| Chiefs @ Chargers | 3.0 | 46.5 |
| Giants @ Commanders | -5.5 | 45.5 |
| Cardinals @ Saints | 6.5 | 42.5 |
| Bengals @ Browns | 5.5 | 47.5 |
| Titans @ Broncos | -8.5 | 42.5 |
| Texans @ Rams | -3 | 43.5 |
| Ravens @ Bills | 1.5 | 50.5 |
| Vikings @ Bears | 1.5 | 43.5 |


These predictions represent 9 out of the 16 total Week 1 games. The remaining 7 games did not meet the model's confidence threshold for making predictions. As with any sports prediction model, these should be used for informational purposes and not as guaranteed betting advice.


## Acknowledgment

I'd like to acknowledge [Kerry Sports Analyst](https://www.youtube.com/@KerrySportsAnalyst) for his excellent YouTube tutorials on building predictive models. His videos have been incredibly useful for learning the fundamentals of sports data analysis and machine learning implementation. For anyone interested in this field, I highly recommend not only checking out his predictive model videos but also exploring his content on identifying trends and patterns in sports data. His approach to breaking down complex concepts into digestible tutorials made this project much more accessible.


## References

- https://www.youtube.com/@KerrySportsAnalyst
- https://www.youtube.com/watch?v=03D-1HXcoIM&list=WL&index=18
- https://www.pro-football-reference.com/
- https://nflweather.com/
