# Brzozowski's Algorithm — Finite Automata Minimization

An implementation in **OCaml** of **Brzozowski's minimization algorithm** for finite automata. Given any finite automaton (deterministic or non-deterministic) encoded in JSON, the program computes the unique **minimal and complete Deterministic Finite Automaton (DFA)** that accepts the exact same formal language.

---

## Table of Contents

- [Overview](#overview)
- [Theoretical Background](#theoretical-background)
  - [How Brzozowski's Method Works](#how-brzozowskis-method-works)
  - [Comparison with Partition Refinement](#comparison-with-partition-refinement)
- [Execution Pipeline](#execution-pipeline)
- [Step-by-Step Example (Automaton M1)](#step-by-step-example-automaton-m1)
  - [Input Automaton M1](#input-automaton-m1)
  - [Step 2: First Reversal](#step-2-first-reversal)
  - [Step 3: First Determinization](#step-3-first-determinization)
  - [Step 4: Second Reversal](#step-4-second-reversal)
  - [Step 5: Second Determinization](#step-5-second-determinization)
  - [Step 6: Completion](#step-6-completion)
  - [Final Output](#final-output)
- [JSON Input and Output Specification](#json-input-and-output-specification)
- [Project Structure](#project-structure)
- [Requirements and Installation](#requirements-and-installation)
- [Compilation and Execution](#compilation-and-execution)
- [Test Suite](#test-suite)
- [Implementation Details](#implementation-details)
- [License](#license)

---

## Overview

Minimizing a finite automaton consists of finding an equivalent deterministic automaton with the minimum possible number of states. While textbook algorithms typically rely on state equivalence partition refinement (such as Moore's or Hopcroft's algorithms), **Janusz Brzozowski (1962)** introduced an algebraic approach based solely on **language reversal** and **determinization (subset construction)**:

$$\mathcal{A}_{\min} = \operatorname{det}(\operatorname{rev}(\operatorname{det}(\operatorname{rev}(\mathcal{A}))))$$

This project provides a functional implementation of this algorithm in OCaml, reading an automaton from standard input (`stdin`) and writing the minimal complete DFA to standard output (`stdout`) in JSON format.

---

## Theoretical Background

### How Brzozowski's Method Works

Let $L$ be a regular language and $\mathcal{A}$ any finite automaton recognizing $L$:

1. **Reversal (`rev`)**: Every transition is reversed (from $p \xrightarrow{a} q$ to $q \xrightarrow{a} p$), and the sets of initial and final states are swapped. The resulting automaton accepts the reversed language:
   $$L^R = \{w^R \mid w \in L\}$$
2. **First Determinization (`det`)**: Converts the reversed NFA into a DFA ($D_1$) using the subset construction, exploring only reachable state subsets via Breadth-First Search (BFS). $D_1$ is a deterministic automaton accepting $L^R$ with only reachable states.
3. **Second Reversal (`rev`)**: Reversing $D_1$ yields an automaton accepting the original language again, since $(L^R)^R = L$.
4. **Second Determinization (`det`)**: By **Brzozowski's Theorem**, if $D$ is a DFA with only reachable states, then determinizing the reverse of $D$ yields the **unique minimal DFA** for the language. Determinizing $D_1^R$ directly produces the minimal DFA for $L$.

> **Intuition**: During the second determinization, each state subset corresponds to the set of states from which words can still be accepted. Two states that accept the exact same suffixes will produce the exact same subset, collapsing directly into a single state (the Myhill-Nerode equivalence classes).

### Comparison with Partition Refinement

| Aspect | Brzozowski's Method | Moore / Hopcroft |
| :--- | :--- | :--- |
| **Input Type** | Accepts any NFA, DFA, or partial automaton directly | Requires an initial complete DFA |
| **Core Operation** | Dual subset construction and reversal | Iterative partition refinement of state equivalence |
| **Worst-Case Complexity** | Exponential $O(2^n)$ in worst-case corner cases | Polynomial: $O(|\Sigma| \cdot n^2)$ (Moore) or $O(|\Sigma| \cdot n \log n)$ (Hopcroft) |
| **Practical Performance** | Fast and concise for typical automata | Requires more complex data structures |

---

## Execution Pipeline

The program executes a 7-step pipeline on every input automaton:

| Step | Function | Description |
| :---: | :--- | :--- |
| **1** | `ler_automato` | Reads JSON input from `stdin` and parses it into the internal `automato` record. Cleans and sorts state lists to enforce canonical set representations. |
| **2** | `inverter` | Reverses all transition directions and swaps initial with final states ($M^R$). |
| **3** | `determinizar` | Applies subset construction via BFS to produce a DFA with reachable states ($D_1$). |
| **4** | `inverter` | Reverses transitions again, restoring the original language orientation ($D_1^R$). |
| **5** | `determinizar` | Determinizes once more; by Brzozowski's Theorem, this DFA is guaranteed to be minimal. |
| **6** | `completar` | Checks if the transition function is total. If transitions are missing, adds a non-accepting trap/sink state with full self-loops. |
| **7** | `para_json` | Serializes the minimal complete DFA to compact JSON sent to `stdout`. |

---

## Step-by-Step Example (Automaton M1)

We trace the algorithm on the canonical exercise automaton $M_1$ (`testes/01_enunciado_M1.json`).

### Input Automaton M1

- **States**: $\{0, 1, 2, 3, 4\}$
- **Alphabet**: $\{a, b\}$
- **Initial State**: $0$
- **Final States**: $\{0, 2, 4\}$

| State | On `a` | On `b` |
| :---: | :---: | :---: |
| **0** (initial, final) | 0 | 1 |
| **1** | 2 | 3 |
| **2** (final) | 2 | 4 |
| **3** | 2 | 3 |
| **4** (final) | 4 | 4 |

---

### Step 2: First Reversal

- **New Initial States**: $\{0, 2, 4\}$
- **New Final State**: $\{0\}$
- Non-deterministic branching occurs:
  - From state $2$ with `a`: $\{1, 2, 3\}$
  - From state $4$ with `b`: $\{2, 4\}$

---

### Step 3: First Determinization

Subset construction via Breadth-First Search (BFS):

| Iteration | Processed Subset | On `a` | On `b` | New Subsets Discovered |
| :---: | :---: | :---: | :---: | :---: |
| **1** | $\{0, 2, 4\}$ (State 0) | $\{0, 1, 2, 3, 4\}$ (State 1) | $\{2, 4\}$ (State 2) | State 1, State 2 |
| **2** | $\{0, 1, 2, 3, 4\}$ (State 1) | $\{0, 1, 2, 3, 4\}$ (State 1) | $\{0, 1, 2, 3, 4\}$ (State 1) | None |
| **3** | $\{2, 4\}$ (State 2) | $\{1, 2, 3, 4\}$ (State 3) | $\{2, 4\}$ (State 2) | State 3 |
| **4** | $\{1, 2, 3, 4\}$ (State 3) | $\{1, 2, 3, 4\}$ (State 3) | $\{0, 1, 2, 3, 4\}$ (State 1) | None |

- **States of $D_1$**: $\{0, 1, 2, 3\}$
- **Final States**: $\{0, 1\}$ (subsets containing the reversed final state $0$)

---

### Step 4: Second Reversal

- **New Initial States**: $\{0, 1\}$ (the final states of $D_1$)
- **New Final State**: $\{0\}$ (the initial state of $D_1$)

---

### Step 5: Second Determinization

Applying subset construction to $D_1^R$:

| Iteration | Processed Subset | On `a` | On `b` | New Subsets Discovered |
| :---: | :---: | :---: | :---: | :---: |
| **1** | $\{0, 1\}$ (State 0) | $\{0, 1\}$ (State 0) | $\{1, 3\}$ (State 1) | State 1 |
| **2** | $\{1, 3\}$ (State 1) | $\{0, 1, 2, 3\}$ (State 2) | $\{1, 3\}$ (State 1) | State 2 |
| **3** | $\{0, 1, 2, 3\}$ (State 2) | $\{0, 1, 2, 3\}$ (State 2) | $\{0, 1, 2, 3\}$ (State 2) | None |

- **Final States**: $\{0, 2\}$ (subsets containing state $0$)
- States $1$ and $3$ of $M_1$ merged into state $1$.
- States $2$ and $4$ of $M_1$ merged into state $2$.
- The resulting DFA has **3 states** (reduced from 5).

---

### Step 6: Completion

Alphabet size is $2$, number of states is $3$. Expected total transitions: $3 \times 2 = 6$.
Since all 6 transitions exist, no trap state is required.

---

### Final Output

```json
[[0,1,2],["a","b"],[[[0,"a"],0],[[0,"b"],1],[[1,"a"],2],[[1,"b"],1],[[2,"a"],2],[[2,"b"],2]],[0],[0,2]]
```

---

## JSON Input and Output Specification

An automaton is represented as a 5-element JSON array:

```json
[
  [0, 1, 2],
  ["a", "b"],
  [
    [[0, "a"], 0],
    [[0, "b"], 1],
    [[1, "a"], 2],
    [[1, "b"], 1],
    [[2, "a"], 2],
    [[2, "b"], 2]
  ],
  [0],
  [0, 2]
]
```

### Component Breakdown

1. **`states`**: List of integer state identifiers (e.g., `[0, 1, 2]`).
2. **`alphabet`**: List of symbol strings (e.g., `["a", "b"]`).
3. **`transitions`**: List of directed transitions, formatted as `[[origin, symbol], destination]`.
4. **`initial_states`**: List of initial states (e.g., `[0]`).
5. **`final_states`**: List of accepting states (e.g., `[0, 2]`).

---

## Project Structure

```
├── ep1_entrega.ml                            # Core algorithm implementation in OCaml
├── Makefile                                  # Build and test orchestration
├── README.md                                 # Project documentation
├── .gitignore                                # Build artifact ignore list
├── docs/
│   └── ALGORITHM_ANALYSIS.md                 # Detailed algorithm defense guide (English)
├── Análise do Algoritmo — Preparação...     # Original defense notes (Portuguese)
└── testes/                                   # Test suite with 19 test cases
    ├── 01_enunciado_M1.json                  # Canonical assignment automaton
    ├── 02_afd_ja_minimo.json                 # Already minimal DFA
    ├── 03_estados_equivalentes.json          # Automaton with duplicate equivalent branches
    ├── 04_afnd.json                          # Non-deterministic finite automaton (NFA)
    ├── 05_varios_iniciais.json               # Automaton with multiple initial states
    ├── 06_afd_parcial_armadilha.json         # Partial DFA requiring sink/trap state
    ├── 07_estados_inalcancaveis.json         # Automaton with unreachable isolated states
    ├── 08_sem_finais.json                    # Automaton with no final states (empty language)
    ├── 09_finais_inalcancaveis.json          # Final states that cannot be reached
    ├── 10_so_palavra_vazia.json              # Language accepting only {ε}
    ├── 11_todas_as_palavras.json             # Universal language Σ*
    ├── 12_sem_iniciais.json                  # Automaton without initial states
    ├── 13_alfabeto_vazio.json                # Automaton with empty alphabet (Σ = ∅)
    ├── 14_estados_nao_consecutivos.json      # Discontinuous state IDs (e.g., 0, 10, 50)
    ├── 15_iniciais_finais_repetidos.json     # Input arrays containing duplicates
    ├── 16_transicoes_duplicadas.json         # Redundant identical transition definitions
    ├── 17_tres_simbolos.json                 # Automaton over 3-symbol alphabet {a, b, c}
    ├── 18_par_de_as.json                     # Parity automaton (even number of 'a's)
    └── 19_json_multilinha.json               # Multiline-formatted JSON input
```

---

## Requirements and Installation

- **OCaml** (version $\ge 4.12$)
- **findlib** (`ocamlfind`)
- **Yojson** (version $\ge 2.0$)

Install dependencies via [OPAM](https://opam.ocaml.org/):

```bash
opam install yojson ocamlfind
```

---

## Compilation and Execution

### Build

Compile the native binary `ep1` using `make`:

```bash
make
```

Or manually with `ocamlfind`:

```bash
ocamlfind ocamlopt -package yojson -linkpkg ep1_entrega.ml -o ep1
```

### Run

The program reads JSON from `stdin` and writes JSON to `stdout`:

```bash
./ep1 < testes/01_enunciado_M1.json
```

Output:

```json
[[0,1,2],["a","b"],[[[0,"a"],0],[[0,"b"],1],[[1,"a"],2],[[1,"b"],1],[[2,"a"],2],[[2,"b"],2]],[0],[0,2]]
```

### Run Test Suite

Execute all 19 test cases:

```bash
make test
```

### Clean Artifacts

Remove the binary and compiled OCaml object files (`.cmi`, `.cmx`, `.o`):

```bash
make clean
```

---

## Test Suite

The project includes 19 test cases covering edge cases and boundary conditions:

| File | Scenario Tested | Expected Behavior |
| :--- | :--- | :--- |
| `01_enunciado_M1.json` | Baseline assignment automaton $M_1$ (5 states) | Minimizes to 3 states |
| `02_afd_ja_minimo.json` | DFA already in minimal form | Preserves identical structure |
| `03_estados_equivalentes.json` | Automaton with duplicate equivalent branches | Merges equivalent states |
| `04_afnd.json` | General NFA with non-deterministic transitions | Converts to equivalent minimal DFA |
| `05_varios_iniciais.json` | NFA with multiple initial states | Combines initial configurations correctly |
| `06_afd_parcial_armadilha.json` | Partial DFA with missing transitions | Adds trap/sink state with loops |
| `07_estados_inalcancaveis.json` | Automaton with unreachable isolated states | Discards unreachable states |
| `08_sem_finais.json` | No accepting states (empty language) | Returns single non-accepting state with loops |
| `09_finais_inalcancaveis.json` | Final states disconnected from start state | Recognizes empty language, reduces to 1 state |
| `10_so_palavra_vazia.json` | Language accepting only the empty word `{ε}` | Produces 2-state minimal DFA |
| `11_todas_as_palavras.json` | Universal language `Σ*` | Produces 1-state accepting DFA |
| `12_sem_iniciais.json` | Automaton with no initial states | Recognizes empty language |
| `13_alfabeto_vazio.json` | Empty alphabet `Σ = ∅` | Handles degenerated alphabet cleanly |
| `14_estados_nao_consecutivos.json` | Non-consecutive state numbers | Renumbers states to $0 \dots k-1$ |
| `15_iniciais_finais_repetidos.json` | Input arrays containing duplicates | Normalizes sets with `List.sort_uniq` |
| `16_transicoes_duplicadas.json` | Redundant identical transition definitions | Deduplicates transitions cleanly |
| `17_tres_simbolos.json` | Alphabet with 3 symbols $\{a, b, c\}$ | Correctly handles larger alphabets |
| `18_par_de_as.json` | Parity automaton | Minimizes to canonical 2-state parity DFA |
| `19_json_multilinha.json` | Multiline formatted JSON | Correctly parsed by Yojson stream reader |

---

## Implementation Details

- **Internal Representation**:
  ```ocaml
  type automato = {
    estados  : int list;
    alfabeto : string list;
    trans    : (int * string * int) list;
    iniciais : int list;
    finais   : int list;
  }
  ```
- **Canonical Subsets**: Sets of states during subset construction are represented as sorted lists without duplicates (`List.sort_uniq compare`), ensuring constant/linear-time canonical equality checks with OCaml's structural equality operator `=`.
- **Breadth-First Exploration**: Subset construction is implemented as a queue-based BFS (`por_tratar = resto @ descobertos`), guaranteeing that only states reachable from the initial state are created and numbered.
- **Completion Guarantee**: After the second determinization, `completar` checks if $|T| = |Q| \times |\Sigma|$. If fewer transitions exist, an explicit non-accepting sink state ($|Q|$) is appended with missing transitions directed to it and full self-loops.

---

## License

This project is licensed under the MIT License.
