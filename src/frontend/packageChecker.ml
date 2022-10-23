
open MyUtil
open Types
open StaticEnv
open TypeError


type error =
  | TypeError                 of type_error
  | ClosedFileDependencyError of ClosedFileDependencyResolver.error
  | NotADocumentFile          of abs_path * Typeenv.t * mono_type
  | NotAStringFile            of abs_path * Typeenv.t * mono_type
  | NoMainModule              of module_name

type 'a ok = ('a, error) result


let add_dependency_to_type_environment ~(package_only : bool) (header : header_element list) (genv : global_type_environment) (tyenv : Typeenv.t) =
  header |> List.fold_left (fun tyenv headerelem ->
    let modnm_opt =
      match headerelem with
      | HeaderUse((_, modnm)) | HeaderUseOf((_, modnm), _) -> if package_only then None else Some(modnm)
      | HeaderUsePackage((_, modnm))                       -> Some(modnm)
    in
    match modnm_opt with
    | None ->
        tyenv

    | Some(modnm) ->
        begin
          match genv |> GlobalTypeenv.find_opt modnm with
          | None ->
              assert false

          | Some(ssig) ->
              let mentry = { mod_signature = ConcStructure(ssig) } in
              tyenv |> Typeenv.add_module modnm mentry
        end
  ) tyenv


let typecheck_library_file ~for_struct:(tyenv_for_struct : Typeenv.t) ~for_sig:(tyenv_for_sig : Typeenv.t) (abspath_in : abs_path) (utsig_opt : untyped_signature option) (utbinds : untyped_binding list) : (StructSig.t abstracted * binding list) ok =
  let open ResultMonad in
  let res =
    Logging.begin_to_typecheck_file abspath_in;
    let* absmodsig_opt = utsig_opt |> optionM (ModuleTypechecker.typecheck_signature tyenv_for_sig) in
    let* ret = ModuleTypechecker.main tyenv_for_struct absmodsig_opt utbinds in
    Logging.pass_type_check None;
    return ret
  in
  res |> Result.map_error (fun tyerr -> TypeError(tyerr))


let typecheck_document_file (tyenv : Typeenv.t) (abspath_in : abs_path) (utast : untyped_abstract_tree) : abstract_tree ok =
  let open ResultMonad in
  Logging.begin_to_typecheck_file abspath_in;
  let* (ty, ast) = Typechecker.main Stage1 tyenv utast |> Result.map_error (fun tyerr -> TypeError(tyerr)) in
  Logging.pass_type_check (Some(Display.show_mono_type ty));
  if OptionState.is_text_mode () then
    if Typechecker.are_unifiable ty (Range.dummy "text-mode", BaseType(StringType)) then
      return ast
    else
      err (NotAStringFile(abspath_in, tyenv, ty))
  else
    if Typechecker.are_unifiable ty (Range.dummy "pdf-mode", BaseType(DocumentType)) then
      return ast
    else
      err (NotADocumentFile(abspath_in, tyenv, ty))


let main (tyenv_prim : Typeenv.t) (genv : global_type_environment) (package : package_info) : (StructSig.t * (abs_path * binding list) list) ok =
  let open ResultMonad in
  let main_module_name = package.main_module_name in
  let utlibs = package.modules in

  (* Resolve dependency among the source files in the package: *)
  let* sorted_utlibs =
    ClosedFileDependencyResolver.main utlibs |> Result.map_error (fun e -> ClosedFileDependencyError(e))
  in

  (* Typecheck each source file: *)
  let* (_genv, libacc, ssig_opt) =
    sorted_utlibs |> foldM (fun (genv, libacc, ssig_opt) (abspath, utlib) ->
      let (header, (modident, utsig_opt, utbinds)) = utlib in
      let tyenv_for_struct = tyenv_prim |> add_dependency_to_type_environment ~package_only:false header genv in
      let (_, modnm) = modident in
      if String.equal modnm main_module_name then
        let* ((_quant, ssig), binds) =
          let tyenv_for_sig = tyenv_prim |> add_dependency_to_type_environment ~package_only:true header genv in
          typecheck_library_file ~for_struct:tyenv_for_struct ~for_sig:tyenv_for_sig abspath utsig_opt utbinds
        in
        let genv = genv |> GlobalTypeenv.add modnm ssig in
        return (genv, Alist.extend libacc (abspath, binds), Some(ssig))
      else
        let* ((_quant, ssig), binds) =
          typecheck_library_file ~for_struct:tyenv_for_struct ~for_sig:tyenv_for_struct abspath utsig_opt utbinds
        in
        let genv = genv |> GlobalTypeenv.add modnm ssig in
        return (genv, Alist.extend libacc (abspath, binds), ssig_opt)
    ) (genv, Alist.empty, None)
  in
  let libs = Alist.to_list libacc in

  match ssig_opt with
  | Some(ssig) -> return (ssig, libs)
  | None       -> err @@ NoMainModule(main_module_name)


let main_document (tyenv_prim : Typeenv.t) (genv : global_type_environment) (sorted_locals : (abs_path * untyped_library_file) list) (utdoc : abs_path * untyped_document_file) : ((abs_path * binding list) list * abstract_tree) ok =
  let open ResultMonad in
  let* (_, libacc) =
    sorted_locals |> foldM (fun (genv, libacc) (abspath, utlib) ->
      let (header, (modident, utsig_opt, utbinds)) = utlib in
      let (_, modnm) = modident in
      let* ((_quant, ssig), binds) =
        let tyenv = tyenv_prim |> add_dependency_to_type_environment ~package_only:false header genv in
        typecheck_library_file ~for_struct:tyenv ~for_sig:tyenv abspath utsig_opt utbinds
      in
      let genv = genv |> GlobalTypeenv.add modnm ssig in
      return (genv, Alist.extend libacc (abspath, binds))
    ) (genv, Alist.empty)
  in
  let libs = Alist.to_list libacc in

  (* Typecheck the document: *)
  let* ast_doc =
    let (abspath, (header, utast)) = utdoc in
    let tyenv = tyenv_prim |> add_dependency_to_type_environment ~package_only:false header genv in
    typecheck_document_file tyenv abspath utast
  in

  return (libs, ast_doc)
