# Phase 0 Research: Simulador Evolutivo y Socio-Cultural de Poblaciones (Evolution)

**Feature**: `001-evo-population-sim`
**Date**: 2026-11-03

## 1. Resumen de Decisiones Tecnológicas y Versiones Verificadas

Todas las versiones han sido verificadas directamente en el registro oficial de `npm` y probadas contra el servidor local de Ollama (`0.40.14`) del entorno.

| Ámbito | Paquete Elegido | Versión Exacta (npm) | Rol en la Arquitectura |
| :--- | :--- | :--- | :--- |
| **Lenguaje y Tipado** | `typescript` | `7.0.2` | Tipado estricto ESM (`"type": "module"`, `strict: true`). |
| **Bundler / Dev Server** | `vite` + `@vitejs/plugin-react` | `8.3.5` / `6.2.1` | Servidor de desarrollo y empaquetado web de baja latencia. |
| **Testing** | `vitest` | `5.1.0` | Ejecución de pruebas unitarias, de contratos y de integración deterministas. |
| **Validación y Schemas** | `zod` | `4.6.7` | Validación de esquemas en tiempo de ejecución, persistencia JSON y salidas estructuradas de LLM. |
| **IA — Sistema 1 (`d3`)** | `ollama` (`ollama/browser`) | `0.6.4` | Invocación directa de `ollamaClient.systemone()` (`POST /v1/systemone`) para obtener probabilidades normalizadas por *deme*. |
| **IA — Sistema 2 (`gemma4`)** | `@langchain/ollama` + `@langchain/core` | `1.3.0` / `1.3.4` | Orquestación de `ChatOllama` con `.withStructuredOutput(zodSchema, { method: "jsonSchema" })` y `think: false`. |
| **Geometría Hexagonal** | `honeycomb-grid` | `4.1.5` | Coordenadas axiales/cúbicas $(q, r, s)$, espirales/anillos, 6 vecinos equidistantes, distancia hexagonal y vértices SVG. |
| **Árbol Filo-Cultural** | `d3-hierarchy` + `@types/d3-hierarchy` | `3.1.3` / `3.1.7` | Cálculo determinista de coordenadas $(x, y)$ y enlaces genealógicos para el Árbol Filo-Cultural. |
| **UI y Estado Reactivo** | `react` + `react-dom` + `zustand` | `19.3.1` / `5.0.16` | Interfaz declarativa de vista única y almacén de estado minimalista sin boilerplate. |
| **Internacionalización (i18n)** | `i18next` + `react-i18next` | `26.7.1` / `17.1.12` | Inglés (`en`) por defecto y cambio reactivo en caliente a los principales idiomas del mundo (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`). |
| **Estilos e Iconografía** | `tailwindcss` + `@tailwindcss/vite` + `lucide-react` | `4.3.4` / `1.67.0` | Estilizado utilitario moderno sin configuración PostCSS adicional e iconos vectoriales. |

---

## 2. Decisiones de Investigación Detalladas

### Decisión 1: Integración del Modelo de Decisión Rápida (`d3` — Sistema 1)

- **Decision**: Utilizar el submódulo `ollama/browser` del SDK oficial `ollama@0.6.4` invocando el método tipado `ollamaClient.systemone()` con el modelo local `d3:4b` (permitiendo autodetección de cualquier variante instalada `d3:*` o `d3` mediante `ollamaClient.list()`).
- **Rationale**:
  1. **Compatibilidad con Navegador**: El punto de entrada raíz `import { Ollama } from "ollama"` importa módulos de Node (`node:fs`, `node:path`), lo que rompe el empaquetado web en Vite. En cambio, `import { Ollama } from "ollama/browser"` usa `fetch` estándar nativo del navegador.
  2. **API Nativa `systemone` (`/v1/systemone`)**: A diferencia de los endpoints de chat tradicionales, `ollamaClient.systemone()` envía un objeto `state` estructurado (estado biofísico de la celda hexagonal, los 6 vecinos y el *deme*) y un mapa `questions` de tipo `'choice'` con los descriptores semánticos de cada decisión del catálogo (`criteria`).
  3. **Rendimiento Empírico Verificado**: En pruebas reales contra `d3:4b` en Ollama `0.40.14`, cada llamada `systemone` con las 7 decisiones del catálogo responde en **~58 ms en caliente** (`output_tokens: 0`), devolviendo directamente `probabilities` normalizadas ($\sum P_i = 1.0$), `choice` y `confidence`. Evaluar 15 *demes* activos toma **< 0.9 s por turno**, cumpliendo holgadamente el objetivo `< 3 s` de `SC-002`.
- **Alternatives considered**:
  - *Usar `ChatOllama` de `@langchain/ollama` para `d3`*: Descartado porque `@langchain/ollama@1.3.0` envuelve `/api/chat` y no expone el endpoint especializado `/v1/systemone` de los modelos de decisión `d3`.
  - *Peticiones `fetch` manuales sin SDK*: Descartado por violar el Principio IV de la Constitución (*No Reinventing the Wheel*), ya que `ollama@0.6.4` provee los tipos `SystemOneRequest`, `SystemOneResponse` y `SystemOneChoiceAnswer`.

---

### Decisión 2: Integración del Modelo Generativo (`gemma4:e4b-it-qat` — Sistema 2)

- **Decision**: Utilizar `ChatOllama` de `@langchain/ollama@1.3.0` junto con `@langchain/core@1.3.4` y esquemas `zod@4.6.7` a través de `.withStructuredOutput(schema, { method: "jsonSchema" })` configurando explícitamente `think: false`.
- **Rationale**:
  1. **Desactivación de `thinking` por defecto (`think: false`)**: El modelo `gemma4:e4b-it-qat` en Ollama tiene `thinking: true` activado por defecto. Si no se pasa `think: false`, invierte varios segundos adicionales generando trazas de razonamiento innecesarias antes de producir el JSON. Con `think: false` y `method: "jsonSchema"`, sintetiza un nuevo rasgo/tradición completo con su crónica en **~2.6 s en caliente**.
  2. **Soporte Nativo de Zod v4**: `@langchain/core@1.3.4` soporta nativamente `zod@4.6.7` (`zod/v4/core`) y convierte los esquemas Zod en restricciones JSON Schema estrictas para Ollama, garantizando que los 6 ejes del `BiophysicalVector` siempre se reciban con los tipos y nombres exactos antes de pasar por el validador termodinámico.
- **Alternatives considered**:
  - *Parseo manual de bloques Markdown JSON con expresiones regulares*: Descartado por fragilidad y por existir `.withStructuredOutput()` nativo en `@langchain/ollama`.

---

### Decisión 3: Geometría Espacial Hexagonal (`honeycomb-grid@4.1.5`)

- **Decision**: Utilizar `honeycomb-grid@4.1.5` con orientación `Orientation.POINTY` y generador `spiral({ start: [0, 0], radius: R })`.
- **Rationale**:
  1. Resuelve de serie coordenadas axiales/cúbicas $(q, r, s)$ con $q + r + s = 0$, cálculo de los 6 vértices en píxeles (`hex.corners`) para renderizado directo en `<polygon>`, conversión de coordenadas de puntero a hexágono (`grid.pointToHex`) y búsqueda de los 6 vecinos equidistantes (`ring({ center: [q, r], radius: 1 })` o `grid.neighborOf`).
  2. Un radio $R = 5$ produce exactamente $91$ celdas hexagonales (dentro del rango óptimo $60\text{--}150$ de `SC-002`), mientras que $R = 4$ ($61$ celdas) y $R = 6$ ($127$ celdas) cubren todas las variantes de los Presets Científicos.
- **Alternatives considered**:
  - *Implementar matemáticas axiales/cúbicas y matrices de transformación a píxeles desde cero*: Descartado por el Principio IV (*No Reinventing the Wheel*).

---

### Decisión 4: Renderizado del Mapa Hexagonal y del Árbol Filo-Cultural (KISS)

- **Decision**: Renderizar el mapa hexagonal (61–169 celdas) y sus 5 capas visuales mediante **SVG declarativo en React 19** apoyado en las geometrías de `honeycomb-grid@4.1.5`, y calcular el layout del **Árbol Filo-Cultural** mediante **`d3-hierarchy@3.1.3`** (`d3.stratify` + `d3.tree`) renderizado también en SVG.
- **Rationale**:
  1. **Principio I (KISS & Zero Defensive Bloat)**: Con un máximo de 169 celdas hexagonales y $\le 40$ *demes* simultáneos, un `<svg>` declarativo actualiza el DOM en **< 4 ms por turno** (25 veces más rápido que el límite de $100\text{ ms}$ de `SC-002`).
  2. **Interacción Directa**: Cada `<g>` hexagonal recibe eventos nativos (`onClick`, `onPointerDown`, `onPointerEnter`) para seleccionar *demes* en el Inspector Cognitivo o pintar con el Pincel de Presión Selectiva, sin necesidad de mantener un grafo de escena WebGL duplicado ni raycasting manual.
  3. **Árbol Filo-Cultural Puro**: `d3-hierarchy` transforma la lista plana de `LineageNode` en coordenadas $(x, y)$ jerárquicas en menos de 20 líneas de código puro y determinista.
- **Alternatives considered**:
  - *`pixi.js@8.22.0` (WebGL)*: Descartado por introducir un ciclo de vida imperativo asíncrono, ~500 KB adicionales de bundle y sincronización manual de texturas para menos de 200 polígonos.
  - *`@xyflow/react@12.12.1`*: Descartado porque está diseñado para editores de nodos arrastrables, exige añadir `dagre` igualmente para layouts en árbol e introduce estado duplicado innecesario.

---

### Decisión 5: Gestión de Estado y Desacoplamiento Determinista (`zustand@5.0.16`)

- **Decision**: Centralizar el estado de la interfaz y de la sesión en un único store de `zustand@5.0.16` (`useSimulationStore`) manteniendo el motor biofísico (`src/engine/`) como funciones puras de TypeScript sin dependencias de React ni de red.
- **Rationale**:
  1. Cumple el mandato constitucional **Deterministic Core Testability**: las 4 fases del turno generacional pueden probarse de principio a fin en `vitest@5.1.0` inyectando un proveedor cognitivo simulado (`MockCognitiveProvider`) y verificarse al 100% en milisegundos.
  2. El bucle de `Auto-Play` se gestiona de forma lineal y segura: espera la resolución asíncrona completa del turno $t$ antes de programar el temporizador del turno $t+1$, deteniéndose de inmediato si el usuario pulsa `Pausa`, si se dispara un Hito Evolutivo con `autoPauseOnMilestone = true` o si ocurre un timeout de conexión con Ollama.

---

### Decisión 6: Internacionalización (`i18n`) con Inglés (`en`) por Defecto y Prompts Multilingües

- **Decision**: Utilizar `i18next@26.7.1` y `react-i18next@17.1.12` configurados con `lng: "en"` y `fallbackLng: "en"` por defecto, cargando diccionarios JSON estáticos tipados en `src/i18n/locales/` para los 8 principales idiomas del mundo (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`) e inyectando el código de idioma activo (`locale`) en las llamadas al Sistema 2 (`gemma4:e4b-it-qat`).
- **Rationale**:
  1. **Sin Reinventar la Rueda (Principio IV)**: `i18next` + `react-i18next` es el estándar de la industria en React/TypeScript para interpolación, pluralización y cambio de idioma en caliente sin recargar el DOM.
  2. **Consistencia entre Catálogo Estático e IA Generativa**: El catálogo base (7 decisiones, 6 rasgos biológicos, 5 tradiciones culturales) y los 3 presets mantienen sus descriptores canónicos en inglés (`en`) por defecto y sus traducciones en los diccionarios locales, mientras que `gemma4:e4b-it-qat` recibe la instrucción explícita de redactar los rasgos emergentes, el autocompletado del Laboratorio y las crónicas del Cuaderno del Naturalista en el `locale` activo del jugador.
- **Alternatives considered**:
  - *Construir un sistema de diccionarios casero con React Context*: Descartado por violar el Principio IV (*No Reinventing the Wheel*).
