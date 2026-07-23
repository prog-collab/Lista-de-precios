-- ============================================================
--  Modulo "Reservas" (sena / apartado de mercaderia).
--
--  Caso: viene un cliente, no le alcanza para pagar todo, deja una sena
--  y "aparta" el producto. El producto se saca de la venta (se descuenta
--  del stock igual que una venta, pero con motivo='reserva') y queda a la
--  espera de que la persona vuelva con el resto y lo retire.
--
--  Reglas de negocio confirmadas con el usuario (2026-07-23):
--   - Pagos: la sena inicial + cuantos abonos parciales haga falta hasta
--     completar el total (ledger inmutable reserva_pagos, mismo patron que
--     cuenta_corriente_movimientos / stock_movimientos).
--   - Vencimiento: se guarda una fecha; las vencidas se resaltan en la UI,
--     pero el stock se libera A MANO (liberar_reserva_stock) cuando el
--     usuario lo decide — nada automatico.
--   - Cancelacion: SIEMPRE se reintegra la sena (sale de la caja, con el
--     mismo medio con que entro) y se libera el stock.
--   - Al retirar: facturar en AFIP es OPCIONAL (los campos factura_* se
--     completan desde la web con el mismo facturador que usa "ventas").
--
--  Enlace con lo que ya existe:
--   - Stock: reusa _ajustar_stock_uno (la unica funcion que escribe stock y
--     respeta el trigger de proteccion + local_asignado). Motivos nuevos en
--     stock_movimientos: 'reserva' (apartar) y 'reserva_cancelada' (liberar).
--   - Caja: cada pago/reintegro en efectivo queda atado a la caja_sesion del
--     momento; cerrar_caja_sesion ahora suma tambien el efectivo neto de
--     reservas del dia (ver mas abajo). Igual que ventas, crear una reserva
--     o cobrar un abono exige una caja abierta en ese local.
--   - Clientes: cliente_id obligatorio (FK a clientes) — hace falta para
--     poder avisarle por WhatsApp cuando esta lista / por vencer.
--
--  PENDIENTE DE APLICAR: pegar en el SQL Editor de Supabase (proyecto del
--  catalogo, grswqigekcopfrozcxqj) y Run. Idempotente (create if not exists /
--  create or replace), se puede correr mas de una vez sin romper nada.
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
--  Tabla "reservas": una fila por apartado. El saldo NO se guarda acá
--  (se calcula desde el ledger de pagos, ver v_reservas) para no tener
--  dos fuentes de verdad que se puedan desincronizar.
-- ------------------------------------------------------------
create table if not exists reservas (
  id                uuid primary key default gen_random_uuid(),
  local             text not null check (local in ('camerino','giustozzi')),
  vendedor          text,                       -- email de quien la tomo (sbSession)
  vendedor_id       uuid,                        -- vendedor del turno, igual que ventas
  cliente_id        uuid not null references clientes(id) on delete restrict,
  fecha             date not null default current_date,
  items             jsonb not null default '[]'::jsonb,  -- [{codigo,nombre,talle,color,precio}]
  total             numeric(12,2) not null check (total > 0),
  estado            text not null default 'activa'
                      check (estado in ('activa','retirada','cancelada','vencida')),
  vencimiento       date,                        -- opcional; solo para resaltar en la UI
  caja_sesion_id    uuid references caja_sesiones(id),  -- caja donde se creo
  venta_id          uuid references ventas(id),  -- si al retirar se genero una venta
  -- Facturacion opcional al retirar (mismos campos que ventas):
  facturada         boolean not null default false,
  factura_tipo      text,                         -- 'A' | 'B'
  factura_pto_vta   integer,
  factura_numero    integer,
  factura_cae       text,
  nota              text,
  created_at        timestamptz not null default now(),
  retirada_at       timestamptz,
  cancelada_at      timestamptz
);

create index if not exists idx_reservas_estado  on reservas(estado);
create index if not exists idx_reservas_local   on reservas(local);
create index if not exists idx_reservas_cliente on reservas(cliente_id);
create index if not exists idx_reservas_fecha   on reservas(fecha desc);

alter table reservas enable row level security;
drop policy if exists "admin all reservas" on reservas;
create policy "admin all reservas" on reservas
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
--  Ledger de pagos de la reserva: sena, abonos y reintegros (al cancelar).
--  Inmutable, igual que cuenta_corriente_movimientos: nunca se edita, una
--  correccion es otro movimiento. El monto es SIEMPRE positivo; el signo lo
--  da 'tipo' (sena/abono suman, reintegro resta). Cada pago guarda el medio
--  y (si es efectivo) queda atado a la caja_sesion para el arqueo.
-- ------------------------------------------------------------
create table if not exists reserva_pagos (
  id                  uuid primary key default gen_random_uuid(),
  reserva_id          uuid not null references reservas(id) on delete restrict,
  tipo                text not null check (tipo in ('sena','abono','reintegro')),
  monto               numeric(12,2) not null check (monto > 0),
  medio               text not null check (medio in ('contado','transferencia','tarjeta_debito','tarjeta_credito')),
  transferencia_alias text,
  local               text,
  caja_sesion_id      uuid references caja_sesiones(id),
  usuario             text,
  nota                text,
  created_at          timestamptz not null default now()
);
create index if not exists idx_reserva_pagos_reserva on reserva_pagos(reserva_id);
create index if not exists idx_reserva_pagos_caja on reserva_pagos(caja_sesion_id);
create index if not exists idx_reserva_pagos_fecha on reserva_pagos(created_at desc);

alter table reserva_pagos enable row level security;
drop policy if exists "admin select reserva_pagos" on reserva_pagos;
drop policy if exists "admin insert reserva_pagos" on reserva_pagos;
drop policy if exists "gerente delete reserva_pagos" on reserva_pagos;
create policy "admin select reserva_pagos" on reserva_pagos for select using (public.is_admin());
create policy "admin insert reserva_pagos" on reserva_pagos for insert with check (public.is_admin());
create policy "gerente delete reserva_pagos" on reserva_pagos for delete using (public.is_gerente());

-- ------------------------------------------------------------
--  Vista v_reservas: la reserva + datos del cliente + lo pagado (neto de
--  reintegros) + el saldo pendiente. Es lo que lista la web.
-- ------------------------------------------------------------
drop view if exists v_reservas;
create view v_reservas
with (security_invoker = true) as
select
  r.*,
  c.nombre   as cliente_nombre,
  c.telefono as cliente_telefono,
  coalesce((
    select sum(case when p.tipo = 'reintegro' then -p.monto else p.monto end)
    from reserva_pagos p where p.reserva_id = r.id
  ), 0) as pagado,
  greatest(0, r.total - coalesce((
    select sum(case when p.tipo = 'reintegro' then -p.monto else p.monto end)
    from reserva_pagos p where p.reserva_id = r.id
  ), 0)) as saldo_pendiente
from reservas r
join clientes c on c.id = r.cliente_id;

-- ------------------------------------------------------------
--  Helper interno: valida que haya una caja abierta en el local y que sea
--  la que se paso (id), respetando local_asignado del usuario. Devuelve el
--  id validado. Lo usan crear_reserva y registrar_pago_reserva.
-- ------------------------------------------------------------
create or replace function public._reserva_caja_valida(p_caja_sesion_id uuid, p_local text)
returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_local_asignado text;
  v_ok boolean;
begin
  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local then
    raise exception 'Tu usuario solo puede operar en %', v_local_asignado;
  end if;
  select exists(
    select 1 from caja_sesiones cs
    where cs.id = p_caja_sesion_id and cs.local = p_local and cs.estado = 'abierta'
  ) into v_ok;
  if not v_ok then
    raise exception 'No hay una caja abierta en % — abrila antes de tomar la reserva o cobrar el abono.', p_local;
  end if;
  return p_caja_sesion_id;
end $function$;

-- ------------------------------------------------------------
--  crear_reserva: crea la reserva, APARTA el stock (descuenta -1 por item,
--  motivo='reserva') y registra la sena inicial. Todo en una transaccion
--  (todo o nada). Exige caja abierta. Devuelve la fila de v_reservas.
-- ------------------------------------------------------------
create or replace function public.crear_reserva(
  p_local              text,
  p_cliente_id         uuid,
  p_items              jsonb,
  p_total              numeric,
  p_caja_sesion_id     uuid,
  p_sena_monto         numeric,
  p_sena_medio         text,
  p_vendedor           text  default null,
  p_vendedor_id        uuid  default null,
  p_vencimiento        date  default null,
  p_sena_alias         text  default null,
  p_nota               text  default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva_id uuid;
  v_usuario    text;
  it           jsonb;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para tomar una reserva.';
  end if;
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local invalido.';
  end if;
  if p_cliente_id is null then
    raise exception 'Elegi un cliente para la reserva (hace falta para avisarle cuando este lista).';
  end if;
  if coalesce(jsonb_array_length(p_items), 0) = 0 then
    raise exception 'La reserva no tiene productos.';
  end if;
  if p_total is null or p_total <= 0 then
    raise exception 'El total de la reserva tiene que ser mayor a 0.';
  end if;
  if p_sena_monto is null or p_sena_monto <= 0 then
    raise exception 'La sena tiene que ser mayor a 0.';
  end if;
  if p_sena_monto > p_total then
    raise exception 'La sena no puede ser mayor que el total.';
  end if;

  perform public._reserva_caja_valida(p_caja_sesion_id, p_local);
  v_usuario := auth.jwt()->>'email';

  insert into reservas(local, vendedor, vendedor_id, cliente_id, items, total,
                       vencimiento, caja_sesion_id, nota)
  values (p_local, coalesce(p_vendedor, v_usuario), p_vendedor_id, p_cliente_id,
          p_items, p_total, p_vencimiento, p_caja_sesion_id, p_nota)
  returning id into v_reserva_id;

  -- Apartar el stock: -1 por cada item real (los "manual" no tienen stock).
  for it in select * from jsonb_array_elements(p_items) loop
    if coalesce((it->>'manual')::boolean, false) then
      continue;
    end if;
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', p_local, -1,
      'reserva', v_usuario, v_reserva_id
    );
  end loop;

  -- Sena inicial.
  insert into reserva_pagos(reserva_id, tipo, monto, medio, transferencia_alias,
                            local, caja_sesion_id, usuario)
  values (v_reserva_id, 'sena', p_sena_monto, coalesce(p_sena_medio,'contado'),
          p_sena_alias, p_local, p_caja_sesion_id, v_usuario);

  return (select to_jsonb(v) from v_reservas v where v.id = v_reserva_id);
end $function$;
grant execute on function public.crear_reserva(text, uuid, jsonb, numeric, uuid, numeric, text, text, uuid, date, text, text) to authenticated;

-- ------------------------------------------------------------
--  registrar_pago_reserva: agrega un abono. Exige caja abierta y reserva
--  'activa'. No deja pagar de mas (el abono se topea al saldo). Devuelve la
--  fila actualizada de v_reservas.
-- ------------------------------------------------------------
create or replace function public.registrar_pago_reserva(
  p_reserva_id     uuid,
  p_monto          numeric,
  p_medio          text,
  p_caja_sesion_id uuid,
  p_alias          text default null,
  p_nota           text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva  record;
  v_saldo    numeric;
  v_usuario  text;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para cobrar un abono.';
  end if;
  if p_monto is null or p_monto <= 0 then
    raise exception 'El abono tiene que ser mayor a 0.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
  if p_monto > v_saldo then
    raise exception 'El abono (%) es mayor que el saldo pendiente (%).', p_monto, v_saldo;
  end if;

  perform public._reserva_caja_valida(p_caja_sesion_id, v_reserva.local);
  v_usuario := auth.jwt()->>'email';

  insert into reserva_pagos(reserva_id, tipo, monto, medio, transferencia_alias,
                            local, caja_sesion_id, usuario, nota)
  values (p_reserva_id, 'abono', p_monto, coalesce(p_medio,'contado'), p_alias,
          v_reserva.local, p_caja_sesion_id, v_usuario, p_nota);

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;
grant execute on function public.registrar_pago_reserva(uuid, numeric, text, uuid, text, text) to authenticated;

-- ------------------------------------------------------------
--  retirar_reserva: el cliente vino con el resto y se lleva el producto.
--  Opcionalmente cobra el saldo que falte (como un ultimo abono) — si al
--  terminar queda saldo > 0, no deja retirar. NO vuelve a tocar el stock
--  (ya se aparto al crear la reserva). Marca 'retirada'. La facturacion,
--  si se pide, la hace la web y despues completa los campos factura_* con
--  facturar_reserva(). Devuelve la fila de v_reservas.
-- ------------------------------------------------------------
create or replace function public.retirar_reserva(
  p_reserva_id       uuid,
  p_caja_sesion_id   uuid    default null,
  p_pago_monto       numeric default null,   -- saldo que se cobra en el momento (opcional)
  p_pago_medio       text    default null,
  p_pago_alias       text    default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva record;
  v_saldo   numeric;
  v_usuario text;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para retirar una reserva.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  v_usuario := auth.jwt()->>'email';

  -- Cobro del saldo en el momento (si se paso).
  if p_pago_monto is not null and p_pago_monto > 0 then
    select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
    if p_pago_monto > v_saldo then
      raise exception 'El pago (%) es mayor que el saldo pendiente (%).', p_pago_monto, v_saldo;
    end if;
    perform public._reserva_caja_valida(p_caja_sesion_id, v_reserva.local);
    insert into reserva_pagos(reserva_id, tipo, monto, medio, transferencia_alias,
                              local, caja_sesion_id, usuario)
    values (p_reserva_id, 'abono', p_pago_monto, coalesce(p_pago_medio,'contado'),
            p_pago_alias, v_reserva.local, p_caja_sesion_id, v_usuario);
  end if;

  select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
  if v_saldo > 0 then
    raise exception 'Todavia queda saldo pendiente (%). Cobralo antes de retirar.', v_saldo;
  end if;

  update reservas
    set estado = 'retirada', retirada_at = now()
    where id = p_reserva_id;

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;
grant execute on function public.retirar_reserva(uuid, uuid, numeric, text, text) to authenticated;

-- ------------------------------------------------------------
--  facturar_reserva: guarda los datos del comprobante AFIP en la reserva,
--  despues de que la web lo emitio con el facturador (igual que ventas).
-- ------------------------------------------------------------
create or replace function public.facturar_reserva(
  p_reserva_id  uuid,
  p_tipo        text,
  p_pto_vta     integer,
  p_numero      integer,
  p_cae         text
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida.';
  end if;
  update reservas set
    facturada = true, factura_tipo = p_tipo, factura_pto_vta = p_pto_vta,
    factura_numero = p_numero, factura_cae = p_cae
  where id = p_reserva_id;
  if not found then raise exception 'Reserva no encontrada.'; end if;
end $function$;
grant execute on function public.facturar_reserva(uuid, text, integer, integer, text) to authenticated;

-- ------------------------------------------------------------
--  cancelar_reserva: el cliente no la lleva. SIEMPRE se reintegra lo pagado
--  (con el mismo medio con que entro — asi la caja de efectivo cierra bien)
--  y se libera el stock (+1 por item, motivo='reserva_cancelada'). El
--  reintegro en efectivo pide caja abierta (sale plata de la caja). Marca
--  'cancelada'. Devuelve la fila de v_reservas.
-- ------------------------------------------------------------
create or replace function public.cancelar_reserva(
  p_reserva_id     uuid,
  p_caja_sesion_id uuid default null,
  p_nota           text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva record;
  v_usuario text;
  it        jsonb;
  m         record;
  v_tiene_efectivo boolean;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para cancelar una reserva.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  v_usuario := auth.jwt()->>'email';

  -- Si hay algo pagado en efectivo, el reintegro sale de la caja -> exigir
  -- caja abierta (mismo criterio que cobrar).
  select exists(
    select 1 from reserva_pagos p
    where p.reserva_id = p_reserva_id and p.tipo in ('sena','abono') and p.medio = 'contado'
  ) into v_tiene_efectivo;
  if v_tiene_efectivo then
    perform public._reserva_caja_valida(p_caja_sesion_id, v_reserva.local);
  end if;

  -- Reintegrar lo neto pagado, agrupado por medio (para que cada medio de
  -- pago cuadre por separado). Solo sena/abono; si ya hubo reintegros no se
  -- reintegra de nuevo (net = 0).
  for m in
    select medio,
           sum(case when tipo in ('sena','abono') then monto else -monto end) as neto
    from reserva_pagos
    where reserva_id = p_reserva_id
    group by medio
    having sum(case when tipo in ('sena','abono') then monto else -monto end) > 0
  loop
    insert into reserva_pagos(reserva_id, tipo, monto, medio, local,
                              caja_sesion_id, usuario, nota)
    values (p_reserva_id, 'reintegro', m.neto, m.medio, v_reserva.local,
            case when m.medio = 'contado' then p_caja_sesion_id else null end,
            v_usuario, coalesce(p_nota, 'Reintegro por cancelacion'));
  end loop;

  -- Liberar el stock apartado.
  for it in select * from jsonb_array_elements(v_reserva.items) loop
    if coalesce((it->>'manual')::boolean, false) then
      continue;
    end if;
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_reserva.local, 1,
      'reserva_cancelada', v_usuario, p_reserva_id
    );
  end loop;

  update reservas
    set estado = 'cancelada', cancelada_at = now(),
        nota = coalesce(p_nota, nota)
    where id = p_reserva_id;

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;
grant execute on function public.cancelar_reserva(uuid, uuid, text) to authenticated;

-- ------------------------------------------------------------
--  liberar_reserva_stock: para una reserva VENCIDA que se decide dar de
--  baja SIN reintegrar (la sena queda para el negocio; se libera solo el
--  stock y se marca 'vencida'). El reintegro, si se quiere hacer, se maneja
--  aparte con cancelar_reserva. Devuelve la fila de v_reservas.
-- ------------------------------------------------------------
create or replace function public.liberar_reserva_stock(
  p_reserva_id uuid,
  p_nota       text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva record;
  v_usuario text;
  it        jsonb;
begin
  if not public.is_gerente() then
    raise exception 'Solo el gerente puede vencer una reserva reteniendo la sena.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  v_usuario := auth.jwt()->>'email';

  for it in select * from jsonb_array_elements(v_reserva.items) loop
    if coalesce((it->>'manual')::boolean, false) then
      continue;
    end if;
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_reserva.local, 1,
      'reserva_cancelada', v_usuario, p_reserva_id
    );
  end loop;

  update reservas
    set estado = 'vencida', cancelada_at = now(),
        nota = coalesce(p_nota, nota)
    where id = p_reserva_id;

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;
grant execute on function public.liberar_reserva_stock(uuid, text) to authenticated;

-- ------------------------------------------------------------
--  Integracion con el arqueo de caja: cerrar_caja_sesion suma ahora tambien
--  el EFECTIVO neto de reservas de esa caja (senas + abonos en efectivo,
--  menos reintegros en efectivo). Misma firma que la version original
--  (caja_sesiones_schema.sql) — solo cambia el calculo de efectivo_esperado.
-- ------------------------------------------------------------
create or replace function public.cerrar_caja_sesion(
  p_sesion_id uuid, p_gastos numeric, p_retiros numeric, p_adelantos numeric,
  p_cambio numeric, p_arqueo numeric, p_observaciones text default null
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_sesion record;
  v_ventas_contado numeric := 0;
  v_reservas_contado numeric := 0;
  v_esperado numeric;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para cerrar la caja.';
  end if;
  select * into v_sesion from caja_sesiones where id = p_sesion_id for update;
  if not found then raise exception 'Caja no encontrada.'; end if;
  if v_sesion.estado <> 'abierta' then
    raise exception 'Esta caja ya esta cerrada.';
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_sesion.local then
    raise exception 'Tu usuario solo puede cerrar la caja de %', v_sesion.local;
  end if;

  select coalesce(sum(pago_contado),0) into v_ventas_contado
    from ventas where caja_sesion_id = p_sesion_id;

  -- Efectivo neto de reservas cobrado/reintegrado en esta caja.
  select coalesce(sum(case when tipo = 'reintegro' then -monto else monto end), 0)
    into v_reservas_contado
    from reserva_pagos
    where caja_sesion_id = p_sesion_id and medio = 'contado';

  v_esperado := v_sesion.fondo_inicial + v_ventas_contado + v_reservas_contado
              + coalesce(p_cambio,0) - coalesce(p_gastos,0)
              - coalesce(p_retiros,0) - coalesce(p_adelantos,0);
  v_usuario := auth.jwt()->>'email';

  update caja_sesiones set
    estado = 'cerrada',
    gastos = coalesce(p_gastos,0),
    retiros = coalesce(p_retiros,0),
    adelantos = coalesce(p_adelantos,0),
    cambio = coalesce(p_cambio,0),
    arqueo = p_arqueo,
    efectivo_esperado = v_esperado,
    diferencia = coalesce(p_arqueo,0) - v_esperado,
    observaciones = p_observaciones,
    cerrada_por = v_usuario,
    cerrada_at = now()
  where id = p_sesion_id;
end $function$;
grant execute on function public.cerrar_caja_sesion(uuid, numeric, numeric, numeric, numeric, numeric, text) to authenticated;
