-- Presentinho do Textor — schema do Supabase
-- Rode isso inteiro no SQL Editor do seu projeto Supabase.

create table if not exists participants (
  name text primary key,
  pin_hash text not null,
  receiver text references participants(name),
  revealed boolean not null default false,
  revealed_at timestamptz
);

-- Participantes com o PIN já criptografado (bcrypt).
-- O PIN em texto puro nunca fica salvo no banco.
insert into participants (name, pin_hash) values
  ('Rafael Fernandez', '$2b$10$QxacJPh3Q7AmfqZ7bVdNP.1LolY7sQNGimPir6WucY.uUzrUZlCNO'),
  ('Yasmim', '$2b$10$R7E11tH7CaN4cVti0AAP4.jaTnqdq1IPG.8YLuM.xLIZjRvrrUkmG'),
  ('Rapha Capato', '$2b$10$.vjYTgvkNALFZJV3KRD2pOtBJFnsv9GRenHmHh/3nDO69k2hX7f.K'),
  ('Arthur Correa', '$2b$10$UgR797lKKJ2REshnvL1reORO4HkuhlEpmO6Y7CI0F6ifTbROVV2VS'),
  ('Carol Botton', '$2b$10$/6/CBcb7RfxunHuDUIj7b.SQOliH2RI7oR2KL4p5cd1asJ2zwHKly'),
  ('Bia Brossel', '$2b$10$dLjqTOiILPW/qYw1wqC3GO0lju0wm/wp6JFYCN8JZZhfnXXI2ebUO'),
  ('Kkao', '$2b$10$4G0wWce5iLY160rzwst9xupFf1ZYcV2FphNgavDndy7uE0fEsRxs6'),
  ('Mau', '$2b$10$.D4n7D5Aj0Hyu4M7CGzZrelKQsWj9ypMweNVU/93DVFpkzUcEWs7e'),
  ('Rafa Tomazela', '$2b$10$Z16WP81Sw8HU0JroslR3Nu6BO/d9rAoCmwjhJzkq088KzDEd6Qy1i'),
  ('Gabi Afif', '$2b$10$sY.WpwV89QdWcO7zWrE0FuirBATY7/tf5Iq4XUL0gv9jzh7JmGkPa'),
  ('Lucca Guidoni', '$2b$10$pCim4BFouGRniFUxdkScrOufCwHej/x3G7Lo7k768tv4e3IbEGlN2'),
  ('Lucca Claro', '$2b$10$r5hX9WQjHuAygYbuyDmTE.ZkexognTVPEvVw.NyYyJtxWhCXXhKhS'),
  ('Carmona', '$2b$10$LbwqTVv7paVpX/tRbPr19.YNK2KjyS1cptjopXI65GvFTe74/nblO'),
  ('Victor Klock', '$2b$10$c5vn2gKtRdRMHqfo87iy8OXzKmYbxH3vr.fepUC2R57IFL9mQCD8S'),
  ('Mett Corrrea', '$2b$10$hAEyo3nMb9gaiDb1YM5B6OurJNCAMxjGSp0EqRZb2Q.ykaPqpvqOe'),
  ('Manu Carmona', '$2b$10$JsvmlpImGJRb.aYB4GRGre.G/5ppN2seFMDQdWC.ZNPjPmf53ZBve'),
  ('Igor André', '$2b$10$NPXXYXLHaKDVHgTz.d0rmujwGHHVU17LPC6fZeF5DmDF6AQf2V9Wa'),
  ('Gus Amato', '$2b$10$49ZQ9txOfyskm2caYeHKWeSXpKvcqWsr1yQrhjgCZbOqFIL6R/qvu')
on conflict (name) do nothing;
