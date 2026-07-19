#!/usr/bin/env node
// Funde settings.fragment.json (deste template) no ~/.claude/settings.json da maquina atual.
// Roda em qualquer OS (Node puro, sem deps). Nunca sobrescreve o arquivo inteiro -- so as chaves
// do fragment, preservando tudo que ja existe (env com secrets, permissions.allow locais, etc).

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const fragmentPath = path.join(here, 'settings.fragment.json');
const targetPath = path.join(os.homedir(), '.claude', 'settings.json');

const fragment = JSON.parse(fs.readFileSync(fragmentPath, 'utf8'));
const target = fs.existsSync(targetPath) ? JSON.parse(fs.readFileSync(targetPath, 'utf8')) : {};

function mergeObject(targetObj, fragObj, label) {
  targetObj[label] = targetObj[label] || {};
  for (const [k, v] of Object.entries(fragObj)) {
    targetObj[label][k] = v;
  }
}

function mergeHookList(existing, incoming) {
  const list = Array.isArray(existing) ? [...existing] : [];
  for (const entry of incoming) {
    const dup = list.some(e => e.matcher === entry.matcher
      && JSON.stringify(e.hooks) === JSON.stringify(entry.hooks));
    if (!dup) list.push(entry);
  }
  return list;
}

// enabledPlugins / extraKnownMarketplaces: merge raso (chave a chave)
if (fragment.enabledPlugins) mergeObject(target, fragment.enabledPlugins, 'enabledPlugins');
if (fragment.extraKnownMarketplaces) mergeObject(target, fragment.extraKnownMarketplaces, 'extraKnownMarketplaces');

// hooks: merge por evento, dedup por matcher+conteudo
if (fragment.hooks) {
  target.hooks = target.hooks || {};
  for (const [event, list] of Object.entries(fragment.hooks)) {
    target.hooks[event] = mergeHookList(target.hooks[event], list);
  }
}

// escalares simples: sobrescreve (o objetivo do template e igualar isso entre maquinas)
const scalarKeys = ['model', 'language', 'effortLevel', 'autoUpdatesChannel', 'tui',
  'skipWorkflowUsageWarning', 'autoCompactEnabled', 'agentPushNotifEnabled', 'skipAutoPermissionPrompt'];
const changed = [];
for (const key of scalarKeys) {
  if (key in fragment && fragment[key] !== target[key]) {
    changed.push(`${key}: ${JSON.stringify(target[key])} -> ${JSON.stringify(fragment[key])}`);
    target[key] = fragment[key];
  }
}

fs.mkdirSync(path.dirname(targetPath), { recursive: true });
fs.writeFileSync(targetPath, JSON.stringify(target, null, 2) + '\n');

console.log('Settings mesclado em:', targetPath);
console.log('enabledPlugins:', Object.keys(fragment.enabledPlugins || {}).length, 'entradas');
console.log('extraKnownMarketplaces:', Object.keys(fragment.extraKnownMarketplaces || {}).length, 'entradas');
if (changed.length) {
  console.log('Preferencias alteradas:');
  changed.forEach(c => console.log(' ', c));
}
console.log('\nNAO mexi em: env (secrets ficam so na maquina), permissions.allow (evita misturar path Windows/Linux).');
