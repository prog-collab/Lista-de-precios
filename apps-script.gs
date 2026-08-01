/****************************************************************
 *  AGREGAR PRODUCTOS DESDE LA APP  →  Google Sheet
 *
 *  Qué hace: recibe los productos que cargás desde la app y los
 *  guarda en una pestaña "AltasApp" de la planilla LISTA.
 *
 *  CÓMO INSTALARLO (una sola vez):
 *  1) Abrí la planilla en Google Sheets.
 *  2) Menú  Extensiones → Apps Script.
 *  3) Borrá lo que haya y pegá TODO este archivo.
 *  4) Guardá (ícono del disquete).
 *  5) Implementar → Nueva implementación → tipo "Aplicación web".
 *        - Descripción: altas app
 *        - Ejecutar como:  Yo
 *        - Quién tiene acceso:  Cualquier persona
 *     → Implementar → Autorizar (elegí tu cuenta, "Permitir").
 *  6) Copiá la "URL de la aplicación web" (termina en /exec).
 *  7) Pegá esa URL en index.html, en la línea:
 *        const SCRIPT_URL = '';   →   const SCRIPT_URL = 'https://....../exec';
 *  8) Subí index.html a GitHub.
 *
 *  IMPORTANTE para que se vea en TODOS los aparatos:
 *  la planilla tiene que estar compartida como "Cualquier persona
 *  con el enlace: Lector" (así la app puede leer la pestaña AltasApp).
 ****************************************************************/

var SHEET_ID = '1cg2fM1xGxzqBOoSv2mC68W3OcsKmNHAgQSthRxkOVDI';
var TAB = 'AltasApp';

function doPost(e){
  try{
    var d = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.openById(SHEET_ID);

    // --- Configuración compartida (interés mensual, etc.) ---
    // Guarda/actualiza una fila clave/valor en la pestaña "Config".
    if(d.tipo === 'config'){
      var cf = ss.getSheetByName('Config');
      if(!cf){ cf = ss.insertSheet('Config'); cf.appendRow(['clave','valor']); }
      var data = cf.getDataRange().getValues();
      var fila = -1;
      for(var i=1; i<data.length; i++){ if(String(data[i][0]) === String(d.clave)){ fila = i+1; break; } }
      if(fila > 0){ cf.getRange(fila, 2).setValue(d.valor); }
      else { cf.appendRow([d.clave, d.valor]); }
      return ContentService.createTextOutput(JSON.stringify({ok:true}))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var sh = ss.getSheetByName(TAB);
    if(!sh){
      sh = ss.insertSheet(TAB);
      sh.appendRow(['fecha','accion','codigo','nombre','categoria','talles_json','precio_lista']);
    }
    sh.appendRow([
      new Date(),
      d.accion || 'alta',   // alta | edit | baja
      d.codigo || '',
      d.nombre || '',
      d.categoria || '',
      JSON.stringify(d.talles || []),
      d.precio_lista || ''
    ]);
    return ContentService.createTextOutput(JSON.stringify({ok:true}))
      .setMimeType(ContentService.MimeType.JSON);
  }catch(err){
    return ContentService.createTextOutput(JSON.stringify({ok:false, error:String(err)}))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// Permite probar en el navegador que el script está vivo.
function doGet(){
  return ContentService.createTextOutput('OK - listo para recibir altas');
}

/****************************************************************
 *  ARREGLO ÚNICO: poner un 0 adelante a los códigos Taverniti
 *  de 4 dígitos + XXX  (ej. 4240XXX -> 04240XXX)
 *
 *  CÓMO USARLO (una sola vez):
 *  1) En el editor de Apps Script, elegí "padCodigosTaverniti"
 *     en la lista de funciones (arriba, al lado de Ejecutar).
 *  2) Tocá ▶ Ejecutar y autorizá si lo pide.
 *  3) Mirá el registro: dice cuántos cambió.
 *  Es seguro correrlo más de una vez: a los que ya tienen 5
 *  dígitos no los vuelve a tocar.
 ****************************************************************/
function padCodigosTaverniti(){
  var ss = SpreadsheetApp.openById(SHEET_ID);
  var sh = ss.getSheets()[0];                 // Hoja1 (la lista principal)
  var last = sh.getLastRow();
  var vals = sh.getRange(1, 1, last, 2).getValues();  // columnas A (código) y B (nombre)
  var re = /^\d{4}XXX$/;
  var n = 0;
  for(var i=0; i<vals.length; i++){
    var cod = (vals[i][0]==null ? '' : String(vals[i][0])).trim();
    var nom = (vals[i][1]==null ? '' : String(vals[i][1])).toLowerCase();
    if(re.test(cod) && nom.indexOf('taverniti') >= 0){
      sh.getRange(i+1, 1).setValue('0' + cod);  // queda como texto (tiene XXX), conserva el 0
      n++;
    }
  }
  Logger.log('Códigos cambiados: ' + n);
}
