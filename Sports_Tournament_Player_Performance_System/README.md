# Sports Tournament & Player Performance Management System

A DBMS capstone project built with **MySQL 8**, **Node.js/Express**, and a responsive HTML/CSS/JavaScript dashboard.

## Features
- Dashboard overview: tournaments, teams, players, matches and performance leaders
- Manage teams and players
- Create tournaments and fixtures
- Record match results and individual player statistics
- SQL views for standings and player performance
- Stored procedure, triggers, audit log, indexes, transactions, CTE and window-function examples
- REST API backed by MySQL

## Requirements
- MySQL Server 8.0+
- MySQL Workbench
- Node.js 18+
- npm

## 1. Create the database
1. Open MySQL Workbench and connect to your local MySQL server.
2. Open `database/sports_tournament_db.sql`.
3. Execute the complete script (lightning icon).
4. The script creates and selects the database `sports_tournament_db`, creates tables, inserts demo data, and creates views, indexes, triggers and a stored procedure.

Optional verification:
```sql
USE sports_tournament_db;
SHOW TABLES;
SELECT * FROM vw_player_performance;
SELECT * FROM vw_tournament_standings;
```

## 2. Configure and start the backend
Open a terminal in the project folder:
```bash
cd backend
npm install
```
Copy `.env.example` to `.env` and enter your MySQL credentials:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=sports_tournament_db
PORT=3000
```
Start:
```bash
npm start
```
Open `http://localhost:3000`.

## 3. Useful API endpoints
- `GET /api/dashboard` - dashboard counts and leaders
- `GET /api/teams`, `POST /api/teams`
- `GET /api/players`, `POST /api/players`
- `GET /api/tournaments`, `POST /api/tournaments`
- `GET /api/matches`, `POST /api/matches`
- `POST /api/stats` - add player match statistics
- `GET /api/standings/:tournamentId`
- `GET /api/performance`

## Project structure
```text
Sports_Tournament_Player_Performance_System/
├── database/
│   └── sports_tournament_db.sql
├── backend/
│   ├── server.js
│   ├── package.json
│   └── .env.example
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── README.md
```

## Notes for your capstone viva
- The relational design uses separate entities for teams, players, tournaments, venues, matches and player statistics to reduce duplication.
- `player_match_stats` resolves the many-to-many relationship between players and matches.
- Foreign keys enforce referential integrity.
- Views simplify reporting; indexes support frequently filtered columns.
- The audit trigger records changes to match results.
- The stored procedure demonstrates reusable database logic.
- The transaction example shows atomic updates.
- CTE and window-function examples demonstrate advanced SQL.

This is a learning/demo system. Add authentication, authorization, input validation, backups and deployment hardening before production use.
