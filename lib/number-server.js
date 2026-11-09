'use strict';
const crypto=require('node:crypto');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function config(){const base=(process.env.SUPABASE_URL||'').replace(/\/+$/,''),service=process.env.SUPABASE_SERVICE_ROLE_KEY||'',anon=process.env.SUPABASE_ANON_KEY||'',bot=process.env.TELEGRAM_BOT_TOKEN||'',secret=process.env.PEAR_CODE_SECRET||'',webhook=process.env.TELEGRAM_WEBHOOK_SECRET||'';if(!/^https:\/\/[a-z0-9.-]+$/i.test(base)||!service||!anon||!bot||secret.length<32||webhook.length<32)throw Error('configuration_missing');return {base,service,anon,bot,secret,webhook}}
async function jsonRequest(url,opts){const res=await fetch(url,{...opts,redirect:'manual',signal:AbortSignal.timeout(10000)});let body=null;try{body=await res.json()}catch(_){}return {ok:res.ok,status:res.status,body}}
function admin(c){return {apikey:c.service,authorization:'Bearer '+c.service,'content-type':'application/json'}}
async function rpc(c,name,args){const r=await jsonRequest(c.base+'/rest/v1/rpc/'+name,{method:'POST',headers:admin(c),body:JSON.stringify(args)});if(!r.ok)throw Error('database_failed');return r.body}
async function botRequest(c,method,body){const r=await jsonRequest('https://api.telegram.org/bot'+c.bot+'/'+method,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});if(!r.ok||!r.body?.ok)throw Error('telegram_failed');return r.body.result}
async function user(c,authorization){if(!/^Bearer [A-Za-z0-9_.-]+$/.test(authorization||''))return null;const r=await jsonRequest(c.base+'/auth/v1/user',{headers:{apikey:c.anon,authorization}});return r.ok&&uuid.test(r.body?.id||'')?r.body:null}
function codeHash(c,id,code){return crypto.createHmac('sha256',c.secret).update(id+':'+code).digest('hex')}
function secureEqual(a,b){const x=Buffer.from(a||''),y=Buffer.from(b||'');return x.length===y.length&&crypto.timingSafeEqual(x,y)}
function readBody(req){if(!req.body||typeof req.body!=='object'||Array.isArray(req.body))throw Error('invalid_body');return req.body}
module.exports={config,jsonRequest,admin,rpc,botRequest,user,codeHash,secureEqual,uuid,readBody,crypto};
