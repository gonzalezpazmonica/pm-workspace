# Diagram Generation — Dominio

## Por que existe esta skill

La arquitectura de un proyecto necesita representacion visual para comunicacion con
stakeholders y deteccion de problemas estructurales. Esta skill genera diagramas
automaticamente desde codigo e infraestructura, exportando a Draw.io, Miro o Mermaid.

## Conceptos de dominio

- **Deteccion de componentes**: analisis de IaC, codigo fuente y docs para identificar servicios, DBs, colas
- **Modelo Mermaid**: representacion intermedia del diagrama que se convierte al formato destino
- **Metadata**: fichero JSON con referencia al diagrama remoto, elementos detectados y timestamps
- **Tipos de diagrama**: architecture (C4-style), flow (datos), sequence (temporal), orgchart (jerarquia)

## Reglas de negocio que implementa

- Diagram Config (diagram-config.md): constantes de herramientas MCP, formatos y estructura por proyecto
- Language Packs (language-packs.md): deteccion de stack tecnologico para identificar componentes
- Reglas de negocio del proyecto: validacion de entidades del diagrama contra reglas-negocio.md

## Relacion con otras skills

- **Upstream**: project-audit (identifica necesidad de diagramas en fase de auditoria)
- **Downstream**: diagram-import (consume diagramas generados para crear Features/PBIs)
- **Paralelo**: orgchart-import (comparte plantillas Mermaid pero opera sobre datos de equipo, no arquitectura)

## Decisiones clave

- Mermaid como representacion intermedia: portable, legible, convertible a cualquier herramienta
- Deteccion multi-fuente (IaC > codigo > docs): priorizar fuentes mas fiables de arquitectura
- Local como fallback sin MCP: siempre se puede generar .mermaid aunque Draw.io o Miro no esten configurados
