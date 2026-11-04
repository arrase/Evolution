# Feature Specification: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo de Decisión

**Feature Branch**: `003-ollama-perf-context`

**Created**: 2026-11-04

**Status**: Completed

**Input**: User description: "Pese a que estamos usando un modelo de decisión que es razonablemente rápido la aplicación va cada vez más lenta a medida que la simulación avanza, tenemos que hacer un análisis profundo del flujo de la aplicación y su interacción con ollama para ver cómo podemos mejorar la velocidad y contexto que el modelo tiene en cada momento para tomar decisiones. Usa el flujo de trabajo de spec-kit"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cadencia de Turno Estable y Fluida en Simulaciones Avanzadas (Priority: P1)

Como jugador y observador naturalista, quiero que el tiempo de resolución de cada turno generacional se mantenga ágil y acotado a medida que las poblaciones crecen, colonizan el mapa y alcanzan las generaciones medias y avanzadas ($G_{10}$–$G_{40}$), evitando que la proliferación descontrolada de subpoblaciones redundantes o las avalanchas de síntesis de hitos detengan el ritmo del simulador.

**Why this priority**: Es el bloqueo principal de jugabilidad actual. Aunque el motor de decisión individual es rápido en la primera generación (1–3 poblaciones), la fisión migratoria continua ante probabilidades bajas de migración y la cola de múltiples síntesis generativas en un mismo turno multiplican por $10\times$–$30\times$ la duración del turno a partir de la generación 8.

**Independent Test**: Puede probarse ejecutando cualquiera de los 3 escenarios científicos preconfigurados durante 30 generaciones continuas y verificando que (a) las poblaciones estacionarias cuya intención principal no es migrar no se fragmentan artificialmente en decenas de micro-grupos cada turno, (b) las poblaciones equivalentes dentro de un mismo estado ecológico comparten evaluación sin repetir trabajo redundante, y (c) la síntesis de hitos evolutivos o culturales se regula para no encadenar bloqueos prolongados en un único turno.

**Acceptance Scenarios**:

1. **Given** una partida en curso que supera la generación 15 con múltiples celdas colonizadas, **When** el jugador avanza un turno generacional o mantiene activo el modo de reproducción continua, **Then** el sistema evita evaluaciones redundantes entre subpoblaciones con contexto ecológico y adaptativo equivalente y resuelve el turno manteniendo una cadencia fluida.
2. **Given** una subpoblación asentada en un hábitat con recursos suficientes cuya decisión dominante no es la migración (o cuya presión migratoria es marginal), **When** se resuelve la fase demográfica del turno, **Then** la subpoblación permanece cohesionada en su celda sin escindir micro-grupos migrantes en cada generación salvo que exista una intención migratoria significativa o una evacuación de emergencia por escasez.
3. **Given** dos subpoblaciones del mismo linaje que coinciden en una celda o territorio conectado con repertorios adaptativos compatibles, **When** finaliza la fase demográfica, **Then** se consolidan en una única población cohesionada evitando la acumulación exponencial de subgrupos casi idénticos.
4. **Given** un turno en el que múltiples subpoblaciones alcanzan simultáneamente umbrales de hito evolutivo o cultural, **When** se ejecuta la fase de emergencia de hitos, **Then** el sistema sintetiza como máximo un hito prioritario por turno (posponiendo o consolidando el resto para turnos posteriores sin pérdida de progreso) para impedir pausas acumulativas de decenas de segundos.

---

### User Story 2 - Contexto Ecológico, Energético y Competitivo Rico para Decisiones Coherentes (Priority: P1)

Como observador científico, quiero que el motor de decisión de cada subpoblación reciba en cada turno un resumen claro y directamente interpretable de su situación vital —incluyendo su balance entre recursos disponibles y demanda metabólica real, la presión demográfica total en su celda (incluyendo clanes rivales cohabitantes), el estado de degradación del hábitat, su inercia adaptativa reciente y las oportunidades reales de migración hacia celdas vecinas—, para que sus probabilidades de decisión reflejen con precisión las presiones selectivas del mundo.

**Why this priority**: Actualmente el motor de decisión recibe cifras absolutas aisladas (por ejemplo, `recursos: 580` y `población: 320` sin saber que en la misma celda hay otros 2 clanes sumando 960 individuos ni cuánta energía consume realmente la población), ni conoce el impacto biofísico de cada opción o de sus propios rasgos, lo que provoca que elija estrategias genéricas (como *Cooperación* en todo momento) en lugar de responder a la abundancia, la competencia o el colapso ecológico.

**Independent Test**: Puede probarse evaluando el motor de decisión en tres situaciones contrastadas: (1) bosque abundante sin competidores (*El Rift Oeste*), (2) isla superpoblada con tres clanes rivales y herramientas de extracción (*La Isla Finita*), y (3) estepa agotada junto a un corredor costero fértil (*Archipiélago de Darwin*), verificando que la distribución de probabilidades resultante diferencia claramente el forrajeo conservador, la sobreexplotación/disputa competitiva y la migración selectiva.

**Acceptance Scenarios**:

1. **Given** una subpoblación en un hábitat abundante, estable y sin competidores cohabitantes, **When** se evalúa su decisión del turno con el contexto enriquecido, **Then** el contexto informa explícitamente del superávit calórico per cápita y la ausencia de conflicto, favoreciendo estrategias sostenibles de bajo coste metabólico (*Forrajeo Conservador*) frente a gastos defensivos innecesarios.
2. **Given** múltiples subpoblaciones cohabitando en una misma celda con alta presión demográfica agregada o tradiciones de extracción intensiva, **When** se evalúa la decisión de cada grupo, **Then** el contexto incluye la población total combinada en la celda, la ratio de escasez de recursos frente a la demanda agregada, el perfil de los grupos cohabitantes (mismo linaje vs. linajes rivales) y la salud del hábitat ($K / K_{\max}$), activando respuestas coherentes de competencia, sobreexplotación, cooperación o intercambio según sus rasgos.
3. **Given** una subpoblación con déficit energético o saturación local que dispone de celdas vecinas transitables con mayor disponibilidad de recursos por habitante, **When** se evalúa su decisión, **Then** el contexto resume las mejores alternativas vecinas transitables y su ventaja relativa de recursos, incrementando la probabilidad de *Migración Selectiva*.
4. **Given** una subpoblación que lleva varias generaciones invirtiendo en una misma vía adaptativa (asimilación de Baldwin o innovación cultural), **When** se evalúa su decisión, **Then** el contexto incorpora su decisión dominante previa y el progreso hacia el próximo hito adaptativo para mantener continuidad conductual cuando las condiciones ambientales persisten.

---

### User Story 3 - Síntesis de Hitos Evolutivos y Culturales Contextualizada y Concisa (Priority: P2)

Como jugador, quiero que cuando se dispare un hito evolutivo o cultural, el motor generativo reciba la historia causal reciente de la subpoblación (estrés ecológico sufrido, nivel de recursos y salud del hábitat, estación climática, eventos recientes y rasgos ya existentes en el mundo) con restricciones de concisión estrictas, para que genere más rápido adaptaciones únicas, no repetitivas y narrativamente conectadas con lo ocurrido en el mapa.

**Why this priority**: Las llamadas actuales de síntesis generativa tardan entre 10 y 16 segundos (rozando el límite de tiempo de espera) y carecen de contexto sobre si el hito nació de una crisis de recursos, una colonización insular o una simbiosis, pudiendo además repetir nombres de rasgos ya creados por poblaciones hermanas.

**Independent Test**: Puede probarse provocando un hito de asimilación biológica o innovación cultural tras una crisis ecológica o migración, y verificando que (a) la síntesis se completa dentro de un presupuesto de respuesta ágil sin agotar el tiempo de espera, (b) el rasgo propuesto no duplica nombres ya presentes en el catálogo activo, y (c) la crónica generada refleja las condiciones reales de escasez, abundancia o aislamiento del hábitat.

**Acceptance Scenarios**:

1. **Given** que una subpoblación alcanza un umbral de hito evolutivo o cultural, **When** se solicita la síntesis del nuevo rasgo y su crónica, **Then** el contexto proporcionado incluye el estado energético de la población, la salud ecológica y recursos de la celda, los eventos recientes de su linaje y la lista de rasgos emergentes ya existentes en el mundo para evitar duplicados.
2. **Given** la solicitud de síntesis de un hito, **When** el motor generativo redacta la propuesta, **Then** produce descripciones y crónicas concisas y acotadas que reducen significativamente el tiempo de generación sin superar el umbral de espera del turno.

### Edge Cases

- **Equivalencia de Contexto entre Subpoblaciones (Reutilización de Evaluación dentro del Turno):** Si en un mismo turno dos o más subpoblaciones comparten el mismo bioma, nivel equivalente de presión energética/ecológica, mismos rasgos activos y misma configuración de vecindario/cohabitación, el sistema reutiliza la distribución de probabilidades evaluada en ese turno en lugar de emitir llamadas duplicadas al motor de decisión.
- **Límite de Contexto del Modelo de Decisión ante Acumulación de Rasgos:** A medida que una subpoblación acumula múltiples rasgos biológicos y culturales, la representación enviada al motor de decisión debe mantenerse compacta (transmitiendo las afinidades clave y modificadores biofísicos resumidos en lugar de párrafos redundantes o identificadores técnicos internos) para no degradar la latencia ni superar jamás la ventana de contexto del modelo.
- **Prevención de Fragmentación Migratoria Crónica y Cola de Hitos:** Una subpoblación solo debe escindir un grupo migrante cuando la probabilidad asignada a migrar sea sustancial ($\ge 0.20$) o sea la decisión dominante del grupo (o exista emergencia por agotamiento de recursos locales $< 20\%$ de la demanda), evitando que probabilidades residuales de migración ($5\%$–$15\%$) en poblaciones grandes generen nuevas subpoblaciones en cada turno. Asimismo, si una subpoblación ya alcanzó el máximo de rasgos emergentes de una categoría o su linaje acaba de experimentar ese mismo tipo de hito, no debe disparar llamadas generativas innecesarias.
- **Persistencia Ligera sin Bloqueo de Interfaz:** El guardado automático del estado del mundo tras cada turno no debe re-ejecutar validaciones profundas redundantes ni formateos costosos que penalicen el hilo principal a medida que crece el historial de crónicas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (Compactación Estructurada y Semántica del Contexto de Decisión)**: Para cada evaluación de turno, el sistema MUST construir un estado de entrada compacto y de alta señal semántica que elimine identificadores internos irrelevantes y textos redundantes, e incluya explícitamente indicadores interpretables: ratio de cobertura energética (`recursos de la celda / demanda estimada de las poblaciones presentes`), estado vital actual del grupo (`prosperando`, `estable`, `en dificultades`, `en hambruna`), salud ecológica del hábitat ($K / K_{\max}$), presión de cohabitación (población total en la celda y presencia de linajes rivales o afines), inercia conductual (última decisión dominante y progreso hacia hitos) y resumen comparativo de las celdas vecinas transitables ordenadas por oportunidad de recursos per cápita.
- **FR-002 (Visibilidad de Efectos Biofísicos en Rasgos y Decisiones)**: La información de rasgos activos y decisiones elegibles enviada al motor de decisión MUST incluir de forma concisa sus efectos biofísicos clave (coste metabólico, eficiencia de extracción, impacto ecológico, movilidad y cohesión social) junto con sus condiciones de afinidad, permitiendo al modelo distinguir el coste/beneficio real de cada decisión según el estado del hábitat.
- **FR-003 (Deduplicación y Agrupación de Evaluaciones Equivalentes por Turno)**: Durante la Fase Cognitiva de un turno generacional, el sistema MUST identificar subpoblaciones que presenten una firma de estado ecológico, demográfico y adaptativo equivalente dentro de ese turno y reutilizar el resultado de evaluación probabilística, reduciendo el número total de consultas al motor de decisión sin alterar el determinismo ni la sensibilidad contextual.
- **FR-004 (Umbral de Fisión Migratoria Intencional y Consolidación Intra-Linaje)**: En la Fase Biofísica y Demográfica, la escisión de una nueva subpoblación migrante MUST requerir, además del mínimo viable de $\ge 10$ migrantes y $\ge 10$ residentes restantes, que exista una intención migratoria real (`probabilidad de migración >= 0.20`, que la migración sea la decisión dominante del grupo, o que la celda sufra emergencia de recursos), y MUST consolidar subpoblaciones compatibles del mismo linaje cuya divergencia de rasgos sea menor al umbral de cohesión de especie ($< 0.25$), evitando la proliferación artificial de decenas de micro-poblaciones clónicas.
- **FR-005 (Regulación de Cadencia de Hitos del Sistema 2)**: En la Fase de Hitos Evolutivos y Culturales, el sistema MUST procesar como máximo **1 síntesis generativa por turno generacional** (seleccionando el hito de mayor prioridad entre los candidatos activos y manteniendo los contadores de los demás candidatos para turnos siguientes) y MUST evitar que una misma subpoblación dispare múltiples categorías de hito en el mismo turno.
- **FR-006 (Contexto Causal Enriquecido y Concisión en Síntesis de Hitos)**: Toda solicitud de síntesis de hito evolutivo o cultural MUST incluir el balance energético reciente de la subpoblación, la salud y abundancia relativa de su celda, la estación climática, el resumen de eventos recientes de su linaje y los nombres de rasgos ya existentes en el catálogo para prohibir duplicados, acotando la longitud de respuesta generada para minimizar la latencia de inferencia.
- **FR-007 (Persistencia Rápida de Turno)**: El guardado automático en almacenamiento local al finalizar cada turno generacional MUST serializar directamente el estado producido por el motor de turno sin repetir validaciones de esquema completas reservadas para la importación/exportación de archivos externos.

### Key Entities *(include if feature involves data)*

- **EnrichedDemeDecisionContext (Contexto Cognitivo Compacto de Turno)**: Representación semántica optimizada del estado de una subpoblación para el motor de decisión, que sintetiza balance energético per cápita, presión competitiva en la celda actual, salud ecológica del hábitat, rasgos activos con sus vectores resumidos, continuidad adaptativa y mejores destinos vecinos transitables.
- **DemeEvaluationSignature (Firma de Equivalencia Cognitiva)**: Clave determinista derivada de las condiciones ecológicas discretizadas, rasgos activos, estado vital y vecindario de una subpoblación en un turno, utilizada para evitar evaluaciones duplicadas de subpoblaciones equivalentes en la misma generación.
- **CausalMilestoneContext (Contexto Causal de Hito)**: Información enriquecida suministrada al motor de síntesis generativa que vincula el disparador del hito (Baldwin, innovación o especiación) con la presión ecológica real, el historial reciente del linaje y la lista de rasgos existentes a excluir.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001 (Reducción de Tokens y Latencia por Evaluación de Decisión)**: El tamaño de entrada enviado al motor de decisión por cada evaluación de subpoblación se reduce al menos un **35%** respecto al formato bruto anterior, manteniendo el tiempo medio de evaluación individual por debajo de **120 ms** con el modelo en memoria.
- **SC-002 (Control de Proliferación y Escalabilidad en 30 Generaciones)**: En una simulación de 30 generaciones sobre cualquiera de los 3 escenarios científicos preconfigurados, el número de evaluaciones al motor de decisión por turno se mantiene acotado (reduciendo al menos un **50%** las llamadas acumuladas en generaciones avanzadas gracias al umbral de fisión migratoria intencional, la consolidación intra-linaje y la deduplicación de estados equivalentes).
- **SC-003 (Fluidez en Turnos con Hitos Evolutivos)**: Ningún turno generacional bloquea la simulación con más de **1 llamada de síntesis generativa**, y el tiempo de respuesta de cada síntesis de hito se reduce al menos un **30%** mediante acotación de longitud y contexto conciso, evitando errores por tiempo de espera agotado.
- **SC-004 (Fidelidad de Decisiones ante Presiones Ecológicas Reales)**: Evaluado con el modelo de decisión en vivo sobre los tres contextos arquetípicos (*Bosque Abundante sin Competencia*, *Isla Superpoblada con Herramientas de Extracción* y *Hábitat Agotado con Puente Terrestre Fértil*), el modelo asigna probabilidades diferenciadas y ecológicamente coherentes con la hipótesis científica de cada escenario, manteniendo el 100% de las pruebas unitarias, de contrato y de integración en verde.

## Assumptions

- Se mantiene la arquitectura cognitiva dual del simulador (un motor rápido de decisión probabilística para el turno a turno y un motor generativo para la síntesis de hitos y co-diseño), optimizando el flujo de orquestación, la estructura del contexto y la dinámica demográfica sin requerir hardware adicional.
- La validación exhaustiva de estructura de datos se mantiene íntegra en la carga inicial, en la importación/exportación manual de partidas y en las propuestas del motor generativo, mientras que las transiciones internas del motor determinista ya garantizan invariantes estructurales válidas.
