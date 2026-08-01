# Revisión de categorías — para corregir en el Excel

La columna **Fila** es el número de fila en el Excel donde está el encabezado.
La columna **Prod** es cuántos productos quedaron bajo esa categoría.

## ⚠️ Las que hay que revisar

| Fila | Prod | Categoría detectada | Problema |
|-----:|-----:|---------------------|----------|
| 4 | 0 | EFECTIVO | Es la tabla de descuentos de arriba, no una categoría. (Se ignora sola, no molesta.) |
| 6 | 0 | $ | Ídem, ruido de la tabla de arriba. |
| 12 | 0 | $ | Ídem. |
| 327 | **170** | CAMISAS M LARGA HOMBRE | **Inflada**: acá adentro cayó el bloque sin título (las camisas WRANGLER/ALL SEASONS/CARTIER que viste mal). Si esas van en otra categoría, conviene ponerle un título propio a ese bloque (alrededor de la fila 358). |
| 623 | 1 | AERO C/FORRO TELA | Solo 1 producto. ¿Es categoría real o un producto suelto? |
| 625 | 0 | AERO C/POLAR | Sin productos. Probablemente es una fila de talles o quedó pegada a la de abajo. |
| 3187 | **0** | JEANS HOMBRE | **Sin productos**: hay un encabezado JEANS HOMBRE pero justo debajo (fila 3188) viene "LAST POINT", así que los jeans quedaron bajo LAST POINT. Revisar ese orden. |
| 4332 | 1 | CHALINAS | Solo 1. ¿Real? |
| 4397 | 2 | CINTOS DAMA | Solo 2. Revisar. |
| 4416 | 3 | TWIN SET | Solo 3. Revisar si está bien. |
| 4548 | 2 | REMERAS HILO M 3/4 | Solo 2. Revisar. |
| 4828 | 3 | POLERAS Y 1/2 POL. TEJIDAS | Solo 3. Revisar. |
| 5357 | 1 | Billeteras dama | Solo 1. Revisar. |

## ✅ Las que salieron bien (no hace falta tocar)

| Fila | Prod | Categoría |
|-----:|-----:|-----------|
| 22 | 151 | BUZOS HOMBRE |
| 180 | 6 | RELOJES TAVERNITI |
| 188 | 5 | BUZO SIN FRIZA |
| 196 | 4 | POLAR CAMPERA |
| 202 | 122 | CAMISAS MANGA CORTA |
| 502 | 16 | CAMISETAS HOMBRE |
| 520 | 100 | CAMPERAS HOMBRE (PERCHAS) |
| 626 | 64 | AERO MICROFIBRA C/POLAR |
| 693 | 53 | CAMPERAS ALGODÓN Y ACETATO (ESTANTE) |
| 747 | 85 | TAVERNITI |
| 834 | 82 | CAMPERAS TEJIDAS HOMBRE |
| 918 | 29 | CHALECOS HOMBRE |
| 949 | 18 | CHALECOS TEJIDOS |
| 969 | 148 | CHOMBAS M/LARGA |
| 1120 | 424 | CHOMBAS M/CORTA |
| 1547 | 6 | CONJUNTOS HOMBRE |
| 1557 | 44 | PANTALONES BUZO (ALG Y ACET.) |
| 1603 | 17 | PIJAMA HOMBRE |
| 1622 | 10 | POLERAS Y 1/2 POLERAS TEJIDAS |
| 1634 | 177 | REMERAS M LARGA |
| 1813 | 112 | SWEATERS HOMBRE |
| 1928 | 45 | SUDADERAS/MUSCULOSAS HOMBRE |
| 1978 | 825 | REMERAS M CORTA |
| 2806 | 37 | SHORTS Y BERM. BAÑO |
| 2848 | 311 | BERMUDAS HOMBRE |
| 3162 | 22 | CALZADO HOMBRE |
| 3188 | 81 | LAST POINT |
| 3275 | 543 | TAVERNITI JEAN |
| 3822 | 11 | NÁUTICOS/PANT. BUZO S/FRIZA |
| 3836 | 32 | PANTALONES VESTIR |
| 3871 | 26 | SLIP |
| 3900 | 24 | BOXER |
| 3926 | 17 | MEDIAS |
| 3946 | 28 | CINTOS/CORBATAS/ACCESORIOS |
| 3977 | 11 | PERFUMES |
| 3991 | 34 | BERMUDAS DAMA |
| 4032 | 47 | SHORTS DAMA |
| 4083 | 50 | CAMISAS DAMA |
| 4136 | 181 | CAMPERAS DAMA |
| 4319 | 10 | CHALECOS DAMA |
| 4335 | 60 | BUZOS DAMA |
| 4401 | 13 | CHOMBAS DAMA |
| 4422 | 46 | VESTIDOS |
| 4469 | 37 | MUSCULOSAS DAMA |
| 4509 | 31 | REMERAS HILO M LARGA |
| 4542 | 4 | REMERAS HILO M CORTA |
| 4553 | 152 | REMERAS DAMA M CORTA |
| 4709 | 55 | REMERAS DAMA MANGA LARGA |
| 4767 | 43 | REMERAS DAMA |
| 4817 | 7 | POLERAS Y 1/2 POL. ALGODÓN M LARGA |
| 4833 | 22 | CONJUNTOS CAMPERA- |
| 4857 | 92 | CAPRIS |
| 4956 | 38 | POLLERAS |
| 4998 | 29 | CALZAS DAMA |
| 5030 | 27 | JEANS DAMA |
| 5060 | 255 | JEANS TAVERNITI DAMA |
| 5318 | 36 | CARTERAS/MORRALES/BANDOLERAS/MOCHILAS |

## Recordá, para que lo lea bien:

- El **nombre de la categoría** va en la **columna B** (la de los nombres de producto), en su propia fila.
- Esa fila **no debe tener precios**.
- Los productos van **debajo** del encabezado.
