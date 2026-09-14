require('dotenv').config();
const express = require('express');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const bcrypt = require('bcryptjs');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Restrições do sorteio: o Gus só pode tirar, e só pode ser tirado por,
// alguém deste grupo. O resto se sorteia livremente.
const GUS = 'Gus Amato';
const GRUPO_GUS = [
  'Rafael Fernandez',
  'Arthur Correa',
  'Kkao',
  'Mau',
  'Lucca Guidoni',
  'Lucca Claro',
  'Carmona',
  'Victor Klock',
  'Mett Corrrea',
  'Igor André',
];

function allowed(giver, receiver, anterior) {
  if (giver === receiver) return false;
  // Refazer o sorteio tem que dar gente nova pra todo mundo.
  if (anterior && anterior[giver] === receiver) return false;
  if (receiver === GUS) return GRUPO_GUS.includes(giver);
  if (giver === GUS) return GRUPO_GUS.includes(receiver);
  return true;
}

// Monta um ciclo unico: A -> B -> C -> ... -> A, uma corrente so passando por
// todo mundo. Assim ninguem tira a si mesmo e ninguem tira quem tirou ela —
// isso exigiria um ciclo de 2, que nao existe numa corrente de 18. Tambem nao
// se formam panelinhas fechadas de 3 ou 4.
function cyclicMapping(names) {
  const ordem = shuffle(names);
  const mapping = {};
  ordem.forEach((n, i) => { mapping[n] = ordem[(i + 1) % ordem.length]; });
  return mapping;
}

// Sorteia por rejeicao: gera correntes ate cair uma que respeite allowed().
// Com a restricao do Gus mais a de nao repetir o sorteio anterior, cada
// tentativa passa ~11% das vezes — 5000 tentativas tornam a falha impossivel
// na pratica. Se as restricoes ficarem impossiveis um dia, devolve null em vez
// de gravar um sorteio invalido no banco.
function generateDraw(names, anterior) {
  for (let attempt = 0; attempt < 5000; attempt++) {
    const mapping = cyclicMapping(names);
    if (names.every((giver) => allowed(giver, mapping[giver], anterior))) {
      return mapping;
    }
  }
  return null;
}

// Public: list of names + whether each has already revealed (no PINs, no receivers).
app.get('/api/participants', async (req, res) => {
  const { data, error } = await supabase
    .from('participants')
    .select('name, revealed')
    .order('name');

  if (error) return res.status(500).json({ error: 'server_error' });
  res.json(data);
});

// Public: aggregate progress counter.
app.get('/api/progress', async (req, res) => {
  const { data, error } = await supabase.from('participants').select('revealed');
  if (error) return res.status(500).json({ error: 'server_error' });

  const total = data.length;
  const revealed = data.filter((p) => p.revealed).length;
  res.json({ total, revealed, remaining: total - revealed });
});

// Reveal a participant's match — validates PIN server-side, marks as revealed,
// and never sends the mapping to the client until the PIN is confirmed.
app.post('/api/reveal', async (req, res) => {
  const { name, pin } = req.body || {};
  if (!name || !pin) return res.status(400).json({ error: 'missing_fields' });

  const { data: participant, error } = await supabase
    .from('participants')
    .select('*')
    .eq('name', name)
    .single();

  if (error || !participant) return res.status(404).json({ error: 'not_found' });
  if (participant.revealed) return res.status(409).json({ error: 'already_revealed' });

  const pinMatches = await bcrypt.compare(String(pin), participant.pin_hash);
  if (!pinMatches) return res.status(401).json({ error: 'invalid_pin' });

  // Guarded update: only succeeds if still not revealed (protects against
  // two near-simultaneous requests both passing the check above).
  const { data: updated, error: updateError } = await supabase
    .from('participants')
    .update({ revealed: true, revealed_at: new Date().toISOString() })
    .eq('name', name)
    .eq('revealed', false)
    .select();

  if (updateError) return res.status(500).json({ error: 'server_error' });
  if (!updated || updated.length === 0) {
    return res.status(409).json({ error: 'already_revealed' });
  }

  res.json({ receiver: participant.receiver });
});

// Admin only: (re)generates the draw and clears all reveal flags.
// Call this once after seeding participants, and again only if you
// deliberately want to redo the whole draw.
app.post('/api/admin/draw', async (req, res) => {
  const secret = req.headers['x-admin-secret'];
  if (!secret || secret !== process.env.ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const { data, error } = await supabase.from('participants').select('name, receiver');
  if (error) return res.status(500).json({ error: 'server_error' });

  const names = data.map((p) => p.name);

  // Sorteio atual, para nao repetir. No primeiro sorteio fica vazio.
  const anterior = {};
  data.forEach((p) => { if (p.receiver) anterior[p.name] = p.receiver; });

  // Os nomes das restricoes precisam existir de verdade no banco. Sem isso, um
  // typo em GRUPO_GUS passaria batido e o sorteio sairia sem a restricao.
  const desconhecidos = [GUS, ...GRUPO_GUS].filter((n) => !names.includes(n));
  if (desconhecidos.length > 0) {
    return res.status(500).json({ error: 'unknown_names', names: desconhecidos });
  }

  const mapping = generateDraw(names, anterior);
  if (!mapping) return res.status(500).json({ error: 'no_valid_draw' });

  for (const giver of names) {
    const { error: updateError } = await supabase
      .from('participants')
      .update({ receiver: mapping[giver], revealed: false, revealed_at: null })
      .eq('name', giver);
    if (updateError) return res.status(500).json({ error: 'server_error' });
  }

  res.json({ ok: true, count: names.length });
});

// Diz qual commit esta rodando. Serve para confirmar que um deploy subiu
// antes de mexer no sorteio. Nao exige segredo: e so um SHA.
app.get('/api/version', (req, res) => {
  res.json({ commit: (process.env.RENDER_GIT_COMMIT || 'local').slice(0, 7) });
});

// Admin only: quem tirou quem. Nunca exposto sem o ADMIN_SECRET.
app.get('/api/admin/results', async (req, res) => {
  const secret = req.headers['x-admin-secret'];
  if (!secret || secret !== process.env.ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const { data, error } = await supabase
    .from('participants')
    .select('name, receiver, revealed, revealed_at')
    .order('name');

  if (error) return res.status(500).json({ error: 'server_error' });
  res.json(data);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('Presentinho do Textor rodando na porta ' + PORT));
