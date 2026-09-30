---
version_bump: minor
section: Added
---

### Added

- SE-422: API HTTP de Savia Files (`savia-vaults serve --transport http`) para equipos que sirven Savia en red. Permite subir ficheros grandes con reanudación (protocolo tus 1.0: una subida cortada sigue donde se quedó aunque el servidor se reinicie), descargar por rangos y consultar documentos. Usa usuarios y tokens por persona, con los mismos permisos que MCP. Desde el chat, `vault_files upload` y `link` dan una URL y una autorización de un solo uso para que una persona suba o baje el fichero sin pasarlo por el contexto. Probado con el cliente oficial tus-js-client. Medido: 1 GiB a ~200 MB/s (N2) y ~57 MB/s (cifrado), con 185 MiB de memoria.
