-- ============================================================
--  CRM completo de clientes: alta/edición, campos de contacto y redes,
--  saldo de cuenta corriente discriminado por local, y estudio de
--  cercanía vía enlaces (no cálculo de distancia en el servidor).
--
--  "clientes" ya tenía una política RLS "is_admin() para todo" desde antes
--  (cuenta_corriente_clientes_schema.sql) — agregar columnas nullable acá
--  no requiere tocar RLS de nuevo.
--
--  NOTA sobre el "estudio de direcciones" pedido por el usuario: se evaluó
--  geocodificar automáticamente la dirección del cliente contra un servicio
--  externo (Nominatim) para calcular distancia en km al local — el sistema
--  de seguridad lo bloqueó de forma dura por ser un envío de datos
--  personales (domicilio de un cliente) a un tercero no confiable desde el
--  backend, sin importar la autorización del usuario. Se resolvió distinto:
--  cada cliente con dirección cargada tiene un link "Ver ruta en Google
--  Maps" que abre las indicaciones desde el local hasta su domicilio — la
--  consulta la hace el navegador del vendedor al hacer click, nunca el
--  backend, así que no cruza ese límite de confianza.
--
--  Confirmado explícitamente por el usuario el 2026-07-12 antes de aplicar.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table clientes add column if not exists email text;
alter table clientes add column if not exists direccion text;
alter table clientes add column if not exists instagram text;
alter table clientes add column if not exists facebook text;
alter table clientes add column if not exists fecha_nacimiento date;
alter table clientes add column if not exists notas text;
alter table clientes add column if not exists etiqueta text;

-- Saldo de cuenta corriente discriminado por local (para clientes que
-- tienen movimientos en Camerino y en Giustozzi a la vez). El view general
-- v_cuenta_corriente_saldo (de cuenta_corriente_clientes_schema.sql) sigue
-- existiendo para el saldo combinado.
create or replace view v_cuenta_corriente_saldo_local
with (security_invoker = true) as
select
  cliente_id,
  local,
  sum(case when tipo = 'cargo' then monto else -monto end) as saldo,
  max(created_at) as ultimo_movimiento
from cuenta_corriente_movimientos
group by cliente_id, local;
