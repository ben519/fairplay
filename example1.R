# Example 1
# Simulate a league with 9 teams and 8 weeks of play

#======================================================================================================
# Load packages

library(data.table)
library(ggplot2)

#======================================================================================================
# Source scripts

source("helpers.R")

#======================================================================================================

simulate_games <- function(teams, Nrounds = 10){
  # Simulate games with winners and losers
  
  games <- next_round_games(teams, games = NULL, excludeLastKTeams = 2, Nrounds = Nrounds)
  games[, Team1Win := runif(n = .N, min = 0, max = 1) > 0.5]
  
  if(Nrounds == 1) return(games[])
  
  gamesList <- list(games)
  for(rd in seq(2, Nrounds)){
    games <- rbindlist(gamesList)
    newgames <- next_round_games(teams, games, excludeLastKTeams = 2, Nrounds = Nrounds)
    newgames[, Team1Win := runif(n = .N, min = 0, max = 1) > 0.5]
    gamesList <- c(gamesList, list(newgames))
  }
  games <- rbindlist(gamesList)
  
  return(games[])
}

#======================================================================================================
# Simulate

# Build the teams
teams <- make_teams(9)
teams[, Team := c("The Frogs", "The Cats", "The Gerbils", "The Crickets", "The Lizards", "The Pigeons", "The Sloths", 
                  "The Rabbits", "The Worms")]
# Simulate the games
set.seed(0)
games <- simulate_games(teams = teams, Nrounds = 8)

#======================================================================================================
# Make the results presentable

gameteams <- games_to_gameteams(games)
teampts <- team_points(teams, games)

teampts[, PointsGained := shift(Points, type="lead") - Points, by=c("Team")]
gameteams[teampts, StartingPoints := Points, on=c("Team", "Round"="BeforeRound")]
gameteams[teampts, OppSeed := i.Seed, on=c("Opponent"="Team", "Round"="BeforeRound")]
gameteams[teampts, PointsGained := i.PointsGained, on=c("Team", "Round"="BeforeRound")]
gameteams[teampts[, list(Round = BeforeRound - 1, Team, Points)], CmltvPoints := i.Points, on=c("Team", "Round")]

teampts[teampts[BeforeRound == 1], `:=`(StartingSeed = i.Seed, StartingPoints = i.Points), on="Team"]
teams[teampts[BeforeRound == 1], StartingPoints := i.Points, on="Team"]

#======================================================================================================

plot_points_progression(games, team=NULL)
plot_points_progression(games, team="The Crickets")

#======================================================================================================
# source("~/Businesses/GormAnalysis/Clients/_NewClientTemplate/projects/project1/scripts/helpers.R")


teampts[BeforeRound == 1, list(Team, StartingSeed, StartingPoints)]
teampts[BeforeRound == 2][order(StartingSeed), list(Team, StartingSeed, BeforeRd2Seed = Seed, BeforeRd2Points = Points)]

# Team A
gameteams[Team == "A"]
teampts[Team == "A"]

# Team B
gameteams[Team == "B"]
teampts[Team == "B"]

# Team F
gameteams[Team == "F"]
teampts[Team == "F"]

# Team G
gameteams[Team == "G"]
teampts[Team == "G"]

# Team J
gameteams[Team == "J"]
teampts[Team == "J"]

# Team I
gameteams[Team == "I"]
teampts[Team == "J"]
plot_team_games(games, "I")