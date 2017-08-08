# Create a league where strong teams play strong teams and weak teams play weak teams

#======================================================================================================
# Load packages

library(data.table)
library(ggplot2)

#======================================================================================================
# Methods

games_to_gameteams <- function(games){
  # Build a set of (game, team) rows from a set of games
  
  gameteams <- rbind(
    games[, list(Round, Team = Team1, Opponent = Team2, Won = Team1Win)],
    games[, list(Round, Team = Team2, Opponent = Team1, Won = !Team1Win)]
  )[order(Round, Team)]
  return(gameteams)
}

make_teams <- function(n){
  # Create a data.table of n teams
  
  data.table(
    Team = LETTERS[seq(n)],
    StartingSeed = seq(n)
  )
}

next_round_games <- function(teams, games=NULL, excludeLastKTeams = 2, Nrounds){
  # Determine the next round of games
  # If excludeLastKTeams = 2, team X will not play the recent 2 teams it just played
  # If games is NULL or length 0, it's assumbe to be round 1
  
  # Determine which teams have a bye week and when
  if(nrow(teams) %% 2 == 1){
    noplayschedule <- data.table(Round = seq_len(Nrounds), Team = rev(teams$Team)[(seq_len(Nrounds) - 1L) %% nrow(teams) + 1L])
  } else{
    noplayschedule <- data.table(Round = integer(0), Team = character(0))
  }
  
  #--------------------------------------------------
  # Games for round 1
  
  if(is.null(games)) games <- data.table(Round = integer(0), Team1 = character(0), Team2 = character(0), Team1Win = logical(0))
  if(nrow(games) == 0){
    tempteams <- teams[!noplayschedule[Round == 1, list(Team)], on="Team"]
    newgames <- data.table(
      Round = 1L,
      Team1 = tempteams$Team[seq(1, nrow(tempteams), by=2)],
      Team2 = tempteams$Team[seq(2, nrow(tempteams), by=2)]
    )
    newgames[, Team1Win := NA]
    return(newgames)
  }
  
  #--------------------------------------------------
  # Games for round > 1
  
  rd <- max(games$Round) + 1L
  
  # Get the current seed and points for each team
  teamPts <- team_points(teams = teams, games = games)[BeforeRound == rd]
  teamPts <- teamPts[order(Seed)]
  
  # Build gameteams from games
  gameteams <- games_to_gameteams(games)
  
  # Starting with the highest seed, determine matchups for this round
  newgames <- list()
  gameteams <<- gameteams
  rd <<- rd
  teamPts <<- teamPts
  noplayschedule <<- noplayschedule
  
  # if(rd == 8) stop("bleh")
  
  # How to do this..
  # Build a table of all theoretically possible matchups
  possiblegames <- CJ(Team1 = teams$Team, Team2 = teams$Team)
  possiblegames <- possiblegames[Team1 < Team2]
  
  # Exclude teams that can't play in this round
  possiblegames <- possiblegames[!noplayschedule[Round == rd, list(Team)], on=c("Team1"="Team")]
  possiblegames <- possiblegames[!noplayschedule[Round == rd, list(Team)], on=c("Team2"="Team")]
  
  # Now, for all games where a team plays the team it played in the recent 2 games
  recentgames <- gameteams[gameteams[, .I[order(-Round) <= 2], by=Team]$V1]
  recentgames[, GamesAgo := rev(seq_len(.N)), by=Team]
  recentgames <- recentgames[, list(
    Team1 = ifelse(Team < Opponent, Team, Opponent), 
    Team2 = ifelse(Team < Opponent, Opponent, Team),
    GamesAgo
  )]
  recentgames <- recentgames[, list(GamesAgo = min(GamesAgo)), keyby=list(Team1, Team2)]
  possiblegames <- possiblegames[recentgames, GamesAgo := i.GamesAgo, on=c("Team1", "Team2")]
  
  # Insert Points
  possiblegames[teamPts, Team1Points := i.Points, on=c("Team1"="Team")]
  possiblegames[teamPts, Team2Points := i.Points, on=c("Team2"="Team")]
  possiblegames[, PointDiff := abs(Team1Points - Team2Points)]
  
  # Now pick off the worst matchups until each team has one possible opponent left
  possiblegames <- possiblegames[order(GamesAgo, -PointDiff)]
  
  newgames <- list()
  while(nrow(possiblegames) > 0){
    # Fill me in
    
    teamcounts <- data.table(Team = c(possiblegames$Team1, possiblegames$Team2))
    teamcounts <- teamcounts[, list(.N), keyby=Team]
    teamcounts1 <- teamcounts[N == 1]
    
    if(nrow(teamcounts1) > 0){
      # At least one team only has 1 possible game remaining. Use it
      
      teamcounts1 <- teamcounts1[1]
      newgame <- rbind(
        possiblegames[teamcounts1[, list(Team)], on=c("Team1"="Team"), nomatch=0],
        possiblegames[teamcounts1[, list(Team)], on=c("Team2"="Team"), nomatch=0]
      )
      possiblegames <- possiblegames[!newgame, on=c("Team1"="Team1")]
      possiblegames <- possiblegames[!newgame, on=c("Team1"="Team2")]
      possiblegames <- possiblegames[!newgame, on=c("Team2"="Team1")]
      possiblegames <- possiblegames[!newgame, on=c("Team2"="Team2")]
      newgames <- c(newgames, list(newgame))
    } else{
      possiblegames <- tail(possiblegames, -1)
    }
  }
  newgames <- rbindlist(newgames)
  newgames[, Round := rd]
  
  # clean up
  newgames <- newgames[, list(Round, Team1, Team2, Team1Win=NA)]
  
  return(newgames)
}

simulate_games <- function(teams, Nrounds = 10){
  # Simulate games with winners and losers
  
  games <- next_round_games(teams, games = NULL, excludeLastKTeams = 2, Nrounds = Nrounds)
  games[, Team1Win := runif(n = .N, min = 0, max = 1) > 0.4]
  
  if(Nrounds == 1) return(games[])
  
  gamesList <- list(games)
  for(rd in seq(2, Nrounds)){
    games <- rbindlist(gamesList)
    newgames <- next_round_games(teams, games, excludeLastKTeams = 2, Nrounds = Nrounds)
    newgames[, Team1Win := runif(n = .N, min = 0, max = 1) > 0.4]
    gamesList <- c(gamesList, list(newgames))
  }
  games <- rbindlist(gamesList)
  
  return(games[])
}

team_points <- function(teams, games=NULL){
  # Returns a data.table with the number of points for each team, before the start of the given round
  
  # Score points as follows:
  # Consider a game, team X vs team Y, where team X is the 5 seed and team Y is the 7 seed
  # Also suppose there are 12 total teams in the league
  # If team X beats team Y, team X gains (12-7 = 5) points and team Y loses 5 points
  # If team team Y beats team X, team Y gains (12-5 = 7) points and team X loses 7 points
  # Each team starts the season with points = number of teams - starting seed
  # If a team does not play in a given round, that team receives 0 points for the round. (Forfeitting counts as a loss)
  
  # Insert Seed and starting points
  round1seeds <- teams[, list(BeforeRound = 1L, Team, Seed = StartingSeed, Points = .N - StartingSeed)]
  
  # If games is NULL or length 0, return round1seeds
  if(is.null(games)) return(round1seeds)
  if(nrow(games) == 0) return(round1seeds)
  
  # Build a list of tables of (round, team)s
  roundseeds <- list(round1seeds)
  
  for(rd in seq(2, max(games$Round)+1L)){
    
    # Get the results from the previous round.  1 row per (game, team)
    gameteams <- games_to_gameteams(games[Round <= rd - 1])
    
    # Determine the starting seed of each team for the previous round
    roundseedsDT <- rbindlist(roundseeds)
    gameteams[roundseedsDT, TeamSeed := i.Seed, on=c("Round"="BeforeRound", "Team")]
    gameteams[roundseedsDT, OpponentSeed := i.Seed, on=c("Round"="BeforeRound", "Opponent"="Team")]
    gameteams[, Points := ifelse(Won == TRUE, nrow(teams), -OpponentSeed)]
    
    # Aggregate
    teamPts <- rbind(
      roundseedsDT[BeforeRound == 1, list(Team, Points)],
      gameteams[, list(Team, Points)]
    )
    teamPts <- teamPts[, list(Points = sum(Points)), keyby=Team]
    
    # Determine new seeds
    teamPts[, Seed := frank(-Points, ties.method = "first")]
    teamPts[, BeforeRound := rd]
    roundseeds <- c(roundseeds, list(teamPts[, list(BeforeRound, Team, Seed, Points)]))
  }
  roundseeds <- rbindlist(roundseeds)
  
  return(roundseeds)
}

#======================================================================================================

plot_team_games <- function(games, team="A"){
  # Show the progression for a single team
  
  gameteams <- games_to_gameteams(games)
  teampts <- team_points(teams, games)
  edges <- gameteams[Team == team]
  edges[teampts, TeamPts := Points, on=c("Round"="BeforeRound", "Team")]
  edges[teampts, OppPts := Points, on=c("Round"="BeforeRound", "Opponent"="Team")]
  ggplot(teampts, aes(x=BeforeRound, y=Points, group=Team))+geom_line(size=0.5, color="grey")+
    geom_line(data=teampts[Team == team], color="red", size=1.5)+
    geom_segment(data=edges, aes(x=Round, xend=Round, y=TeamPts, yend=OppPts), color="blue")+
    scale_x_continuous(breaks = sort(unique(teampts$BeforeRound)))+
    labs(
      title = paste("Progression for team", team), 
      subtitle = paste0("Starting seed: ", teams[Team == team]$StartingSeed, ".  Final seed: ", tail(teampts[Team == team]$Seed))
    )+theme_bw()
}

plot_team_games(games, "A")
plot_team_games(games, "B")
plot_team_games(games, "C")

#======================================================================================================
# Simulate a league

set.seed(0)
teams <- make_teams(10)
games <- simulate_games(teams = teams, Nrounds = 8)
gameteams <- games_to_gameteams(games)
teampts <- team_points(teams, games)
teampts[, PointsGained := shift(Points, type="lead") - Points, by=c("Team")]
gameteams[teampts, StartingPoints := Points, on=c("Team", "Round"="BeforeRound")]
gameteams[teampts, OpponentSeed := i.Seed, on=c("Opponent"="Team", "Round"="BeforeRound")]
gameteams[teampts, PointsGained := i.PointsGained, on=c("Team", "Round"="BeforeRound")]
gameteams[teampts[, list(Round = BeforeRound - 1, Team, Points)], ResultingCumulativePoints := i.Points, on=c("Team", "Round")]

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
