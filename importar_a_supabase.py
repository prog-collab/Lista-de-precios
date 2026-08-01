#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sube/actualiza los artículos a Supabase (tabla "articulos").

Uso (cuando actualices precios):
  1) Regenerá productos.json desde el Excel:   python actualizar_precios.py
  2) Subí los cambios a Supabase:              python importar_a_supabase.py

Requiere dos variables de entorno (NO se guardan en el repo):
  SUPABASE_URL          -> https://grswqigekcopfrozcxqj.supabase.co
  SUPABASE_SERVICE_KEY  -> la "service_role key" (Project Settings → API). Es SECRETA.

En Windows (PowerShell), antes de correrlo:
  $env:SUPABASE_URL="https://grswqigekcopfrozcxqj.supabase.co"
  $env:SUPABASE_SERVICE_KEY="PEGAR-SERVICE-ROLE-KEY"
  python importar_a_supabase.py
"""
import json, os, sys, urllib.request, urllib.error

URL = os.environ.get("SUPABASE_URL")
KEY = os.environ.get("SUPABASE_SERVICE_KEY")
if not URL or not KEY:
    print("Faltan SUPABASE_URL y/o SUPABASE_SERVICE_KEY (ver instrucciones arriba).")
    sys.exit(1)

items = json.load(open("productos.json", encoding="utf-8"))

# Dedupe por código (último gana) y descartar sin código
seen = {}
for it in items:
    c = str(it.get("codigo") or "").strip()
    if not c:
        continue
    seen[c] = {
        "codigo": c,
        "nombre": it.get("nombre"),
        "categoria": it.get("categoria"),
        "precio_lista": float(it.get("precio_lista") or 0),
        "talles": [{"talle": str(t.get("talle", "")), "precio": t.get("precio")}
                   for t in (it.get("talles") or []) if isinstance(t, dict)],
    }
rows = list(seen.values())
print(f"Artículos a subir: {len(rows)}")

endpoint = URL.rstrip("/") + "/rest/v1/articulos?on_conflict=codigo"
headers = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates,return=minimal",
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

print("Listo. Artículos actualizados en Supabase.")
