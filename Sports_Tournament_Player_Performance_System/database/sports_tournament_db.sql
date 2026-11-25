-- ============================================================
-- SPORTS TOURNAMENT & PLAYER PERFORMANCE MANAGEMENT SYSTEM
-- MySQL 8.0+ | Run the complete script in MySQL Workbench
-- ============================================================

CREATE DATABASE IF NOT EXISTS sports_tournament_db;
USE sports_tournament_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS vw_player_performance;
DROP VIEW IF EXISTS vw_tournament_standings;
DROP VIEW IF EXISTS vw_match_summary;
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS player_match_stats;
DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS tournament_teams;
DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS tournaments;
DROP TABLE IF EXISTS venues;
DROP TABLE IF EXISTS app_users;
SET FOREIGN_KEY_CHECKS = 1;

-- UNIT 1: RELATIONAL MODEL, KEYS, RELATIONSHIPS & NORMALIZATION

CREATE TABLE app_users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('ADMIN','ORGANIZER','ANALYST') NOT NULL DEFAULT 'ANALYST',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE venues (
    venue_id INT AUTO_INCREMENT PRIMARY KEY,
    venue_name VARCHAR(120) NOT NULL,
    city VARCHAR(80) NOT NULL,
    capacity INT UNSIGNED,
    CONSTRAINT chk_venue_capacity CHECK (capacity IS NULL OR capacity > 0)
) ENGINE=InnoDB;

CREATE TABLE teams (
    team_id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL UNIQUE,
    coach_name VARCHAR(100),
    home_city VARCHAR(80),
    founded_year YEAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE players (
    player_id INT AUTO_INCREMENT PRIMARY KEY,
    team_id INT NOT NULL,
    player_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    playing_role ENUM('BATTER','BOWLER','ALL_ROUNDER','WICKET_KEEPER') NOT NULL,
    jersey_number INT,
    nationality VARCHAR(60),
    CONSTRAINT uq_team_jersey UNIQUE (team_id, jersey_number),
    CONSTRAINT fk_player_team FOREIGN KEY (team_id)
        REFERENCES teams(team_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_jersey CHECK (jersey_number IS NULL OR jersey_number BETWEEN 1 AND 99)
) ENGINE=InnoDB;

CREATE TABLE tournaments (
    tournament_id INT AUTO_INCREMENT PRIMARY KEY,
    tournament_name VARCHAR(150) NOT NULL,
    sport_name VARCHAR(60) NOT NULL DEFAULT 'Cricket',
    format_name ENUM('LEAGUE','KNOCKOUT','GROUP_AND_KNOCKOUT') NOT NULL DEFAULT 'LEAGUE',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status ENUM('UPCOMING','ONGOING','COMPLETED') NOT NULL DEFAULT 'UPCOMING',
    organizer_id INT NULL,
    CONSTRAINT fk_tournament_organizer FOREIGN KEY (organizer_id)
        REFERENCES app_users(user_id) ON DELETE SET NULL,
    CONSTRAINT chk_tournament_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB;

-- M:N relationship between tournaments and teams
CREATE TABLE tournament_teams (
    tournament_id INT NOT NULL,
    team_id INT NOT NULL,
    group_name VARCHAR(20),
    points INT NOT NULL DEFAULT 0,
    PRIMARY KEY (tournament_id, team_id),
    CONSTRAINT fk_tt_tournament FOREIGN KEY (tournament_id)
        REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    CONSTRAINT fk_tt_team FOREIGN KEY (team_id)
        REFERENCES teams(team_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE matches (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    tournament_id INT NOT NULL,
    venue_id INT,
    team1_id INT NOT NULL,
    team2_id INT NOT NULL,
    match_date DATETIME NOT NULL,
    status ENUM('SCHEDULED','LIVE','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
    team1_score INT NOT NULL DEFAULT 0,
    team2_score INT NOT NULL DEFAULT 0,
    winner_team_id INT NULL,
    result_summary VARCHAR(255),
    CONSTRAINT fk_match_tournament FOREIGN KEY (tournament_id)
        REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    CONSTRAINT fk_match_venue FOREIGN KEY (venue_id)
        REFERENCES venues(venue_id) ON DELETE SET NULL,
    CONSTRAINT fk_match_team1 FOREIGN KEY (team1_id)
        REFERENCES teams(team_id) ON DELETE RESTRICT,
    CONSTRAINT fk_match_team2 FOREIGN KEY (team2_id)
        REFERENCES teams(team_id) ON DELETE RESTRICT,
    CONSTRAINT fk_match_winner FOREIGN KEY (winner_team_id)
        REFERENCES teams(team_id) ON DELETE SET NULL,
    CONSTRAINT chk_different_teams CHECK (team1_id <> team2_id),
    CONSTRAINT chk_scores CHECK (team1_score >= 0 AND team2_score >= 0)
) ENGINE=InnoDB;

-- Bridge table: one row per player per match
CREATE TABLE player_match_stats (
    stat_id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT NOT NULL,
    player_id INT NOT NULL,
    runs_scored INT NOT NULL DEFAULT 0,
    balls_faced INT NOT NULL DEFAULT 0,
    wickets_taken INT NOT NULL DEFAULT 0,
    overs_bowled DECIMAL(4,1) NOT NULL DEFAULT 0.0,
    catches_taken INT NOT NULL DEFAULT 0,
    minutes_played INT NOT NULL DEFAULT 0,
    UNIQUE KEY uq_player_match (match_id, player_id),
    CONSTRAINT fk_stats_match FOREIGN KEY (match_id)
        REFERENCES matches(match_id) ON DELETE CASCADE,
    CONSTRAINT fk_stats_player FOREIGN KEY (player_id)
        REFERENCES players(player_id) ON DELETE RESTRICT,
    CONSTRAINT chk_stats_nonnegative CHECK (
        runs_scored >= 0 AND balls_faced >= 0 AND wickets_taken >= 0
        AND overs_bowled >= 0 AND catches_taken >= 0 AND minutes_played >= 0
    )
) ENGINE=InnoDB;

CREATE TABLE audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    record_id INT NOT NULL,
    action_type VARCHAR(20) NOT NULL,
    action_details VARCHAR(500),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- UNIT 2: INDEXING
CREATE INDEX idx_players_team ON players(team_id);
CREATE INDEX idx_players_name ON players(player_name);
CREATE INDEX idx_matches_date ON matches(match_date);
CREATE INDEX idx_matches_tournament_status ON matches(tournament_id, status);
CREATE INDEX idx_stats_player ON player_match_stats(player_id);
CREATE INDEX idx_tournaments_status_dates ON tournaments(status, start_date, end_date);

-- SAMPLE DATA
INSERT INTO app_users (full_name,email,password_hash,role) VALUES
('System Administrator','admin@sports.local','demo_hash_change_me','ADMIN'),
('Tournament Organizer','organizer@sports.local','demo_hash_change_me','ORGANIZER');

INSERT INTO venues (venue_name,city,capacity) VALUES
('National Sports Arena','New Delhi',50000),
('University Cricket Ground','Gurugram',12000),
('City Stadium','Chandigarh',30000);

INSERT INTO teams (team_name,coach_name,home_city,founded_year) VALUES
('Delhi Strikers','Rahul Mehta','Delhi',2010),
('Punjab Panthers','Aman Singh','Pathankot',2012),
('Haryana Hawks','Vikram Rao','Gurugram',2015),
('Mumbai Mariners','Karan Shah','Mumbai',2008);

INSERT INTO players (team_id,player_name,date_of_birth,playing_role,jersey_number,nationality) VALUES
(1,'Arjun Sharma','2001-04-12','BATTER',18,'India'),
(1,'Dev Malhotra','2000-08-22','BOWLER',7,'India'),
(1,'Kabir Verma','2002-01-05','ALL_ROUNDER',33,'India'),
(2,'Rohan Gill','2001-11-17','BATTER',10,'India'),
(2,'Ishaan Brar','1999-06-30','WICKET_KEEPER',1,'India'),
(2,'Manav Sandhu','2000-02-14','BOWLER',22,'India'),
(3,'Yuvraj Malik','2001-09-09','ALL_ROUNDER',8,'India'),
(3,'Aarav Dahiya','2002-03-19','BATTER',27,'India'),
(4,'Rehan Khan','2000-12-01','BOWLER',11,'India'),
(4,'Aditya Rao','2001-07-25','BATTER',45,'India');

INSERT INTO tournaments (tournament_name,sport_name,format_name,start_date,end_date,status,organizer_id) VALUES
('Intercity Champions Cup 2026','Cricket','LEAGUE','2026-11-01','2026-11-20','ONGOING',2),
('Winter Sports Series 2026','Cricket','KNOCKOUT','2026-12-05','2026-12-18','UPCOMING',2);

INSERT INTO tournament_teams (tournament_id,team_id,group_name,points) VALUES
(1,1,'A',3),(1,2,'A',0),(1,3,'B',3),(1,4,'B',0),
(2,1,'A',0),(2,2,'A',0),(2,3,'B',0),(2,4,'B',0);

INSERT INTO matches (tournament_id,venue_id,team1_id,team2_id,match_date,status,team1_score,team2_score,winner_team_id,result_summary) VALUES
(1,1,1,2,'2026-11-02 14:00:00','COMPLETED',178,164,1,'Delhi Strikers won by 14 runs'),
(1,2,3,4,'2026-11-04 14:00:00','COMPLETED',151,145,3,'Haryana Hawks won by 6 runs'),
(1,1,1,3,'2026-11-08 15:00:00','SCHEDULED',0,0,NULL,NULL),
(1,3,2,4,'2026-11-10 15:00:00','SCHEDULED',0,0,NULL,NULL);

INSERT INTO player_match_stats
(match_id,player_id,runs_scored,balls_faced,wickets_taken,overs_bowled,catches_taken,minutes_played) VALUES
(1,1,72,48,0,0.0,1,110),
(1,2,8,6,3,4.0,0,110),
(1,3,35,22,1,2.0,1,110),
(1,4,54,39,0,0.0,0,110),
(1,5,20,14,0,0.0,1,110),
(1,6,12,8,2,4.0,0,110),
(2,7,61,40,1,3.0,0,105),
(2,8,44,31,0,0.0,1,105),
(2,9,18,12,2,4.0,0,105),
(2,10,50,36,0,0.0,1,105);

-- UNIT 2: VIEWS for reporting and analytics
CREATE OR REPLACE VIEW vw_player_performance AS
SELECT p.player_id, p.player_name, t.team_name, p.playing_role,
       COUNT(DISTINCT s.match_id) AS matches_played,
       COALESCE(SUM(s.runs_scored),0) AS total_runs,
       COALESCE(SUM(s.wickets_taken),0) AS total_wickets,
       COALESCE(SUM(s.catches_taken),0) AS total_catches,
       ROUND(AVG(NULLIF(s.runs_scored,0)),2) AS average_runs_per_scored_innings
FROM players p
JOIN teams t ON p.team_id = t.team_id
LEFT JOIN player_match_stats s ON p.player_id = s.player_id
GROUP BY p.player_id,p.player_name,t.team_name,p.playing_role;

CREATE OR REPLACE VIEW vw_tournament_standings AS
SELECT tt.tournament_id, tr.tournament_name, t.team_id, t.team_name,
       COUNT(m.match_id) AS matches_scheduled,
       SUM(CASE WHEN m.status='COMPLETED' THEN 1 ELSE 0 END) AS matches_completed,
       SUM(CASE WHEN m.status='COMPLETED' AND m.winner_team_id=t.team_id THEN 1 ELSE 0 END) AS wins,
       SUM(CASE WHEN m.status='COMPLETED' AND m.winner_team_id IS NOT NULL
                 AND m.winner_team_id<>t.team_id THEN 1 ELSE 0 END) AS losses,
       tt.points
FROM tournament_teams tt
JOIN tournaments tr ON tr.tournament_id=tt.tournament_id
JOIN teams t ON t.team_id=tt.team_id
LEFT JOIN matches m ON m.tournament_id=tt.tournament_id
  AND (m.team1_id=t.team_id OR m.team2_id=t.team_id)
GROUP BY tt.tournament_id,tr.tournament_name,t.team_id,t.team_name,tt.points;

CREATE OR REPLACE VIEW vw_match_summary AS
SELECT m.match_id,tr.tournament_name,m.match_date,
       t1.team_name AS team1,m.team1_score,t2.team_name AS team2,m.team2_score,
       tv.venue_name,m.status,m.result_summary
FROM matches m
JOIN tournaments tr ON tr.tournament_id=m.tournament_id
JOIN teams t1 ON t1.team_id=m.team1_id
JOIN teams t2 ON t2.team_id=m.team2_id
LEFT JOIN venues tv ON tv.venue_id=m.venue_id;

-- UNIT 3: TRIGGERS & AUDIT
DELIMITER //
CREATE TRIGGER trg_match_result_audit
AFTER UPDATE ON matches
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status OR OLD.team1_score <> NEW.team1_score
       OR OLD.team2_score <> NEW.team2_score OR NOT (OLD.winner_team_id <=> NEW.winner_team_id) THEN
        INSERT INTO audit_log(table_name,record_id,action_type,action_details)
        VALUES ('matches',NEW.match_id,'UPDATE',
          CONCAT('Status: ',OLD.status,' -> ',NEW.status,
                 '; Score: ',OLD.team1_score,'-',OLD.team2_score,
                 ' -> ',NEW.team1_score,'-',NEW.team2_score));
    END IF;
END//

CREATE PROCEDURE sp_add_tournament_team(
    IN p_tournament_id INT,
    IN p_team_id INT,
    IN p_group_name VARCHAR(20)
)
BEGIN
    INSERT INTO tournament_teams(tournament_id,team_id,group_name)
    VALUES(p_tournament_id,p_team_id,p_group_name);
END//
DELIMITER ;

-- UNIT 3: TRANSACTION DEMONSTRATION (safe example; rolled back)
START TRANSACTION;
UPDATE tournament_teams
SET points = points + 3
WHERE tournament_id = 1 AND team_id = 1;
ROLLBACK;
-- The points remain unchanged because this example is rolled back.

-- UNIT 2: COMPLEX QUERIES, JOINS, CTEs, SUBQUERIES, WINDOW FUNCTIONS

-- 1. INNER JOIN: players with their teams
SELECT p.player_name,t.team_name,p.playing_role
FROM players p INNER JOIN teams t ON p.team_id=t.team_id;

-- 2. LEFT JOIN: all teams and their players, including teams without players
SELECT t.team_name,p.player_name
FROM teams t LEFT JOIN players p ON t.team_id=p.team_id
ORDER BY t.team_name,p.player_name;

-- 3. Subquery: players whose total runs are above the overall player average
SELECT player_name,total_runs
FROM vw_player_performance
WHERE total_runs > (SELECT AVG(total_runs) FROM vw_player_performance);

-- 4. CTE: total runs by player
WITH player_totals AS (
    SELECT p.player_id,p.player_name,SUM(s.runs_scored) AS runs
    FROM players p LEFT JOIN player_match_stats s ON p.player_id=s.player_id
    GROUP BY p.player_id,p.player_name
)
SELECT * FROM player_totals ORDER BY runs DESC;

-- 5. Window function: rank players by runs
SELECT player_name,total_runs,
       DENSE_RANK() OVER (ORDER BY total_runs DESC) AS run_rank
FROM vw_player_performance;

-- 6. Aggregate: tournament match count
SELECT tr.tournament_name,COUNT(m.match_id) AS total_matches
FROM tournaments tr LEFT JOIN matches m ON tr.tournament_id=m.tournament_id
GROUP BY tr.tournament_id,tr.tournament_name;

-- 7. Set operation equivalent using UNION
SELECT team_name AS participant,'TEAM' AS participant_type FROM teams
UNION
SELECT player_name,'PLAYER' FROM players;

-- 8. Index/query-plan demonstration
EXPLAIN SELECT * FROM matches
WHERE tournament_id=1 AND status='SCHEDULED';

-- 9. View-based reports
SELECT * FROM vw_player_performance ORDER BY total_runs DESC;
SELECT * FROM vw_tournament_standings ORDER BY tournament_id,points DESC;
SELECT * FROM vw_match_summary ORDER BY match_date;

-- 10. Stored procedure example
-- Example call (uncomment only after choosing a team not already registered):
-- CALL sp_add_tournament_team(2,5,'A');

-- 11. Trigger demonstration (updates a match and writes to audit_log)
UPDATE matches SET status='LIVE' WHERE match_id=3;
SELECT * FROM audit_log ORDER BY changed_at DESC;

-- 12. CRUD examples (commented to avoid changing demo data on initial run)
-- INSERT INTO teams(team_name,coach_name,home_city) VALUES ('Sample XI','Coach Name','Jaipur');
-- UPDATE teams SET coach_name='Updated Coach' WHERE team_id=1;
-- DELETE FROM teams WHERE team_name='Sample XI';

-- UNIT 4: NoSQL / real-world extension discussion
-- This project uses MySQL as its transactional source of truth.
-- A document database such as MongoDB could store flexible event logs or
-- ball-by-ball commentary documents. Do not execute MongoDB commands in MySQL Workbench.
