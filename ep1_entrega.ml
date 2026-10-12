(* Prompts adicionais

   Prompt: "Como consigo representar um autómato finito determinístico
     na linguagem OCaml?"
   Para que serviu: perceber as formas de guardar um autómato em OCaml.
     O programa guarda o autómato num record com listas.

   Prompt: "Explica-me o que faz a biblioteca de OCaml Yojson."
   Para que serviu: perceber como o programa lê o autómato em formato
     JSON e como escreve o resultado também em JSON. Como foi uma biblioteca apenas me introduzida neste projeto fui perceber melhor como é o seu funcionamento e como poderia tirar o melhor proveito dela neste exercicio em especifico.

   Prompt: "Explica-me de forma clara o método de Brzozowski e como ele
     é aplicado a este autómato." (autómato M1 do enunciado)
   Para que serviu: perceber como o programa minimiza o autómato.
     O método tem quatro passos: inverter, determinizar, inverter
     outra vez e determinizar outra vez. Serviu também para perceber
     porque é que o estado q_novo faz com que M' não seja mínimo
     (alínea b).

   Prompt: "Quais as melhores funções em OCaml para trabalhar com
     autómatos finitos determinísticos?"
   Para que serviu: perceber as funções de OCaml que o programa usa,
     como List.map, List.iter, Hashtbl e Queue. Esta pesquisa ocorreu depois de uma automatização de teste que pedi a Ia para fazer a um esboço de algoritmo que já tinha, apos esses testes percebi que algumas funções falhavam no cumprimento do tempo de execução e que iria necessitar utilizar de ferramentas mais adequadas para não falhar nesse requisito.
 *)

type automato = {
  estados  : int list;
  alfabeto : string list;
  trans    : (int * string * int) list;
  iniciais : int list;
  finais   : int list;
}

let para_int = function `Int n -> n | _ -> failwith "int"
let para_string = function `String s -> s | _ -> failwith "string"
let para_lista = function `List l -> l | _ -> failwith "lista"

let para_transicao = function
  | `List [ `List [ o; s ]; d ] -> (para_int o, para_string s, para_int d)
  | _ -> failwith "transicao"

let ler_automato = function
  | `List [ est; alf; tr; ini; fin ] ->
    { estados  = List.map para_int (para_lista est);
      alfabeto = List.map para_string (para_lista alf);
      trans    = List.map para_transicao (para_lista tr);
      iniciais = List.sort_uniq compare (List.map para_int (para_lista ini));
      finais   = List.sort_uniq compare (List.map para_int (para_lista fin)) }
  | _ -> failwith "automato"

let inverter m =
  { m with
    trans    = List.map (fun (o, s, d) -> (d, s, o)) m.trans;
    iniciais = m.finais;
    finais   = m.iniciais }

let mover trans conj simb =
  List.sort_uniq compare
    (List.concat_map
       (fun q ->
          List.filter_map
            (fun (o, s, d) -> if o = q && s = simb then Some d else None)
            trans)
       conj)

let determinizar m =
  if m.iniciais = [] then
    { estados = [ 0 ]; alfabeto = m.alfabeto; trans = [];
      iniciais = [ 0 ]; finais = [] }
  else
    let eh_final c = List.exists (fun q -> List.mem q m.finais) c in
    let tratar conj n_conj registados =
      List.fold_left
        (fun (registados, descobertos, transicoes) s ->
           let dest = mover m.trans conj s in
           if dest = [] then (registados, descobertos, transicoes)
           else
             match List.assoc_opt dest registados with
             | Some n_dest ->
               (registados, descobertos, (n_conj, s, n_dest) :: transicoes)
             | None ->
               let n_dest = List.length registados in
               ((dest, n_dest) :: registados,
                descobertos @ [ dest ],
                (n_conj, s, n_dest) :: transicoes))
        (registados, [], [])
        m.alfabeto
    in
    let rec explorar registados por_tratar transicoes =
      match por_tratar with
      | [] -> (registados, List.rev transicoes)
      | conj :: resto ->
        let n_conj = List.assoc conj registados in
        let (registados, descobertos, transicoes_conj) =
          tratar conj n_conj registados in
        explorar registados (resto @ descobertos) (transicoes_conj @ transicoes)
    in
    let (registados, transicoes) =
      explorar [ (m.iniciais, 0) ] [ m.iniciais ] [] in
    let finais =
      List.sort compare
        (List.filter_map
           (fun (conj, n) -> if eh_final conj then Some n else None)
           registados)
    in
    { estados  = List.init (List.length registados) (fun i -> i);
      alfabeto = m.alfabeto;
      trans    = transicoes;
      iniciais = [ 0 ];
      finais }

let completar m =
  if m.finais = [] then
    { estados = [ 0 ]; alfabeto = m.alfabeto;
      trans = List.map (fun s -> (0, s, 0)) m.alfabeto;
      iniciais = [ 0 ]; finais = [] }
  else
  let n_estados = List.length m.estados in
  if List.length m.trans = n_estados * List.length m.alfabeto then
    m
  else
    let armadilha = n_estados in
    let em_falta =
      List.concat_map
        (fun q ->
           List.filter_map
             (fun s ->
                if List.exists (fun (o, sy, _) -> o = q && sy = s) m.trans
                then None
                else Some (q, s, armadilha))
             m.alfabeto)
        m.estados
    in
    let lacos = List.map (fun s -> (armadilha, s, armadilha)) m.alfabeto in
    { m with
      estados = m.estados @ [ armadilha ];
      trans   = m.trans @ em_falta @ lacos }

let minimizar m = completar (determinizar (inverter (determinizar (inverter m))))

let para_json m =
  let ints l = `List (List.map (fun x -> `Int x) l) in
  `List [
    ints m.estados;
    `List (List.map (fun s -> `String s) m.alfabeto);
    `List (List.map
             (fun (o, s, d) -> `List [ `List [ `Int o; `String s ]; `Int d ])
             m.trans);
    ints m.iniciais;
    ints m.finais;
  ]

let () =
  let m = ler_automato (Yojson.Basic.from_channel stdin) in
  print_endline (Yojson.Basic.to_string (para_json (minimizar m)))

