// Reproduz a corrida de refresh: N requisições simultâneas com o mesmo token.
// Esperado após a correção: no máximo um 200 por rodada. Uso: node refresh_race.mjs
const API='http://localhost:3100/api';
const post=(p,b)=>fetch(API+p,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(b)});
const n=Date.now().toString(36);
const r=await (await post('/auth/register',{username:'race_'+n,name:'r',email:`race_${n}@example.test`,password:'senha-fixture-123'})).json();
let double=0;
let token=r.refreshToken;
for(let i=0;i<25;i++){
  const res=await Promise.all(Array.from({length:8},()=>post('/auth/refresh',{refreshToken:token})));
  const ok=[];
  for(const x of res) if(x.status===200) ok.push(await x.json());
  if(ok.length>1) double++;
  if(ok.length===0) break;
  token=ok[0].refreshToken;
}
console.log('rodadas com mais de um 200 para o mesmo token:',double,'de 25');
