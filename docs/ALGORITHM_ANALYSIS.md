# Step-by-Step Algorithm Analysis: Brzozowski's Method

An in-depth mathematical and implementation breakdown of the finite automata minimization algorithm implemented in `ep1_entrega.ml`.

---

## 1. Introduction

The program accepts an automaton in JSON format via `stdin` and outputs the **minimal and complete DFA** accepting the exact same formal language. It executes a strict 7-step pipeline:

| Step | Function | Operation |
| :---: | :--- | :--- |
| **1** | `ler_automato` | Parses JSON input and constructs the internal automaton record. |
| **2** | `inverter` | Inverts transition directions and swaps initial with final states. |
| **3** | `determinizar` | Applies subset construction via BFS to yield an equivalent DFA. |
| **4** | `inverter` | Reverses the DFA transitions and swaps states once again. |
| **5** | `determinizar` | Re-determinizes the reversed automaton; yields a **minimal DFA**. |
| **6** | `completar` | Adds a trap/sink state with self-loops if transitions are missing. |
| **7** | `para_json` | Serializes the minimal complete DFA to compact JSON. |

Steps 2 through 5 constitute **Brzozowski's core minimization method**:
$$\operatorname{det}(\operatorname{rev}(\operatorname{det}(\operatorname{rev}(M))))$$

---

## 2. Running Example: Automaton $M_1$

We trace $M_1$ (`testes/01_enunciado_M1.json`) across all 7 steps:
- **States**: $\{0, 1, 2, 3, 4\}$
- **Alphabet**: $\{a, b\}$
- **Initial State**: $0$
- **Final States**: $\{0, 2, 4\}$

| State | On `a` | On `b` |
| :---: | :---: | :---: |
| **0** (init, final) | 0 | 1 |
| **1** | 2 | 3 |
| **2** (final) | 2 | 4 |
| **3** | 2 | 3 |
| **4** (final) | 4 | 4 |

---

## 3. The `Yojson` Integration

The program relies on only two core functions from `Yojson` (v2.2.2):
- `Yojson.Basic.from_channel`: Reads raw characters from `stdin` into a polymorphic variant AST (`Yojson.Basic.t`).
- `Yojson.Basic.to_string`: Emits the AST into a compact, single-line JSON string sent to `stdout`.

Custom helper converters handle the impedance match between `Yojson.Basic.t` and OCaml typed lists:
- `para_int : Yojson.Basic.t -> int`
- `para_string : Yojson.Basic.t -> string`
- `para_lista : Yojson.Basic.t -> Yojson.Basic.t list`
- `para_transicao : Yojson.Basic.t -> int * string * int`
- `ler_automato : Yojson.Basic.t -> automato`
- `para_json : automato -> Yojson.Basic.t`

---

## 4. Detailed Execution Steps

### Step 1 — Parsing (`ler_automato`)
Reads the 5-element array and normalizes `iniciais` and `finais` using `List.sort_uniq compare`.
Sorting ensures canonical representations: two sets are equal if and only if their sorted list representations are structurally equal (`=`).

### Step 2 — Reversal (`inverter`)
1. Reverses directed edges: $(o, s, d) \mapsto (d, s, o)$.
2. Swaps initial and final sets: $\text{iniciais}' = \text{finais}$, $\text{finais}' = \text{iniciais}$.

For $M_1$:
- Initial states become $\{0, 2, 4\}$.
- Final state becomes $\{0\}$.
The automaton is now non-deterministic ($M_1^R$).

### Step 3 — Determinization (`determinizar`)
Performs the subset construction using BFS:
- Initial subset: $\{0, 2, 4\} \mapsto \text{State } 0$.
- On `a`: $\{0\} \cup \{1, 2, 3\} \cup \{4\} = \{0, 1, 2, 3, 4\} \mapsto \text{State } 1$.
- On `b`: $\emptyset \cup \emptyset \cup \{2, 4\} = \{2, 4\} \mapsto \text{State } 2$.
- Exploring State $1$ $\{0, 1, 2, 3, 4\}$ on `a` and `b` self-loops to State $1$.
- Exploring State $2$ $\{2, 4\}$ on `a` leads to $\{1, 2, 3, 4\} \mapsto \text{State } 3$.
- Exploring State $3$ $\{1, 2, 3, 4\}$ on `b` loops back to State $1$.

Resulting DFA $D_1$ has 4 states, all reachable from State $0$.

### Step 4 — Second Reversal (`inverter`)
Reverses $D_1$:
- Initial states: $\{0, 1\}$ (finals of $D_1$).
- Final state: $\{0\}$ (initial of $D_1$).

### Step 5 — Second Determinization (`determinizar`)
Determinizing $D_1^R$ directly groups Myhill-Nerode equivalent states:
- Initial subset: $\{0, 1\} \mapsto \text{State } 0$.
- State $0$ on `b` $\mapsto \{1, 3\} \mapsto \text{State } 1$.
- State $1$ on `a` $\mapsto \{0, 1, 2, 3\} \mapsto \text{State } 2$.
- State $2$ on `a` $\mapsto \text{State } 2$, on `b` $\mapsto \text{State } 2$.

Final states (those containing $0$): $\{0, 2\}$.
Total minimal states: $3$.

### Step 6 — Completion (`completar`)
Verifies that $|T| = |Q| \times |\Sigma|$. For $M_1$, $3 \times 2 = 6$ transitions are present, so the automaton is already complete. If transitions are missing in partial automata (e.g. `testes/06_afd_parcial_armadilha.json`), an explicit non-accepting trap state is added with transitions for all remaining symbols.

### Step 7 — Output (`para_json`)
Serializes back to JSON:
```json
[[0,1,2],["a","b"],[[[0,"a"],0],[[0,"b"],1],[[1,"a"],2],[[1,"b"],1],[[2,"a"],2],[[2,"b"],2]],[0],[0,2]]
```

---

## 5. Why the Result is Guaranteed to be Minimal

**Brzozowski's Minimization Theorem**:
> If $A$ is a deterministic finite automaton whose states are all reachable from the initial state, then $\operatorname{det}(\operatorname{rev}(A))$ produces the unique minimal DFA accepting $L(A)^R$.

In our pipeline:
1. $D_1 = \operatorname{det}(\operatorname{rev}(M))$ is deterministic and, because BFS only enqueues reachable subsets, every state in $D_1$ is reachable.
2. Therefore, applying $\operatorname{det}(\operatorname{rev}(D_1))$ produces the minimal DFA for $(L(D_1)^R)^R = L(M)$.
