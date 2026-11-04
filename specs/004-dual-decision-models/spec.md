# Feature Specification: Arquitectura Cognitiva Dual de Decisión por Población y Síntesis Ligera en VRAM

**Feature Branch**: `004-dual-decision-models`

**Created**: 2026-11-04

**Status**: Completed

**Input**: User description: "Vamos a usar tev1:4b como segundo modelo de decisión y gemma4:e2b como LLM, descarga los modelos que no estén ya descargados y comprueba si así caben los 3 en la vram. Quiero que usemos el flujo de spec-kit para implementar estos cambios"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gestión Cognitiva de Poblaciones con Dos Modelos de Decisión Distintos (Priority: P1)

Como jugador y observador científico, quiero que las distintas subpoblaciones (*demes*) del mundo sean gobernadas de forma determinista por dos modelos de decisión diferenciados (un modelo primario y un segundo modelo de decisión alternativo) que evalúan concurrentemente las firmas de estado únicas de cada turno, para observar asimetrías conductuales genuinas entre poblaciones sin perder fluidez de turno ni determinismo en la caché de equivalencia.

**Why this priority**: Es el núcleo funcional solicitado: permitir que cada población sea gestionada por uno de los dos modelos de decisión en paralelo sobre las firmas únicas del turno, manteniendo a la vez la deduplicación intra-turno entre poblaciones equivalentes que comparten el mismo modelo asignado.

**Independent Test**: Puede probarse ejecutando un turno generacional en cualquiera de los escenarios científicos con múltiples poblaciones (como *El Rift y la Sabana* o *La Isla Finita*) y verificando que (a) a cada subpoblación se le asigna de forma determinista uno de los dos motores de decisión, (b) las poblaciones asignadas a motores distintos se evalúan con su respectivo modelo sin mezclar cachés entre modelos diferentes, y (c) las evaluaciones únicas de un mismo turno se despachan concurrentemente e informan en la justificación qué motor tomó la decisión.

**Acceptance Scenarios**:

1. **Given** un escenario con dos o más subpoblaciones activas (por ejemplo, las poblaciones occidental y oriental del Rift o los clanes de la Isla Finita), **When** se resuelve la fase cognitiva del turno generacional, **Then** el sistema asigna determinísticamente cada subpoblación a uno de los dos modelos de decisión configurados (`d3:4b` o `tev1:4b`) y ejecuta la evaluación con el modelo correspondiente.
2. **Given** dos subpoblaciones que comparten un contexto ecológico equivalente en el mismo turno pero están asignadas a modelos de decisión distintos, **When** se calcula la firma de equivalencia del turno, **Then** el sistema incluye la identidad del modelo asignado en la firma para evaluar cada modelo por separado, reutilizando la caché únicamente entre subpoblaciones equivalentes gobernadas por el mismo modelo.
3. **Given** múltiples firmas de evaluación únicas pendientes en un mismo turno generacional, **When** el motor de turno solicita las distribuciones de probabilidad, **Then** las solicitudes únicas se despachan de forma concurrente y la justificación contextual resultante identifica el modelo que gobernó la decisión de esa población.

---

### User Story 2 - Síntesis Generativa Ligera para Coexistencia de los Tres Modelos en Memoria de Vídeo (Priority: P1)

Como jugador con una tarjeta gráfica local de 16 GB de memoria de vídeo, quiero que el motor generativo encargado de sintetizar los hitos evolutivos, las crónicas naturalistas y el co-diseño de catálogo utilice el modelo compacto `gemma4:e2b`, para que los tres modelos activos (los dos motores de decisión y el motor generativo) residan simultáneamente al 100% en memoria de vídeo sin intercambios de disco ni bloqueos prolongados.

**Why this priority**: Sin sustituir el modelo generativo pesado anterior por la variante compacta `gemma4:e2b`, los tres modelos superarían los 16 GB de memoria gráfica disponible, provocando descargas constantes a memoria del sistema y pausas de varios segundos en cada turno.

**Independent Test**: Puede probarse ejecutando la síntesis de un hito evolutivo o el asistente de co-diseño de catálogo y comprobando que utiliza `gemma4:e2b` por defecto, mantiene el cumplimiento del esquema estructurado y el equilibrio termodinámico en los 8 idiomas soportados, y permite que los 3 modelos permanezcan residentes al 100% en la GPU (`~15.0 GB` sobre `16.3 GB`).

**Acceptance Scenarios**:

1. **Given** que una subpoblación alcanza un umbral de hito evolutivo o cultural (o el usuario solicita co-diseñar un elemento en el laboratorio), **When** se invoca al motor generativo de Sistema 2, **Then** el sistema utiliza `gemma4:e2b` como modelo por defecto y devuelve una propuesta válida, localizada y termodinámicamente equilibrada en menos de 3 segundos en caliente.
2. **Given** una sesión activa del simulador donde se alternan evaluaciones de decisión de ambos motores de Sistema 1 (`d3:4b` y `tev1:4b`) y síntesis de hitos de Sistema 2 (`gemma4:e2b`), **When** los tres modelos se cargan con retención en memoria, **Then** los tres caben simultáneamente en una GPU de 16 GB sin expulsarse mutuamente.

---

### User Story 3 - Diagnóstico y Verificación de Disponibilidad de los Tres Modelos (Priority: P2)

Como usuario del simulador, quiero que el panel de diagnóstico e inspección de conexión compruebe e informe del estado de disponibilidad de los tres modelos requeridos (`d3:4b`, `tev1:4b` y `gemma4:e2b`) y muestre los comandos exactos para descargarlos si falta alguno, para poder diagnosticar y preparar el entorno local sin confusiones.

**Why this priority**: Si falta cualquiera de los dos modelos de decisión o el modelo generativo ligero, el usuario necesita visibilidad inmediata en la interfaz de diagnóstico y los comandos exactos de instalación.

**Independent Test**: Puede probarse abriendo el modal de diagnóstico de conexión o consultando el informe de estado cuando falta alguno de los tres modelos y verificando que reporta individualmente el estado de ambos modelos de decisión y del modelo generativo junto con los comandos `ollama pull` correspondientes.

**Acceptance Scenarios**:

1. **Given** el servicio local de modelos en ejecución, **When** la aplicación verifica el estado de disponibilidad al iniciar o desde el modal de diagnóstico, **Then** comprueba la presencia de `d3:4b`, `tev1:4b` y `gemma4:e2b`, marcando el sistema como listo únicamente cuando los tres modelos están disponibles.
2. **Given** que alguno de los tres modelos no está instalado o el servidor local no responde, **When** se consulta el estado o se abre la ventana de diagnóstico, **Then** se muestran los comandos de descarga para `d3:4b`, `tev1:4b` y `gemma4:e2b` y el estado desglosado de cada modelo.

### Edge Cases

- **Herencia y Reparto Determinista de Modelo en Fisión Migratoria y Especiación:** Cuando una subpoblación se divide por migración o sufre especiación alopátrica, la asignación de modelo de decisión sigue siendo 100% determinista a partir de su identificador o configuración, garantizando que en escenarios que parten de una única población fundadora (*Archipiélago de Darwin*) las poblaciones hijas colonizadoras también se repartan entre ambos modelos de decisión.
- **Compatibilidad con Evaluaciones sin Modelo Explícito:** Si una prueba unitaria o llamada directa invoca la evaluación o el cálculo de firma sin especificar un modelo de decisión en los datos de la población, el sistema utiliza de forma predecible el modelo de decisión primario (`d3:4b`) sin romper los contratos existentes.
- **Acotación de Ventana de Contexto en el Segundo Modelo de Decisión:** Para evitar que el segundo modelo de decisión (`tev1:4b`, cuya ventana por defecto es `8192`) reserve memoria extra innecesaria que desplace capas a la CPU cuando `gemma4:e2b` ya está cargado, las llamadas de decisión mantienen el mismo presupuesto compacto de contexto en los tres modelos.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (Asignación Determinista de Modelo de Decisión por Población)**: El sistema MUST asignar de forma determinista a cada subpoblación (*deme*) uno de los dos modelos de decisión de Sistema 1 (`d3:4b` como modelo primario y `tev1:4b` como modelo secundario), garantizando que en escenarios con múltiples poblaciones iniciales o derivadas coexistan poblaciones gobernadas por `d3:4b` y poblaciones gobernadas por `tev1:4b`.
- **FR-002 (Aislamiento de Caché Intra-Turno por Modelo y Ejecución Concurrente)**: La firma de equivalencia intra-turno (`computeDemeEvaluationSignature`) MUST incorporar el modelo de decisión asignado a la subpoblación (usando `d3:4b` por defecto cuando no se especifique) para impedir que una población gestionada por `tev1:4b` reutilice probabilidades calculadas por `d3:4b` o viceversa, y el motor de turno MUST evaluar concurrentemente las firmas únicas del turno.
- **FR-003 (Trazabilidad del Modelo de Decisión en la Justificación)**: La justificación contextual generada para cada subpoblación tras su evaluación MUST incluir la referencia al modelo de decisión (`d3:4b` o `tev1:4b`) cuando haya sido asignado explícitamente en el turno, permitiendo distinguir en el inspector qué modelo gobierna a cada población.
- **FR-004 (Adopción de `gemma4:e2b` como Motor Generativo de Sistema 2)**: El motor de Sistema 2 para síntesis de hitos evolutivos/culturales y co-diseño de catálogo MUST utilizar `gemma4:e2b` como modelo por defecto en lugar de `gemma4:e4b-it-qat`, manteniendo la generación estructurada validada y el equilibrio termodinámico.
- **FR-005 (Verificación de Estado y Diagnóstico para los Tres Modelos)**: El proveedor cognitivo en vivo y el modal de diagnóstico MUST verificar la instalación de los tres modelos (`d3:4b`, `tev1:4b` y `gemma4:e2b`), exponer sus etiquetas resueltas y estado de disponibilidad en el informe de estado, y listar los comandos `ollama pull d3:4b`, `ollama pull tev1:4b` y `ollama pull gemma4:e2b` cuando falten.

### Key Entities *(include if feature involves data)*

- **DemeDecisionModelAssignment (Asignación de Modelo de Decisión por Población)**: Regla determinista y atributo opcional de contexto (`decisionModelTag`) que vincula cada subpoblación con su motor de decisión asignado (`d3:4b` o `tev1:4b`).
- **TriModelStatusReport (Informe de Estado de Tres Modelos)**: Extensión del estado de diagnóstico (`OllamaStatusReport`) que refleja la disponibilidad conjunta e individual del modelo de decisión primario (`d3:4b`), del modelo de decisión secundario (`tev1:4b`) y del modelo generativo (`gemma4:e2b`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001 (Coexistencia 100% en VRAM de 16 GB)**: Los tres modelos (`d3:4b`, `tev1:4b` y `gemma4:e2b`) permanecen cargados simultáneamente al **100% en GPU** dentro de un presupuesto total de memoria de vídeo inferior a **15.5 GB** (dejando margen libre en una tarjeta de 16 GB sin intercambio a disco ni CPU).
- **SC-002 (Latencia de Evaluación Dual y Síntesis Ligera)**: Cada evaluación individual en caliente de cualquiera de los dos modelos de decisión (`d3:4b` o `tev1:4b`) se completa en menos de **100 ms**, y la síntesis generativa en caliente con `gemma4:e2b` se completa en menos de **3.0 segundos**.
- **SC-003 (Reparto Efectivo entre Poblaciones y Cero Regresiones)**: En cualquiera de los escenarios con múltiples poblaciones, ambos modelos de decisión (`d3:4b` y `tev1:4b`) participan activamente gestionando sus respectivas poblaciones asignadas sin colisiones de caché entre modelos distintos, manteniendo el **100%** de las pruebas unitarias, de contrato y de integración en verde.

## Assumptions

- El entorno local dispone de Ollama actualizado con soporte para la capacidad `decision` (`systemone`) tanto en `d3:4b` como en `tev1:4b`, y soporte de salida estructurada JSON en `gemma4:e2b`.
- El reparto determinista de modelos por población no requiere que el usuario configure manualmente qué modelo usa cada nuevo grupo que nace por migración, sino que se deriva automáticamente de forma reproducible.
