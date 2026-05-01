const { spawn }    = require('child_process');
const { bareosDb } = require('../db/connection');
const logger       = require('../utils/logger');

function execBconsole(command, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const proc = spawn('bconsole', []);
    let out = ''; let err = '';
    proc.stdout.on('data', d => { out += d; });
    proc.stderr.on('data', d => { err += d; });
    setTimeout(() => { proc.kill(); reject(new Error(`timeout: ${command}`)); }, timeoutMs);
    proc.on('close', code => {
      if (code !== 0 && !out) reject(new Error(`bconsole exit ${code}: ${err}`));
      else resolve(out);
    });
    proc.stdin.write(command + '\nquit\n');
    proc.stdin.end();
  });
}

async function getVolumi(poolName) {
  const q = bareosDb('media as m').leftJoin('pool as p', 'm.poolid', 'p.poolid')
    .select('m.volumename as label', 'm.volstatus as stato', 'm.volbytes as bytes', 'm.lastwritten as ultima_scrittura', 'p.name as pool');
  if (poolName) q.where('p.name', poolName);
  return q.orderBy('m.lastwritten', 'desc');
}

async function getVolume(label) {
  return bareosDb('media as m').leftJoin('pool as p', 'm.poolid', 'p.poolid')
    .select('m.volumename as label', 'm.volstatus as stato', 'm.volbytes as bytes', 'm.lastwritten', 'p.name as pool')
    .where('m.volumename', label).first();
}

async function getJobsPerClient(clientName, limit = 10) {
  return bareosDb('job as j').leftJoin('client as c', 'j.clientid', 'c.clientid')
    .select('j.jobid', 'j.name', 'j.jobstatus', 'j.starttime', 'j.endtime', 'j.jobbytes', 'j.jobfiles')
    .where('c.name', clientName).orderBy('j.starttime', 'desc').limit(limit);
}

async function getPools() { return bareosDb('pool').select('poolid', 'name', 'numvols', 'maxvols'); }
async function getStorageDaemons() { return bareosDb('storage').select('storageid', 'name', 'address', 'sdport', 'enabled'); }

async function labelVolume({ label, pool, storage }) { return execBconsole(`label volume="${label}" pool="${pool}" storage="${storage}"`); }
async function updateVolumeStatus({ label, stato })  { return execBconsole(`update volume="${label}" volstatus="${stato}"`); }
async function statusStorage(name)  { return execBconsole(`status storage="${name}"`); }
async function statusClient(name)   { return execBconsole(`status client="${name}"`); }
async function statusDirector()     { return execBconsole('status director'); }

module.exports = { getVolumi, getVolume, getJobsPerClient, getPools, getStorageDaemons, labelVolume, updateVolumeStatus, statusStorage, statusClient, statusDirector };
