import openpyxl, re, json
wb = openpyxl.load_workbook('LISTA 2025.xlsx', data_only=True)
ws = wb['Hoja1']
rows = list(ws.iter_rows(values_only=True))

def isnum(x): return isinstance(x,(int,float))
def isprice(x): return isnum(x) and x > 100
DATE = re.compile(r'^\s*\d{1,2}/\d{2}')

def codestr(x):
    if x is None: return None
    if isinstance(x,float) and x.is_integer(): return str(int(x))
    return str(x).strip()

cur_cat = None
cur_tallas = [None,None,None,None]
cur_name = None
productos = []

for i, r in enumerate(rows):
    a,b = r[0], r[1]
    prices = [r[2], r[3], r[4], r[5]]
    has_price = any(isprice(x) for x in prices)

    if not has_price:
        # header / categoria / talles row
        # talle labels from C-F (text only)
        new_tallas = []
        for x in prices:
            if isinstance(x,str) and x.strip():
                new_tallas.append(x.strip())
            elif isnum(x):
                new_tallas.append(str(int(x)) if (isinstance(x,float) and x.is_integer()) else str(x))
            else:
                new_tallas.append(None)
        if any(new_tallas):
            cur_tallas = new_tallas
        # category name in col B (text, not a number)
        if isinstance(b,str) and b.strip():
            if DATE.match(b.strip()):
                # encabezado huérfano sin título (bloque de jeans/pantalones hombre)
                cur_cat = "JEANS HOMBRE"
            else:
                cur_cat = b.strip()
        continue

    # product row
    codigo = None
    if a is not None and not (isinstance(a,str) and DATE.match(str(a))):
        codigo = codestr(a)
    nombre = None
    if isinstance(b,str) and b.strip():
        nombre = b.strip()
        cur_name = nombre
    else:
        nombre = cur_name
    # talle-price pairs
    tp = []
    for idx,x in enumerate(prices):
        if isprice(x):
            label = cur_tallas[idx] if idx < len(cur_tallas) and cur_tallas[idx] else f"Talle {idx+1}"
            tp.append({"talle": label, "precio": round(float(x))})
    if not tp:
        continue
    productos.append({
        "codigo": codigo or "",
        "nombre": nombre or "",
        "categoria": cur_cat or "",
        "precio_lista": tp[0]["precio"],
        "talles": tp
    })

json.dump(productos, open('/tmp/productos.json','w'), ensure_ascii=False)
print("TOTAL productos:", len(productos))
print("con codigo:", sum(1 for p in productos if p['codigo']))
print("sin codigo:", sum(1 for p in productos if not p['codigo']))
print("con nombre:", sum(1 for p in productos if p['nombre']))
print("sin nombre:", sum(1 for p in productos if not p['nombre']))
print("con categoria:", sum(1 for p in productos if p['categoria']))
print("con >1 talle:", sum(1 for p in productos if len(p['talles'])>1))
from collections import Counter
cats = Counter(p['categoria'] for p in productos)
print("\nCategorias (top 25):")
for c,n in cats.most_common(25):
    print(f"  {n:5d}  {c[:45]}")
print("\nMuestras:")
for p in productos[:3] + productos[200:203] + productos[900:903]:
    print(" ", p)
