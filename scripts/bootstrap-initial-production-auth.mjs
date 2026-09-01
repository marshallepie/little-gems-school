#!/usr/bin/env node
/**
 * One-time production Auth creation for the approved initial administrators.
 * Passwords are read from an attached TTY only and are never written or logged.
 */
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'node:url';

const ACCOUNTS = [
  'AdrianAnyata@marshallepie.com',
  'R.Oses@marshallepie.com',
  'G.I.Ucheya@marshallepie.com',
];

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be supplied only in this operator shell.`);
  return value;
}

async function readHidden(prompt) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('A local interactive TTY is required; do not pipe or pass passwords as arguments/environment.');
  }
  process.stdout.write(prompt);
  const stdin = process.stdin;
  stdin.setRawMode(true);
  stdin.resume();
  stdin.setEncoding('utf8');
  let value = '';
  return new Promise((resolve, reject) => {
    const done = () => {
      stdin.off('data', onData);
      stdin.setRawMode(false);
      stdin.pause();
      process.stdout.write('\n');
    };
    const onData = (chunk) => {
      for (const char of chunk) {
        if (char === '\r' || char === '\n') {
          done();
          resolve(value);
        } else if (char === '\u0003') {
          done();
          reject(new Error('Cancelled by operator.'));
        } else if (char === '\u007f' || char === '\b') {
          value = value.slice(0, -1);
        } else if (char >= ' ') {
          value += char;
        }
      }
    };
    stdin.on('data', onData);
  });
}

function isStrongTemporaryPassword(password) {
  return password.length >= 20
    && /[a-z]/.test(password)
    && /[A-Z]/.test(password)
    && /[0-9]/.test(password)
    && /[^A-Za-z0-9]/.test(password);
}

export async function assertZeroAuthUsers(admin, when) {
  // `total` plus a one-item page makes a zero-user result unambiguous and
  // rejects API/proxy responses that omit pagination metadata.
  const { data: listed, error: listError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1 });
  if (listError) throw new Error(`Could not inspect Auth users ${when}: ${listError.message}`);
  if (!listed
    || !Array.isArray(listed.users)
    || !Number.isSafeInteger(listed.total)
    || listed.total < 0
    || !Number.isSafeInteger(listed.lastPage)
    || listed.lastPage !== 0
    || listed.nextPage !== null) {
    throw new Error(`Refusing to run: Auth user listing is uncertain ${when}. Stop and follow the runbook failure gate.`);
  }
  if (listed.users.length !== 0 || listed.total !== 0) {
    throw new Error(`Refusing to run: the target project is not a zero-user production Auth state ${when}. Stop and follow the runbook failure gate.`);
  }
}

export async function main() {
  const url = requireEnv('SUPABASE_URL');
  const key = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  if (process.env.LGS_INITIAL_BOOTSTRAP_CONFIRM !== 'CREATE-EXACTLY-THREE') {
    throw new Error('Set LGS_INITIAL_BOOTSTRAP_CONFIRM=CREATE-EXACTLY-THREE after completing the runbook preflight.');
  }
  const admin = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
  await assertZeroAuthUsers(admin, 'during initial preflight');

  const passwords = new Map();
  for (const email of ACCOUNTS) {
    let password;
    do {
      password = await readHidden(`Temporary password for ${email}: `);
      if (!isStrongTemporaryPassword(password)) {
        console.error('Use at least 20 characters including upper, lower, number, and symbol. Nothing was created.');
      }
    } while (!isStrongTemporaryPassword(password));
    const confirmation = await readHidden(`Re-enter temporary password for ${email}: `);
    if (password !== confirmation) throw new Error(`Password confirmation did not match for ${email}. Nothing was created.`);
    passwords.set(email, password);
  }

  // This is intentionally the last operation before the first createUser call:
  // prompts can take time, so the initial preflight alone is not sufficient.
  await assertZeroAuthUsers(admin, 'immediately before Auth creation');

  for (const email of ACCOUNTS) {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password: passwords.get(email),
      email_confirm: true,
    });
    passwords.set(email, '');
    if (error) throw new Error(`Auth creation stopped for ${email}: ${error.message}. Do not retry blindly; use the runbook forward-only failure gate.`);
    console.log(`Created confirmed Auth identity: ${data.user.id} ${data.user.email}`);
  }
  console.log('All three Auth identities were created without sending email. Continue immediately with the database-operator verification/mapping transaction in the runbook.');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
