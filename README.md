# Presentinho do Textor

Backend real (Supabase + Render) para o amigo secreto de ano novo. O PIN de cada
pessoa é validado no servidor, o mapa do sorteio nunca é enviado ao navegador
antes da validação, e cada nome só pode ser revelado uma vez — tudo isso
garantido pelo banco de dados, não só pela aparência da página.

## 1. Criar o projeto no Supabase

1. Crie uma conta em https://supabase.com (plano gratuito é suficiente).
2. Crie um novo projeto.
3. Abra **SQL Editor** → **New query**, cole todo o conteúdo do arquivo
   `supabase.sql` e rode.
   - Isso cria a tabela `participants` já com os 18 nomes e os PINs
     criptografados (bcrypt) — o PIN em texto puro não fica salvo em lugar
     nenhum do banco.
4. Vá em **Project Settings → API** e anote dois valores:
   - **Project URL** → vai virar `SUPABASE_URL`
   - **service_role key** (não a `anon key`) → vai virar `SUPABASE_SERVICE_KEY`

A `service_role key` tem acesso total ao banco — ela só deve existir no
servidor (Render), nunca no navegador.

## 2. Subir este projeto pro GitHub

1. Crie um repositório novo (pode ser privado).
2. Suba esta pasta inteira (`server.js`, `package.json`, `public/`, etc.).
   Não é necessário subir o `.env` — ele é só um modelo local.

## 3. Criar o serviço no Render

1. Em https://render.com, clique em **New → Web Service**.
2. Conecte o repositório do GitHub que você acabou de criar.
3. Configure:
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
4. Em **Environment**, adicione as variáveis:
   - `SUPABASE_URL` → a Project URL do passo 1
   - `SUPABASE_SERVICE_KEY` → a service_role key do passo 1
   - `ADMIN_SECRET` → invente uma senha forte, só sua (não compartilhe com o grupo)
5. Clique em **Create Web Service** e aguarde o deploy.

Ao final, o Render te dá uma URL pública, algo como:
`https://presentinho-do-textor.onrender.com`

## 4. Gerar o sorteio (uma única vez)

Antes de compartilhar o link com o grupo, você precisa gerar o sorteio.
Rode este comando (troque a URL e o `ADMIN_SECRET` pelos seus):

```bash
curl -X POST https://presentinho-do-textor.onrender.com/api/admin/draw \
  -H "x-admin-secret: SEU_ADMIN_SECRET"
```

Resposta esperada: `{"ok":true,"count":18}`

Isso sorteia os pares e zera qualquer revelação anterior. **Só rode de novo se
quiser refazer o sorteio do zero** — isso apaga o que já foi sorteado.

### Restrições do sorteio

O Gus Amato só pode tirar — e só pode ser tirado por — alguém do `GRUPO_GUS`
definido no topo do `server.js` (10 pessoas). O restante do grupo se sorteia
livremente, e ninguém tira a si mesmo.

O sorteio é por amostragem de rejeição: embaralha até cair um arranjo válido.
Se as restrições ficarem impossíveis de satisfazer, o endpoint devolve
`no_valid_draw` em vez de gravar um sorteio inválido. E se algum nome do
`GRUPO_GUS` não existir no banco (typo), devolve `unknown_names` listando quais
— assim uma restrição nunca é ignorada em silêncio.

## 4b. Ver quem tirou quem

```bash
curl -s https://presentinho-do-textor.onrender.com/api/admin/results \
  -H "x-admin-secret: SEU_ADMIN_SECRET"
```

Devolve `name`, `receiver`, `revealed` e `revealed_at` de todo mundo. Exige o
`ADMIN_SECRET` — sem ele, 401.

## 5. Compartilhar

Agora é só mandar a URL pública do Render pro grupo. Cada pessoa:
1. Seleciona o próprio nome
2. Digita o PIN (4 últimos dígitos do celular)
3. Vê o resultado uma única vez
4. Vai para a tela de agradecimento

## Notas de segurança

- Os PINs ficam salvos como hash (bcrypt) no banco — nem você, olhando direto
  no Supabase, consegue ver o PIN em texto puro de volta.
- O navegador nunca recebe a lista de pares — só o nome sorteado da pessoa que
  acabou de confirmar o PIN certo.
- Uma vez revelado, o banco marca `revealed = true` e passa a recusar novas
  tentativas para aquele nome (erro 409), mesmo que alguém tente manipular a
  requisição diretamente.
- O endpoint de re-sorteio (`/api/admin/draw`) exige o `ADMIN_SECRET` — guarde
  bem essa senha.
