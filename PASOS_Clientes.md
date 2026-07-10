# Base de clientes (para facturar y mandar el ticket por WhatsApp)

## Qué hace

- Un botón **🔍** al lado del campo CUIT (en Factura A) para buscar un cliente ya
  guardado por nombre/teléfono/CUIT y autocompletar.
- Un botón **💾 Guardar cliente** que aparece después de verificar el CUIT contra
  AFIP — guarda el nombre que devolvió AFIP + el teléfono que le pidas al cliente.
- El botón "Compartir por WhatsApp" del ticket, si el cliente tiene teléfono
  guardado, abre el chat directo con esa persona (si no, abre el selector normal
  de WhatsApp).

## 1. Crear la tabla en Supabase

Pegá el contenido de `supabase/clientes_schema.sql` en el **SQL Editor** de
Supabase (mismo proyecto del catálogo) y dale **Run**. Se puede correr varias
veces sin problema (usa `if not exists`).

## 2. (Opcional, una sola vez) Importar los contactos de Gmail

1. Entrá a **contacts.google.com** con la cuenta **camerinosantafe@gmail.com**.
2. Seleccioná los contactos que quieras (o todos) → **Exportar** → formato
   **"Google CSV"**.
3. Guardá el archivo como `contactos.csv` en esta misma carpeta
   (`Lista de precios para negocio`).
4. Corré (PowerShell):
   ```
   $env:SUPABASE_URL="https://grswqigekcopfrozcxqj.supabase.co"
   $env:SUPABASE_SERVICE_KEY="PEGAR-SERVICE-ROLE-KEY"
   python importar_clientes_csv.py
   ```
   (la Service Role Key está en Supabase → Project Settings → API — es secreta,
   no se guarda en el repo).

Esto carga **nombre + teléfono** de cada contacto que tenga ambos datos. El
**CUIT queda vacío** — se completa solo cuando factures a esa persona por
primera vez y guardes el cliente (así el nombre y CUIT quedan tal cual figuran
en AFIP, no como estén escritos en la agenda).

> Si preferís arrancar sin importar nada viejo, saltá este paso — la tabla se va
> llenando sola con el botón "Guardar cliente" en cada factura nueva.

## Cómo se usa día a día

1. En Factura A, empezás a escribir el CUIT o tocás **🔍** para buscar por
   nombre/teléfono si ya lo tenés guardado.
2. Al confirmar el CUIT (Enter), se verifica contra AFIP como ya andaba.
3. Si es un cliente nuevo, tocá **💾 Guardar cliente** — te pide el teléfono y
   lo guarda con el nombre real de AFIP para la próxima vez.
4. Al compartir el ticket por WhatsApp, si ese cliente tiene teléfono guardado,
   va derecho a su chat.
