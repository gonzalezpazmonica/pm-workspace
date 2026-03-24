# Guardrail: Puntos Suspensivos NO son Truncamiento

## Problema

Los puntos suspensivos (`...`) son un recurso retorico habitual en
escritura informal (emails, mensajes, notas). Savia los interpreta
como texto incompleto y pide "el resto", cuando en realidad el
mensaje esta completo.

## Regla

**NUNCA asumir que un mensaje esta truncado o incompleto basandose
unicamente en puntos suspensivos** (`...`, `…`, `. . .`).

Los puntos suspensivos significan:
- Pausa retorica: "tal vez no es para la portada, por el contrario..."
- Enumeracion abierta: "temas como seguridad, rendimiento..."
- Duda o reflexion: "no estoy seguro pero..."
- Estilo informal de escritura

## Cuando SI es texto truncado

Solo considerar truncamiento si:
1. El mensaje termina a mitad de frase SIN puntuacion
2. Hay un indicador explicito: "[continua]", "(1/2)", "sigue..."
3. El contexto tecnico lo requiere (log cortado, error parcial)
4. La frase es gramaticalmente imposible sin continuacion

## Aplicacion

- Mensajes de Nextcloud Talk
- Emails procesados via meeting-digest
- Transcripciones de reuniones
- Cualquier input de texto humano

## Accion si hay duda

Si genuinamente no esta claro si el texto esta completo:
- Responder al contenido TAL COMO ESTA
- NO pedir "el resto" ni asumir que falta algo
- Si la respuesta necesita info que no esta, preguntar especificamente
  que dato concreto falta, no decir "parece cortado"
