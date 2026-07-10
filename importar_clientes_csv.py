#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Importa los contactos exportados de Google Contacts (CSV) a Supabase (tabla "clientes").
Solo carga nombre + teléfono — el CUIT se completa después, cliente por cliente,
con el botón "Guardar cliente" al facturar (así queda linkeado a los datos reales de AFIP).

Uso:
  1) En contacts.google.com (con camerinosantafe@gmail.com) → Exportar → formato "Google CSV".
  2) Guardá el archivo como contactos.csv en esta misma carpeta.
  3) Corré:
       $env:SUPABASE_URL="https://grswqigekcopfrozcxqj.supabase.co"
       $env:SUPABASE_SERVICE_KEY="PEGAR-SERVICE-ROLE-KEY"
       python importar_clientes_csv.py
"""
import csv, json, os, re, sys, urllib.request, urllib.error

URL = os.environ.get("SUPABASE_URL")
KEY = os.environ.get("SUPABASE_SERVICE_KEY")
if not URL or not KEY:
    print("Faltan SUPABASE_URL y/o SUPABASE_SERVICE_KEY (ver instrucciones arriba).")
    sys.exit(1)

ARCHIVO = "contactos.csv"
if not os.path.exists(ARCHIVO):
    print(f"No encontré {ARCHIVO} en esta carpeta. Exportalo desde contacts.google.com primero.")
    sys.exit(1)


def limpiar_telefono(v):
    v = re.sub(r"[^\d+]", "", v or "")
    return v or None


rows = []
with open(ARCHIVO, encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        nombre = (row.get("Name") or "").strip()
        if not nombre:
            first = (row.get("First Name") or "").strip()
            last = (row.get("Last Name") or "").strip()
            nombre = (first + " " + last).strip()
        tel = None
        for col in row:
            if col.startswith("Phone") and col.endswith("Value") and row.get(col):
                tel = limpiar_telefono(row[col])
                break
        if not nombre or not tel:
            continue
        rows.append({"nombre": nombre, "telefono": tel})

print(f"Contactos con nombre y teléfono a subir: {len(rows)}")
if not rows:
    sys.exit(0)

endpoint = URL.rstrip("/") + "/rest/v1/clientes"
headers = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}

BATCH = 500
total = 0
for i in range(0, len(rows), BATCH):
    chunk = rows[i:i + BATCH]
    data = json.dumps(chunk, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            total += len(chunk)
            print(f"  subidos {total}/{len(rows)}")
    except urllib.error.HTTPError as e:
        print("ERROR HTTP", e.code, e.read().decode("utf-8", "replace")[:500])
        sys.exit(1)

print("Listo. Contactos cargados en Supabase (tabla clientes, sin CUIT todavía).")
