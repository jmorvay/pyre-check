(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open Core

open Ast
open Expression
open Pyre


type index = {
  function_keys: (Access.t Hash_set.t) File.Handle.Table.t;
  class_keys: (Type.t Hash_set.t) File.Handle.Table.t;
  alias_keys: (Type.t Hash_set.t) File.Handle.Table.t;
  global_keys: (Access.t Hash_set.t) File.Handle.Table.t;
  dependent_keys: (Access.t Hash_set.t) File.Handle.Table.t;
}


type t = {
  index: index;
  dependents: (File.Handle.t list) Access.Table.t;
}


module type Handler = sig
  val add_function_key: handle: File.Handle.t -> Access.t -> unit
  val add_class_key: handle: File.Handle.t -> Type.t -> unit
  val add_alias_key: handle: File.Handle.t -> Type.t -> unit
  val add_global_key: handle: File.Handle.t -> Access.t -> unit
  val add_dependent_key: handle: File.Handle.t -> Access.t -> unit

  val add_dependent: handle: File.Handle.t -> Access.t -> unit
  val dependents: Access.t -> (File.Handle.t list) option

  val get_function_keys: handle: File.Handle.t -> Access.t list
  val get_class_keys: handle: File.Handle.t -> Type.t list
  val get_alias_keys: handle: File.Handle.t -> Type.t list
  val get_global_keys: handle: File.Handle.t -> Access.t list
  val get_dependent_keys: handle: File.Handle.t -> Access.t list

  val clear_keys_batch: File.Handle.t list -> unit
end


let handler {
    index = { function_keys; class_keys; alias_keys; global_keys; dependent_keys };
    dependents;
  } =
  (module struct
    let add_function_key ~handle name =
      match Hashtbl.find function_keys handle with
      | None ->
          Hashtbl.set
            function_keys
            ~key:handle
            ~data:(Access.Hash_set.of_list [name])
      | Some hash_set ->
          Hash_set.add hash_set name


    let add_class_key ~handle class_type =
      match Hashtbl.find class_keys handle with
      | None ->
          Hashtbl.set
            class_keys
            ~key:handle
            ~data:(Type.Hash_set.of_list [class_type])
      | Some hash_set ->
          Hash_set.add hash_set class_type


    let add_alias_key ~handle alias =
      match Hashtbl.find alias_keys handle with
      | None ->
          Hashtbl.set
            alias_keys
            ~key:handle
            ~data:(Type.Hash_set.of_list [alias])
      | Some hash_set ->
          Hash_set.add hash_set alias


    let add_global_key ~handle global =
      match Hashtbl.find global_keys handle with
      | None ->
          Hashtbl.set
            global_keys
            ~key:handle
            ~data:(Access.Hash_set.of_list [global])
      | Some hash_set ->
          Hash_set.add hash_set global


    let add_dependent_key ~handle dependent =
      match Hashtbl.find dependent_keys handle with
      | None ->
          Hashtbl.set
            dependent_keys
            ~key:handle
            ~data:(Access.Hash_set.of_list [dependent])
      | Some hash_set ->
          Hash_set.add hash_set dependent


    let add_dependent ~handle dependent =
      add_dependent_key ~handle dependent;
      Hashtbl.add_multi ~key:dependent ~data:handle dependents


    let dependents = Hashtbl.find dependents


    let get_function_keys ~handle =
      Hashtbl.find function_keys handle
      >>| Hash_set.to_list
      |> Option.value ~default:[]


    let get_class_keys ~handle =
      Hashtbl.find class_keys handle
      >>| Hash_set.to_list
      |> Option.value ~default:[]


    let get_alias_keys ~handle =
      Hashtbl.find alias_keys handle
      >>| Hash_set.to_list
      |> Option.value ~default:[]


    let get_global_keys ~handle =
      Hashtbl.find global_keys handle
      >>| Hash_set.to_list
      |> Option.value ~default:[]


    let get_dependent_keys ~handle =
      Hashtbl.find dependent_keys handle
      >>| Hash_set.to_list
      |> Option.value ~default:[]


    let clear_keys_batch handles =
      List.iter ~f:(Hashtbl.remove function_keys) handles;
      List.iter ~f:(Hashtbl.remove class_keys) handles;
      List.iter ~f:(Hashtbl.remove alias_keys) handles;
      List.iter ~f:(Hashtbl.remove global_keys) handles;
      List.iter ~f:(Hashtbl.remove dependent_keys) handles
  end: Handler)


let create () =
  let index = {
    function_keys = File.Handle.Table.create ();
    class_keys = File.Handle.Table.create ();
    alias_keys = File.Handle.Table.create ();
    global_keys = File.Handle.Table.create ();
    dependent_keys = File.Handle.Table.create ();
  }
  in
  { index = index; dependents = Access.Table.create () }


let copy {
    index = { function_keys; class_keys; alias_keys; global_keys; dependent_keys };
    dependents } =
  {
    index = {
      function_keys = Hashtbl.copy function_keys;
      class_keys = Hashtbl.copy class_keys;
      alias_keys = Hashtbl.copy alias_keys;
      global_keys = Hashtbl.copy global_keys;
      dependent_keys = Hashtbl.copy dependent_keys;
    };
    dependents = Hashtbl.copy dependents;
  }


let transitive ~get_dependencies ~handle =
  let transitive_closure handle =
    let rec closure ~visited node =
      if Set.mem visited node then
        visited
      else
        let visited = Set.add visited node in
        match get_dependencies node with
        | None -> visited
        | Some neighbors ->
            List.fold
              ~init:visited
              ~f:(fun visited neighbor ->
                  closure ~visited neighbor)
              neighbors
    in
    closure ~visited:File.Handle.Set.empty handle
    |> fun handles -> Set.remove handles handle
  in
  transitive_closure handle


let transitive_of_list ~get_dependencies ~handles =
  handles
  |> List.map ~f:(fun handle -> transitive ~get_dependencies ~handle)
  |> File.Handle.Set.union_list
  (* Ensure no file gets double-checked. *)
  |> (fun dependents -> Set.diff dependents (File.Handle.Set.of_list handles))


let of_list ~get_dependencies ~handles =
  let fold_dependents dependents handle =
    get_dependencies handle
    >>| File.Handle.Set.of_list
    >>| Set.union dependents
    |> Option.value ~default:dependents
  in
  List.fold
    ~init:File.Handle.Set.empty
    ~f:fold_dependents
    handles
  |> (fun dependents -> Set.diff dependents (File.Handle.Set.of_list handles))


let to_dot ~get_dependencies ~handle =
  let nodes, edges =
    let rec iterate ~worklist ~visited ~result:((nodes, edges) as result) =
      match Queue.dequeue worklist with
      | Some access ->
          let visited, nodes, edges =
            if not (Set.mem visited access) then
              let visited = Set.add visited access in
              let nodes = access :: nodes in

              let dependencies =
                get_dependencies access
                >>| List.map ~f:(fun handle -> Ast.Source.qualifier ~handle)
                |> Option.value ~default:[]
              in
              let enqueue edges dependency =
                if not (Set.mem visited dependency) then
                  Queue.enqueue worklist dependency;
                (access, dependency) :: edges
              in
              let edges = List.fold dependencies ~init:edges ~f:enqueue in
              visited, nodes, edges
            else
              visited, nodes, edges
          in
          iterate ~worklist ~visited ~result:(nodes, edges)
      | _ ->
          result
    in

    let worklist = Queue.create () in
    Queue.enqueue worklist (Ast.Source.qualifier ~handle);
    let nodes, edges = iterate ~worklist ~visited:Access.Set.empty ~result:([], []) in
    List.rev nodes, List.rev edges
  in

  let buffer = Buffer.create 10000 in
  Buffer.add_string buffer "digraph {\n";
  let print_node access =
    let label =
      Printf.sprintf
        "  %d[label=\"%s\"%s]\n"
        (Access.hash access)
        (Access.show access)
        (if (Access.equal access (Ast.Source.qualifier ~handle))
         then " color=\"red\"" else "")
    in
    Buffer.add_string buffer label
  in
  let print_edge (source, dependency) =
    let edge =
      Printf.sprintf
        "  %d -> %d [dir=back]\n"
        (Access.hash source)
        (Access.hash dependency)
    in
    Buffer.add_string buffer edge
  in
  List.iter nodes ~f:print_node;
  List.iter edges ~f:print_edge;
  Buffer.add_string buffer "}";
  Buffer.contents buffer
