import { readFileSync } from 'node:fs';

const logPath = 'firestore-debug.log';
const log = readFileSync(logPath, 'utf8');

const forbiddenDiagnostics = [
  ['limite de 1.000 expressões', /maximum of 1000 expressions/i],
  ['avaliação interrompida', /unable to evaluate the expression/i],
  ['erro de valor nulo', /null value error/i],
  [
    'excesso de leituras das regras',
    /(?:too many|maximum|exceeded).{0,80}(?:document access|access call|calls? to (?:get|exists|getAfter))/i,
  ],
  [
    'falha interna do Emulator',
    /(?:StatusRuntimeException|status|code)\s*[:=]\s*INTERNAL\b|\bINTERNAL:\s*(?!Commit)/i,
  ],
];

const failures = forbiddenDiagnostics
  .filter(([, pattern]) => pattern.test(log))
  .map(([label]) => label);

if (failures.length > 0) {
  throw new Error(`Diagnósticos proibidos no ${logPath}: ${failures.join(', ')}.`);
}

console.log(
  `Auditoria de ${logPath}: sem limite de expressões, excesso de leituras, ` +
    'avaliação interrompida, erro nulo ou falha interna.',
);
