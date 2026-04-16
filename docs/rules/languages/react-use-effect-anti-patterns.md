---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# React useEffect Anti-Patterns — Decision Checklist

> Fuente: "You Might Not Need an Effect" (React docs) + no-use-effect skill.

## 6 Reglas

### R1: Derivar estado, no sincronizarlo
NUNCA: `useEffect(() => setX(f(y)), [y])`
SIEMPRE: `const x = f(y)` inline o `const x = useMemo(() => f(y), [y])` si es costoso.

### R2: Librerias de data fetching
NUNCA: `useEffect(() => { fetch(url).then(setData) }, [])`
SIEMPRE: `const { data } = useQuery({ queryKey, queryFn })` (TanStack Query / SWR).
useEffect+fetch crea race conditions y reinventa caching.

### R3: Event handlers, no effects
NUNCA: `useEffect(() => { if (submitted) doSomething() }, [submitted])`
SIEMPRE: `const handleSubmit = () => { doSomething() }`
La logica procedural disparada por acciones de usuario va en handlers.

### R4: useMountEffect para inicializacion
Reservar mount-time para sistemas externos (DOM, widgets third-party, browser APIs).
Preferir renderizado condicional sobre guards dentro de effects.
`useMountEffect` falla binario y ruidoso: corrio una vez o no corrio.

### R5: Reset con key prop
NUNCA: `useEffect(() => { setForm(init) }, [userId])`
SIEMPRE: `<FormComponent key={userId} initialValues={init} />`
React remonta el componente con key diferente — sin cleanup manual.

### R6: Nunca usar refs como parches de effects
NUNCA: `const hasRun = useRef(false); useEffect(() => { if (hasRun.current) return; ... })`
Si necesitas useRef para controlar ejecucion de un effect, el effect ES el problema.

## Decision Checklist

Antes de escribir useEffect, responder secuencialmente:

1. Se puede calcular durante render? -> useMemo o inline (R1)
2. Lo dispara una accion del usuario? -> event handler (R3)
3. Es data fetching? -> TanStack Query / SWR (R2)
4. Es subscripcion a store externo? -> useSyncExternalStore
5. Resetea estado cuando cambian props? -> key prop (R5)
6. Es setup unico al montar? -> useMountEffect wrapper (R4)
7. Necesita un ref para evitar re-ejecucion? -> STOP, repensar (R6)
8. Es medicion de DOM post-render? -> callback ref

Si ninguna aplica -> useEffect puede ser apropiado (raro).

## Filosofia de fallos

useMountEffect: fallos binarios y ruidosos (corrio o no corrio).
useEffect directo: degradacion gradual y silenciosa.
Preferir fallos ruidosos — son mas faciles de diagnosticar a las 3AM.
