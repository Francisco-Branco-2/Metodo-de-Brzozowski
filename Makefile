SRC  = ep1_entrega.ml
BIN  = ep1
PKGS = yojson

.PHONY: all clean test

all: $(BIN)

$(BIN): $(SRC)
	ocamlfind ocamlopt -package $(PKGS) -linkpkg $(SRC) -o $(BIN)

clean:
	rm -f $(BIN) *.cmi *.cmx *.cmo *.o

test: $(BIN)
	@for f in testes/*.json; do \
		echo "== $$f"; \
		./$(BIN) < $$f || echo "ERRO (código $$?)"; \
	done
