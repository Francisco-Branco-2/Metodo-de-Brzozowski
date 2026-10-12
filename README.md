# Brzozowski's Algorithm — Finite Automata Minimization

[![OCaml](https://img.shields.io/badge/Language-OCaml-orange.svg)](https://ocaml.org/)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Yojson](https://img.shields.io/badge/Dependency-Yojson-blue.svg)](https://github.com/ocaml-community/yojson)
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()

An implementation in **OCaml** of **Brzozowski's minimization algorithm** for finite automata. Given any finite automaton (deterministic or non-deterministic) encoded in JSON, the program computes the unique **minimal and complete Deterministic Finite Automaton (DFA)** that accepts the exact same formal language.

---

## Table of Contents

- [Overview](#overview)
- [Theoretical Foundation](#theoretical-foundation)
  - [Why Brzozowski's Method Works](#why-brzozowskis-method-works)
  - [Comparison with Partition Refinement](#comparison-with-partition-refinement)
- [Algorithm Pipeline](#algorithm-pipeline)
- [Step-by-Step Walkthrough ($M_1$)](#step-by-step-walkthrough-m_1)
- [Automaton JSON Specification](#automaton-json-specification)
- [Project Structure](#project-structure)
- [Requirements & Installation](#requirements--installation)
- [Compilation & Execution](#compilation--execution)
- [Test Suite](#test-suite)
- [Implementation Details](#implementation-details)

---

## Overview

Minimizing a finite automaton consists of finding an equivalent deterministic automaton with the smallest possible number of states. While textbook approaches often rely on equivalence relation refinement (such as Moore's $O(|\Sigma| \cdot |Q|^2)$ or Hopcroft's $O(|\Sigma| \cdot |Q| \log |Q|)$ algorithms), **Janusz Brzozowski (1962)** discovered an elegant algebraic method based solely on **language reversal** and **determinization (subset construction)**:

$$\mathcal{A}_{\min} = \operatorname{det}(\operatorname{rev}(\operatorname{det}(\operatorname{rev}(\mathcal{A}))))$$

This project provides an efficient functional implementation in OCaml, reading input automata from standard input (`stdin`) and emitting the resulting minimal DFA to standard output (`stdout`) in JSON.

---

## Theoretical Foundation

### Why Brzozowski's Method Works

Let $L$ be a regular language and $\mathcal{A}$ any finite automaton recognizing $L$:

1. **Reversal ($\operatorname{rev}$)**: Inverts all transition transitions $(p \xrightarrow{a} q \implies q \xrightarrow{a} p)$ and swaps initial and final states. The resulting automaton accepts the reversed language $L^R = \{w^R \mid w \in L\}$.
2. **First Determinization ($\operatorname{det}$)**: Converts the reversed NFA into a DFA ($D_1$) using the subset (powerset) construction restricted to reachable states via Breadth-First Search (BFS). $D_1$ is a DFA accepting $L^R$ with **only reachable states**.
3. **Second Reversal ($\operatorname{rev}$)**: Reverses $D_1$. Because $(L^R)^R = L$, this NFA once again accepts the original language $L$.
4. **Second Determinization ($\operatorname{det}$)**: By **Brzozowski's Theorem**, if $D$ is a DFA with only reachable states, then $\operatorname{det}(\operatorname{rev}(D))$ yields the **unique minimal DFA** for the reversed language of $D$. Applying this to $D_1$ directly produces the minimal DFA for $L$.

> **Key Intuition**: During the second determinization, each subset state corresponds to the set of states in $D_1$ from which a word can still be accepted. Two states that accept identical suffixes naturally produce the same subset and are therefore merged into a single state, directly factoring out the Myhill-Nerode equivalence classes.

### Comparison with Partition Refinement

| Aspect | Brzozowski's Method | Moore / Hopcroft |
| :--- | :--- | :--- |
| **Input Type** | Accepts any NFA, DFA, or partial automaton directly | Requires an initial complete DFA |
| **Core Operation** | Dual subset construction + reversal | State equivalence partition refinement |
| **Worst-Case Complexity** | $O(2^n)$ (subset construction worst-case) | $O(|\Sigma| n^2)$ (Moore) / $O(|\Sigma| n \log n)$ (Hopcroft) |
| **Practical Performance** | Exceptionally fast for most practical automata; very concise implementation | Requires complex data structures for Hopcroft's bound |

---

## Algorithm Pipeline

The program executes a 7-step pipeline on every input automaton:

```
stdin ──▶ [1. ler_automato] ──▶ automato
      ──▶ [2. inverter]     ──▶ automato (reversed NFA)
      ──▶ [3. determinizar] ──▶ automato (reachable DFA D1)
      ──▶ [4. inverter]     ──▶ automato (reversed NFA D1^R)
      ──▶ [5. determinizar] ──▶ automato (minimal DFA)
      ──▶ [6. completar]    ──▶ automato (minimal complete DFA)
      ──▶ [7. para_json]    ──▶ stdout (JSON)
```

1. **`ler_automato`**: Parses JSON into the internal `automato` record. Deduplicates and sorts state lists to enforce canonical set representations.
2. **`inverter`**: Reverses transitions and swaps start and accept states.
3. **`determinizar`**: Implements subset construction using Breadth-First Search (BFS) to explore only reachable state subsets.
4. **`inverter`**: Reverses the determinized automaton back to the original language orientation.
5. **`determinizar`**: Executes the second subset construction, producing the minimal DFA.
6. **`completar`**: Guarantees that the DFA is **complete** (i.e. every state has an outgoing transition for every symbol in $\Sigma$). If any transition is missing, it creates a designated sink/trap state ($q_{\text{trap}}$) with self-loops on all symbols.
7. **`para_json`**: Serializes the resulting automaton into compact JSON.

---

## Step-by-Step Walkthrough ($M_1$)

Consider the automaton $M_1$ from `testes/01_enunciado_M1.json`:
- **States**: $\{0, 1, 2, 3, 4\}$
- **Alphabet**: $\{a, b\}$
- **Initial State**: $0$
- **Final States**: $\{0, 2, 4\}$

### Original Transitions ($M_1$)
| State | with `a` | with `b` |
| :---: | :---: | :---: |
| **0** (initial, final) | 0 | 1 |
| **1** | 2 | 3 |
| **2** (final) | 2 | 4 |
| **3** | 2 | 3 |
| **4** (final) | 4 | 4 |

---

### Step 2: First Reversal ($\operatorname{rev}(M_1)$)
- **New Initial States**: $\{0, 2, 4\}$
- **New Final State**: $\{0\}$
- Transitions are inverted:
  - $2 \xrightarrow{a} 1, 2, 3$ (non-deterministic branching)
  - $4 \xrightarrow{b} 2, 4$

### Step 3: First Determinization ($D_1$)
Subsets discovered via BFS:
- Subset $0 = \{0, 2, 4\}$ (initial)
- Subset $1 = \{0, 1, 2, 3, 4\}$
- Subset $2 = \{2, 4\}$
- Subset $3 = \{1, 2, 3, 4\}$

Resulting DFA $D_1$ has 4 reachable states (finals: $0$ and $1$).

### Step 4: Second Reversal ($\operatorname{rev}(D_1)$)
- **New Initial States**: $\{0, 1\}$
- **New Final State**: $\{0\}$

### Step 5: Second Determinization (Minimal DFA)
Subsets discovered:
- State $0 = \{0, 1\}$ (initial)
- State $1 = \{1, 3\}$
- State $2 = \{0, 1, 2, 3\}$
- Final states: $\{0, 2\}$

States $1$ and $3$ of $M_1$ merged into state $1$; states $2$ and $4$ merged into state $2$.

### Step 6: Completion
Alphabet size is $2$, number of states is $3$. Expected transitions: $3 \times 2 = 6$. Since all 6 transitions exist, no trap state is required.

### Final Minimal DFA Output
```json
[[0,1,2],["a","b"],[[[0,"a"],0],[[0,"b"],1],[[1,"a"],2],[[1,"b"],1],[[2,"a"],2],[[2,"b"],2]],[0],[0,2]]
```

---

## Automaton JSON Specification

An automaton is encoded as a 5-element JSON array:

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

Where:
1. `states`: List of integer state identifiers (e.g., `[0, 1, 2]`).
2. `alphabet`: List of string symbols (e.g., `["a", "b"]`).
3. `transitions`: List of directed edges formatted as `[[origin, symbol], destination]`.
4. `initial_states`: List of initial states (e.g., `[0]`).
5. `final_states`: List of accepting/final states (e.g., `[0, 2]`).

---

## Project Structure

```
├── ep1_entrega.ml                            # Core algorithm implementation in OCaml
├── Makefile                                  # Build and test orchestration
├── README.md                                 # Project documentation
├── .gitignore                                # Build artifact ignore list
├── Análise do Algoritmo — Preparação...     # Detailed algorithm analysis notes (PT)
└── testes/                                   # Test suite with 19 test cases
    ├── 01_enunciado_M1.json                  # Canonical assignment automaton
    ├── 02_afd_ja_minimo.json                 # Already minimal DFA
    ├── 03_estados_equivalentes.json          # Automaton with redundant equivalent states
    ├── 04_afnd.json                          # Non-deterministic finite automaton (NFA)
    ├── 05_varios_iniciais.json               # Automaton with multiple initial states
    ├── 06_afd_parcial_armadilha.json         # Partial DFA requiring sink/trap state
    ├── 07_estados_inalcancaveis.json         # Automaton with unreachable states
    ├── 08_sem_finais.json                    # Automaton with no final states (empty language)
    ├── 09_finais_inalcancaveis.json          # Final states that cannot be reached
    ├── 10_so_palavra_vazia.json              # Language containing only the empty word
    ├── 11_todas_as_palavras.json             # Language accepting all words (Sigma*)
    ├── 12_sem_iniciais.json                  # Automaton without initial states
    ├── 13_alfabeto_vazio.json                # Automaton with empty alphabet
    ├── 14_estados_nao_consecutivos.json      # Discontinuous state IDs (e.g. 0, 10, 50)
    ├── 15_iniciais_finais_repetidos.json     # Duplicated entries in initial/final sets
    ├── 16_transicoes_duplicadas.json         # Duplicated transition entries
    ├── 17_tres_simbolos.json                 # Automaton over 3-symbol alphabet {a, b, c}
    ├── 18_par_de_as.json                     # Parity language (even number of 'a's)
    └── 19_json_multilinha.json               # Multiline-formatted JSON input
```

---

## Requirements & Installation

- **OCaml** ($\ge 4.12$)
- **findlib** (`ocamlfind`)
- **Yojson** ($\ge 2.0$)

Install dependencies via [OPAM](https://opam.ocaml.org/):

```bash
opam install yojson ocamlfind
```

---

## Compilation & Execution

### Build

Compile native binary `ep1` using `make`:

```bash
make
```

Or manually:

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

Remove binary and compiled OCaml object files (`.cmi`, `.cmx`, `.o`):

```bash
make clean
```

---

## Test Suite

The project includes 19 rigorous test cases covering all edge and boundary conditions:

| File | Scenario Tested | Expected Behavior |
| :--- | :--- | :--- |
| `01_enunciado_M1.json` | Baseline exercise automaton $M_1$ (5 states) | Minimizes to 3 states |
| `02_afd_ja_minimo.json` | DFA already in minimal form | Preserves identical structure |
| `03_estados_equivalentes.json` | Automaton with duplicate equivalent branches | Merges equivalent states |
| `04_afnd.json` | General NFA with non-deterministic transitions | Converts to equivalent minimal DFA |
| `05_varios_iniciais.json` | NFA with multiple initial states | Correctly combines initial configurations |
| `06_afd_parcial_armadilha.json` | Partial DFA with missing transitions | Adds trap/sink state and complete loops |
| `07_estados_inalcancaveis.json` | Automaton with unreachable isolated states | Discards unreachable states |
| `08_sem_finais.json` | No accepting states ($L = \emptyset$) | Single non-accepting state with loops |
| `09_finais_inalcancaveis.json` | Final states disconnected from start state | Recognizes empty language, reduces to 1 state |
| `10_so_palavra_vazia.json` | Language accepting only $\{\varepsilon\}$ | 2-state minimal DFA |
| `11_todas_as_palavras.json` | Universal language $\Sigma^*$ | 1-state accepting DFA |
| `12_sem_iniciais.json` | Automaton with no initial states | Recognizes empty language |
| `13_alfabeto_vazio.json` | Empty alphabet $\Sigma = \emptyset$ | Handles degenerated alphabet cleanly |
| `14_estados_nao_consecutivos.json` | Non-consecutive state numbers | Renumbers states to $0 \dots k-1$ |
| `15_iniciais_finais_repetidos.json` | Input arrays containing duplicates | Normalizes sets with `List.sort_uniq` |
| `16_transicoes_duplicadas.json` | Redundant identical transition definitions | Deduplicates transitions cleanly |
| `17_tres_simbolos.json` | Alphabet with 3 symbols $\{a, b, c\}$ | Correctly handles larger alphabets |
| `18_par_de_as.json` | Parity automaton | Minimizes to canonical 2-state parity DFA |
| `19_json_multilinha.json` | Heavily formatted, multi-line JSON | Robustly parsed by Yojson stream reader |

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
