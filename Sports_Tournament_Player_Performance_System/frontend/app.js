const $ = s => document.querySelector(s);
let cache = {teams:[],tournaments:[]};
const api = async (url, options={}) => {
  const r = await fetch('/api'+url,{headers:{'Content-Type':'application/json'},...options});
  const data = await r.json();
  if(!r.ok) throw new Error(data.error || 'Request failed');
  return data;
};
function showPage(page){
  document.querySelectorAll('.page').forEach(x=>x.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(x=>x.classList.toggle('active',x.dataset.page===page));
  $('#'+page).classList.add('active');
  $('#page-title').textContent = ({overview:'Overview',tournaments:'Tournaments',teams:'Teams',players:'Players',matches:'Matches',performance:'Performance centre'})[page];
  if(page==='teams') loadTeams(); if(page==='players') loadPlayers();
  if(page==='tournaments') loadTournaments(); if(page==='matches') loadMatches();
  if(page==='performance') loadPerformance();
}
document.querySelectorAll('.nav-item').forEach(b=>b.addEventListener('click',()=>showPage(b.dataset.page)));
function toast(msg){const t=$('#toast');t.textContent=msg;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2600)}
function esc(v){return String(v??'—').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
async function loadOverview(){
  try{
    const d=await api('/dashboard'); $('#connection').textContent='Connected';
    $('#count-tournaments').textContent=d.counts.tournaments;$('#count-teams').textContent=d.counts.teams;
    $('#count-players').textContent=d.counts.players;$('#count-matches').textContent=d.counts.matches;
    $('#upcoming-count').textContent=`${d.counts.upcoming_matches} scheduled fixtures`;
    $('#recent-matches').innerHTML=d.recent.map(m=>`<div class="match-row"><div><strong>${esc(m.team1)} <span style="color:#a4ada7">vs</span> ${esc(m.team2)}</strong><small>${esc(m.tournament_name)} · ${new Date(m.match_date).toLocaleDateString()}</small></div><div class="match-result">${m.status==='COMPLETED'?`${m.team1_score} – ${m.team2_score}`:`<span class="status scheduled">${esc(m.status)}</span>`}</div></div>`).join('')||'<div class="empty">No matches yet.</div>';
    $('#leader-list').innerHTML=d.leaders.map((p,i)=>`<div class="leader-row"><div class="rank">${i+1}</div><div><b>${esc(p.player_name)}</b><small>${esc(p.team_name)}</small></div><div class="runs">${p.total_runs}<small> RUNS</small></div></div>`).join('')||'<div class="empty">No player stats recorded.</div>';
  }catch(e){$('#connection').textContent='Offline';$('#recent-matches').innerHTML='<div class="empty">Cannot reach database. Start backend and check .env.</div>';console.error(e)}
}
async function loadTeams(){try{const rows=await api('/teams');cache.teams=rows;$('#team-list').innerHTML=rows.map(t=>`<div class="team-card"><div class="card-top"><div class="team-symbol">◈</div><span class="mini-pill">${t.player_count} PLAYERS</span></div><h3>${esc(t.team_name)}</h3><p>${esc(t.home_city)} · Coach ${esc(t.coach_name)}</p></div>`).join('')}catch(e){toast(e.message)}}
async function loadPlayers(){try{const rows=await api('/players');cache.teams=cache.teams.length?cache.teams:await api('/teams');$('#player-rows').innerHTML=rows.map(p=>`<tr><td>${esc(p.player_name)}</td><td>${esc(p.team_name)}</td><td>${esc(p.playing_role.replaceAll('_',' '))}</td><td>${esc(p.jersey_number)}</td><td>${esc(p.nationality)}</td></tr>`).join('')}catch(e){toast(e.message)}}
async function loadTournaments(){try{const rows=await api('/tournaments');$('#tournament-list').innerHTML=rows.map(t=>`<div class="tournament-card"><div class="card-top"><div class="team-symbol">🏆</div><span class="status ${t.status==='UPCOMING'?'scheduled':''}">${esc(t.status)}</span></div><h3>${esc(t.tournament_name)}</h3><p>${esc(t.sport_name)} · ${esc(t.format_name)}</p><p>${new Date(t.start_date).toLocaleDateString()} – ${new Date(t.end_date).toLocaleDateString()}</p></div>`).join('')}catch(e){toast(e.message)}}
async function loadMatches(){try{const rows=await api('/matches');$('#match-rows').innerHTML=rows.map(m=>`<tr><td>${esc(m.tournament_name)}</td><td>${esc(m.team1)} vs ${esc(m.team2)}</td><td>${new Date(m.match_date).toLocaleString()}</td><td>${esc(m.venue_name)}</td><td><span class="status ${m.status==='SCHEDULED'?'scheduled':''}">${esc(m.status)}</span></td><td>${esc(m.result_summary||'—')}</td></tr>`).join('')}catch(e){toast(e.message)}}
async function loadPerformance(){try{const rows=await api('/performance');$('#performance-rows').innerHTML=rows.map((p,i)=>`<tr><td>#${i+1}</td><td>${esc(p.player_name)}</td><td>${esc(p.team_name)}</td><td>${p.matches_played}</td><td>${p.total_runs}</td><td>${p.total_wickets}</td><td>${p.total_catches}</td></tr>`).join('')}catch(e){toast(e.message)}}
function field(label,name,type='text',required=true,options=null,full=false){
  let control=options?`<select name="${name}" ${required?'required':''}>${options.map(o=>`<option value="${o.value}">${o.label}</option>`).join('')}</select>`:`<input name="${name}" type="${type}" ${required?'required':''}>`;
  return `<div class="field ${full?'full':''}"><label>${label}</label>${control}</div>`;
}
function openModal(kind){
  const forms={
    team:{title:'Add a team',fields:field('TEAM NAME','team_name')+field('COACH NAME','coach_name','text',false)+field('HOME CITY','home_city','text',false)+field('FOUNDED YEAR','founded_year','number',false),url:'/teams'},
    player:{title:'Add a player',fields:field('PLAYER NAME','player_name')+field('TEAM','team_id','text',true,cache.teams.map(t=>({value:t.team_id,label:t.team_name})))+field('PLAYING ROLE','playing_role','text',true,['BATTER','BOWLER','ALL_ROUNDER','WICKET_KEEPER'].map(x=>({value:x,label:x.replaceAll('_',' ')})))+field('JERSEY NUMBER','jersey_number','number',false)+field('NATIONALITY','nationality','text',false),url:'/players'},
    tournament:{title:'Create tournament',fields:field('TOURNAMENT NAME','tournament_name','text',true,null,true)+field('SPORT','sport_name','text',true)+field('FORMAT','format_name','text',true,['LEAGUE','KNOCKOUT','GROUP_AND_KNOCKOUT'].map(x=>({value:x,label:x.replaceAll('_',' ')})))+field('START DATE','start_date','date')+field('END DATE','end_date','date')+field('STATUS','status','text',true,['UPCOMING','ONGOING','COMPLETED'].map(x=>({value:x,label:x}))),url:'/tournaments'},
    match:{title:'Schedule a match',fields:field('TOURNAMENT ID','tournament_id','number')+field('VENUE ID (OPTIONAL)','venue_id','number',false)+field('TEAM 1 ID','team1_id','number')+field('TEAM 2 ID','team2_id','number')+field('MATCH DATE & TIME','match_date','datetime-local',true,null,true),url:'/matches'}
  };
  const f=forms[kind];$('#modal-title').textContent=f.title;$('#modal-fields').innerHTML=f.fields;$('#form-error').textContent='';
  $('#modal').classList.add('show');$('#modal-form').dataset.url=f.url;
}
function closeModal(){$('#modal').classList.remove('show')}
$('#modal-form').addEventListener('submit',async e=>{
  e.preventDefault();const body=Object.fromEntries(new FormData(e.target).entries());
  Object.keys(body).forEach(k=>{if(body[k]==='')body[k]=null});
  try{await api(e.target.dataset.url,{method:'POST',body:JSON.stringify(body)});closeModal();toast('Record saved successfully');loadOverview();if(e.target.dataset.url==='/teams')loadTeams();if(e.target.dataset.url==='/players')loadPlayers();if(e.target.dataset.url==='/tournaments')loadTournaments();if(e.target.dataset.url==='/matches')loadMatches()}
  catch(err){$('#form-error').textContent=err.message}
});
$('#modal').addEventListener('click',e=>{if(e.target.id==='modal')closeModal()});
loadOverview();
