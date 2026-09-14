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

// Derangement: nobody is matched to themselves.
function generateDerangement(names) {
  let receivers;
  let attempts = 0;
  do {
    receivers = shuffle(names);
    attempts++;
  } while (receivers.some((r, i) => r === names[i]) && attempts < 500);

  const mapping = {};
  names.forEach((giver, i) => { mapping[giver] = receivers[i]; });
  return mapping;
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

  const { data, error } = await supabase.from('participants').select('name');
  if (error) return res.status(500).json({ error: 'server_error' });

  const names = data.map((p) => p.name);
  const mapping = generateDerangement(names);

  for (const giver of names) {
    const { error: updateError } = await supabase
      .from('participants')
      .update({ receiver: mapping[giver], revealed: false, revealed_at: null })
      .eq('name', giver);
    if (updateError) return res.status(500).json({ error: 'server_error' });
  }

  res.json({ ok: true, count: names.length });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('Presentinho do Textor rodando na porta ' + PORT));
