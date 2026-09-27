-- Presentinho do Textor — coluna permanente "ja viu o nome pelo menos 1 vez".
--
-- RODE ISSO ANTES DE USAR O reabrir.sh.
-- O reabrir zera a coluna `revealed`, que hoje e a unica fonte dessa
-- informacao. Esta migracao copia o estado atual para uma coluna que o
-- reabrir nunca toca — depois disso, reabrir quantas vezes quiser e seguro.
--
-- Pode rodar mais de uma vez sem estragar nada.

alter table participants
  add column if not exists ja_viu boolean not null default false;

-- Preserva quem ja revelou ate agora.
update participants
   set ja_viu = true
 where revealed = true
   and ja_viu = false;

-- Confira: ja_viu tem que bater com o numero de gente que ja revelou hoje.
select count(*) filter (where ja_viu)   as ja_viram,
       count(*) filter (where revealed) as revelados_agora,
       count(*)                          as total
  from participants;
