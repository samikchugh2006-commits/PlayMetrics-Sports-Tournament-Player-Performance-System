require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'frontend')));

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'sports_tournament_db',
  waitForConnections: true, connectionLimit: 10, queueLimit: 0
});

const asyncRoute = fn => (req,res,next) => Promise.resolve(fn(req,res,next)).catch(next);

app.get('/api/dashboard', asyncRoute(async (req,res) => {
  const [[counts]] = await pool.query(`
    SELECT
      (SELECT COUNT(*) FROM tournaments) tournaments,
      (SELECT COUNT(*) FROM teams) teams,
      (SELECT COUNT(*) FROM players) players,
      (SELECT COUNT(*) FROM matches) matches,
      (SELECT COUNT(*) FROM matches WHERE status='SCHEDULED') upcoming_matches
  `);
  const [leaders] = await pool.query(
    'SELECT player_name,team_name,total_runs,total_wickets FROM vw_player_performance ORDER BY total_runs DESC LIMIT 5'
  );
  const [recent] = await pool.query('SELECT * FROM vw_match_summary ORDER BY match_date DESC LIMIT 6');
  res.json({counts,leaders,recent});
}));

app.get('/api/teams', asyncRoute(async (req,res) => {
  const [rows] = await pool.query(`SELECT t.*, COUNT(p.player_id) player_count
    FROM teams t LEFT JOIN players p ON p.team_id=t.team_id
    GROUP BY t.team_id ORDER BY t.team_name`);
  res.json(rows);
}));
app.post('/api/teams', asyncRoute(async (req,res) => {
  const {team_name,coach_name,home_city,founded_year} = req.body;
  if (!team_name) return res.status(400).json({error:'Team name is required'});
  const [r] = await pool.execute(
    'INSERT INTO teams(team_name,coach_name,home_city,founded_year) VALUES(?,?,?,?)',
    [team_name,coach_name || null,home_city || null,founded_year || null]);
  res.status(201).json({team_id:r.insertId,message:'Team created'});
}));

app.get('/api/players', asyncRoute(async (req,res) => {
  const [rows] = await pool.query(`SELECT p.*,t.team_name FROM players p
    JOIN teams t ON p.team_id=t.team_id ORDER BY p.player_name`);
  res.json(rows);
}));
app.post('/api/players', asyncRoute(async (req,res) => {
  const {team_id,player_name,playing_role,jersey_number,nationality} = req.body;
  if (!team_id || !player_name || !playing_role)
    return res.status(400).json({error:'team_id, player_name and playing_role are required'});
  const [r] = await pool.execute(
    `INSERT INTO players(team_id,player_name,playing_role,jersey_number,nationality)
     VALUES(?,?,?,?,?)`,
    [team_id,player_name,playing_role,jersey_number || null,nationality || null]);
  res.status(201).json({player_id:r.insertId,message:'Player created'});
}));

app.get('/api/tournaments', asyncRoute(async (req,res) => {
  const [rows] = await pool.query('SELECT * FROM tournaments ORDER BY start_date DESC');
  res.json(rows);
}));
app.post('/api/tournaments', asyncRoute(async (req,res) => {
  const {tournament_name,sport_name,format_name,start_date,end_date,status} = req.body;
  if (!tournament_name || !start_date || !end_date)
    return res.status(400).json({error:'Tournament name, start date and end date are required'});
  const [r] = await pool.execute(
    `INSERT INTO tournaments(tournament_name,sport_name,format_name,start_date,end_date,status)
     VALUES(?,?,?,?,?,?)`,
    [tournament_name,sport_name || 'Cricket',format_name || 'LEAGUE',start_date,end_date,status || 'UPCOMING']);
  res.status(201).json({tournament_id:r.insertId,message:'Tournament created'});
}));

app.get('/api/matches', asyncRoute(async (req,res) => {
  const [rows] = await pool.query('SELECT * FROM vw_match_summary ORDER BY match_date');
  res.json(rows);
}));
app.post('/api/matches', asyncRoute(async (req,res) => {
  const {tournament_id,venue_id,team1_id,team2_id,match_date} = req.body;
  if (!tournament_id || !team1_id || !team2_id || !match_date)
    return res.status(400).json({error:'Tournament, both teams and match date are required'});
  if (Number(team1_id) === Number(team2_id))
    return res.status(400).json({error:'A team cannot play against itself'});
  const [r] = await pool.execute(
    `INSERT INTO matches(tournament_id,venue_id,team1_id,team2_id,match_date)
     VALUES(?,?,?,?,?)`,
    [tournament_id,venue_id || null,team1_id,team2_id,match_date]);
  res.status(201).json({match_id:r.insertId,message:'Match scheduled'});
}));

app.post('/api/stats', asyncRoute(async (req,res) => {
  const {match_id,player_id,runs_scored=0,balls_faced=0,wickets_taken=0,overs_bowled=0,catches_taken=0,minutes_played=0} = req.body;
  if (!match_id || !player_id) return res.status(400).json({error:'match_id and player_id are required'});
  const [r] = await pool.execute(
    `INSERT INTO player_match_stats(match_id,player_id,runs_scored,balls_faced,wickets_taken,overs_bowled,catches_taken,minutes_played)
     VALUES(?,?,?,?,?,?,?,?)
     ON DUPLICATE KEY UPDATE runs_scored=VALUES(runs_scored),balls_faced=VALUES(balls_faced),
       wickets_taken=VALUES(wickets_taken),overs_bowled=VALUES(overs_bowled),
       catches_taken=VALUES(catches_taken),minutes_played=VALUES(minutes_played)`,
    [match_id,player_id,runs_scored,balls_faced,wickets_taken,overs_bowled,catches_taken,minutes_played]);
  res.status(201).json({message:'Player statistics saved'});
}));
app.get('/api/standings/:tournamentId', asyncRoute(async (req,res) => {
  const [rows] = await pool.execute(
    'SELECT * FROM vw_tournament_standings WHERE tournament_id=? ORDER BY points DESC,wins DESC',
    [req.params.tournamentId]);
  res.json(rows);
}));
app.get('/api/performance', asyncRoute(async (req,res) => {
  const [rows] = await pool.query('SELECT * FROM vw_player_performance ORDER BY total_runs DESC');
  res.json(rows);
}));

app.use((err,req,res,next) => {
  console.error(err);
  res.status(500).json({error:'Server/database error',detail:err.code || err.message});
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Sports management app running at http://localhost:${port}`));
