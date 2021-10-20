
open LengthInterface
open GraphicBase

exception ParseErrorDetail of Range.t * string
exception IllegalArgumentLength of Range.t * int * int


type 'a ranged =
  Range.t * 'a
[@@deriving show]

type ctrlseq_name       = string  [@@deriving show]
type var_name           = string  [@@deriving show]
type id_name            = string  [@@deriving show]
type class_name         = string  [@@deriving show]
type type_name          = string  [@@deriving show]
type constructor_name   = string  [@@deriving show]
type module_name        = string  [@@deriving show]
type sig_var_name       = string  [@@deriving show]
type type_argument_name = string  [@@deriving show]
type length_unit_name   = string  [@@deriving show]
type type_variable_name = string  [@@deriving show]
type signature_name     = string  [@@deriving show]
type label              = string  [@@deriving show]
type field_name         = label   [@@deriving show]


type input_position = {
  input_file_name : string;
  input_line      : int;
  input_column    : int;
}
[@@deriving show { with_path = false }]

type header_element =
  | HeaderRequire of string
  | HeaderImport  of string


type quantifiability = Quantifiable | Unquantifiable
[@@deriving show]

type level = Level.t
[@@deriving show]


module StoreIDHashTable = Hashtbl.Make(StoreID)

module EvalVarIDMap = Map.Make(EvalVarID)

module OpaqueIDSet = Set.Make(TypeID)

module LabelSet = Set.Make(String)

module LabelMap = struct
  include Map.Make(String)


  let pp pp_v ppf labmap =
    Format.fprintf ppf "@[<hv1>{";
    fold (fun k v is_first ->
      begin
        if is_first then
          Format.fprintf ppf "%s -> %a" k pp_v v
        else
          Format.fprintf ppf ",@ %s -> %a" k pp_v v
      end;
      false
    ) labmap true |> ignore;
    Format.fprintf ppf "@]"

end

type 'a abstracted =
  OpaqueIDSet.t * 'a

type manual_type =
  Range.t * manual_type_main

and manual_type_main =
  | MTypeName        of type_name * manual_type list
  | MTypeParam       of var_name
  | MFuncType        of manual_type list * manual_type * manual_type
  | MProductType     of manual_type TupleList.t
  | MRecordType      of manual_type Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "MRecordType(...)")]
  | MHorzCommandType of manual_command_argument_type list
  | MVertCommandType of manual_command_argument_type list
  | MMathCommandType of manual_command_argument_type list
[@@deriving show]

and manual_command_argument_type =
  | MMandatoryArgumentType of manual_type
  | MOptionalArgumentType  of manual_type

type manual_kind =
  | MUniversalKind
  | MRecordKind    of manual_type Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "MRecordKind(...)")]
[@@deriving show]

type base_type =
  | EnvType
  | UnitType
  | BoolType
  | IntType
  | FloatType
  | LengthType
  | StringType
  | TextRowType
  | TextColType
  | BoxRowType
  | BoxColType
  | ContextType
  | PrePathType
  | PathType
  | GraphicsType
  | ImageType
  | DocumentType
  | MathType
  | RegExpType
  | TextInfoType
  | InputPosType
[@@deriving show]


module TypeNameMap = Map.Make(String)


let base_type_map : base_type TypeNameMap.t =
  List.fold_left (fun map (tynm, bt) ->
    map |> TypeNameMap.add tynm bt
  ) TypeNameMap.empty
  [
    ("unit"        , UnitType    );
    ("bool"        , BoolType    );
    ("int"         , IntType     );
    ("float"       , FloatType   );
    ("length"      , LengthType  );
    ("string"      , StringType  );
    ("inline-text" , TextRowType );
    ("block-text"  , TextColType );
    ("inline-boxes", BoxRowType  );
    ("block-boxes" , BoxColType  );
    ("context"     , ContextType );
    ("pre-path"    , PrePathType );
    ("path"        , PathType    );
    ("graphics"    , GraphicsType);
    ("image"       , ImageType   );
    ("document"    , DocumentType);
    ("math"        , MathType    );
    ("regexp"      , RegExpType  );
    ("text-info"   , TextInfoType);
  ]


type kind =
  | UniversalKind

type ('a, 'b) typ =
  Range.t * ('a, 'b) type_main

and ('a, 'b) type_main =
  | BaseType        of base_type
  | FuncType        of ('a, 'b) row * ('a, 'b) typ * ('a, 'b) typ
  | ListType        of ('a, 'b) typ
  | RefType         of ('a, 'b) typ
  | ProductType     of (('a, 'b) typ) TupleList.t
  | TypeVariable    of 'a
  | DataType        of (('a, 'b) typ) list * TypeID.t
  | RecordType      of ('a, 'b) row
      [@printer (fun fmt _ -> Format.fprintf fmt "RecordType(...)")]
  | HorzCommandType of (('a, 'b) command_argument_type) list
  | VertCommandType of (('a, 'b) command_argument_type) list
  | MathCommandType of (('a, 'b) command_argument_type) list
  | CodeType        of ('a, 'b) typ

and ('a, 'b) command_argument_type =
  | MandatoryArgumentType of ('a, 'b) typ
  | OptionalArgumentType  of label ranged * ('a, 'b) typ

and ('a, 'b) row =
  | RowCons  of label ranged * ('a, 'b) typ * ('a, 'b) row
  | RowVar   of 'b
  | RowEmpty

and mono_row_variable_updatable =
  | MonoORFree of FreeRowID.t
  | MonoORLink of mono_row

and mono_row_variable =
  | UpdatableRow   of mono_row_variable_updatable ref
(*
  | MustBeBoundRow of MustBeBoundRowID.t
*)

and poly_row_variable =
  | PolyORFree of mono_row_variable

and mono_type_variable_updatable =
  | MonoFree of FreeID.t
  | MonoLink of mono_type

and mono_type_variable =
  | Updatable   of mono_type_variable_updatable ref
  | MustBeBound of MustBeBoundID.t

and poly_type_variable =
  | PolyFree  of mono_type_variable
  | PolyBound of BoundID.t

and mono_type =
  (mono_type_variable, mono_row_variable) typ

and poly_type_body =
  (poly_type_variable, poly_row_variable) typ

and poly_type =
  | Poly of poly_type_body

and mono_row =
  (mono_type_variable, mono_row_variable) row

type mono_command_argument_type =
  (mono_type_variable, mono_row_variable) command_argument_type

type macro_parameter_type =
  | LateMacroParameter  of mono_type
  | EarlyMacroParameter of mono_type

type macro_type =
  | HorzMacroType of macro_parameter_type list
  | VertMacroType of macro_parameter_type list


let pp_sep fmt () =
  Format.fprintf fmt ";@ "


type stage =
  | Persistent0
  | Stage0
  | Stage1

module TypeParameterMap = Map.Make(String)

type type_parameter_map = MustBeBoundID.t TypeParameterMap.t

type pre = {
  level           : level;
  type_parameters : type_parameter_map;
  quantifiability : quantifiability;  (* maybe omitted in the future *)
  stage           : stage;
}


let string_of_stage = function
  | Persistent0 -> "persistent stage"
  | Stage0      -> "stage 0"
  | Stage1      -> "stage 1"


type untyped_macro_parameter =
  | UTLateMacroParam  of (Range.t * var_name)
  | UTEarlyMacroParam of (Range.t * var_name)
[@@deriving show { with_path = false; } ]

type untyped_binding =
  untyped_binding_main ranged

and untyped_binding_main =
  | UTBindValue     of untyped_rec_or_nonrec
  | UTBindType      of untyped_type_binding list
  | UTBindModule    of module_name ranged * untyped_signature option * untyped_module
  | UTBindSignature of signature_name ranged * untyped_signature
  | UTBindInclude   of untyped_module
  | UTBindHorzMacro of ctrlseq_name ranged * untyped_macro_parameter list * untyped_abstract_tree
  | UTBindVertMacro of ctrlseq_name ranged * untyped_macro_parameter list * untyped_abstract_tree

and untyped_module =
  untyped_module_main ranged

and untyped_module_main =
  | UTModVar     of module_name
  | UTModBinds   of untyped_binding list
  | UTModProjMod of untyped_module * module_name ranged
  | UTModFunctor of module_name ranged * untyped_signature * untyped_module
  | UTModApply   of module_name ranged * module_name ranged
  | UTModCoerce  of module_name ranged * untyped_signature

and untyped_signature =
  untyped_signature_main ranged

and untyped_signature_main =
  | UTSigVar     of signature_name
  | UTSigPath    of untyped_module * signature_name ranged
  | UTSigDecls   of untyped_declaration list
  | UTSigFunctor of module_name ranged * untyped_signature * untyped_signature
  | UTSigWith    of untyped_signature * (module_name ranged) list * type_name ranged * (type_variable_name ranged) list * manual_type

and untyped_declaration =
  untyped_declaration_main
    (* TEMPORARY; should be `untyped_declaration_main ranged`  *)

and untyped_declaration_main =
  | UTDeclValue      of var_name ranged * constraints * manual_type
  | UTDeclDirect     of var_name ranged * constraints * manual_type
  | UTDeclTypeTrans  of type_name ranged * manual_type
  | UTDeclTypeOpaque of type_name ranged * untyped_type_argument list
  | UTDeclModule     of module_name ranged * untyped_signature
  | UTDeclSignature  of signature_name ranged * untyped_signature
  | UTDeclInclude    of untyped_signature

and constructor_branch =
  | UTConstructorBranch of constructor_name ranged * manual_type

and untyped_rec_or_nonrec =
  | UTNonRec  of untyped_let_binding
  | UTRec     of untyped_letrec_binding list
  | UTMutable of untyped_let_mutable_binding

and untyped_let_binding =
  manual_type option * untyped_pattern_tree * untyped_abstract_tree

and untyped_letrec_binding =
  UTLetRecBinding of manual_type option * Range.t * var_name * untyped_abstract_tree

and untyped_let_mutable_binding =
  (Range.t * var_name) * untyped_abstract_tree

and untyped_type_binding =
  type_name ranged * (type_variable_name ranged) list * constraints * untyped_synonym_or_variant

and untyped_synonym_or_variant =
  | UTBindSynonym of manual_type
  | UTBindVariant of constructor_branch list

and untyped_input_horz_element = Range.t * untyped_input_horz_element_main
  [@printer (fun fmt (_, utihmain) -> Format.fprintf fmt "%a" pp_untyped_input_horz_element_main utihmain)]

and untyped_input_horz_element_main =
  | UTInputHorzText         of string
      [@printer (fun fmt s -> Format.fprintf fmt "IT:%s" s)]
  | UTInputHorzEmbedded     of untyped_abstract_tree * untyped_command_argument list
      [@printer (fun fmt (utast, lst) -> Format.fprintf fmt "IC:%a %a" pp_untyped_abstract_tree utast (Format.pp_print_list ~pp_sep pp_untyped_command_argument) lst)]
  | UTInputHorzContent      of untyped_abstract_tree
  | UTInputHorzEmbeddedMath of untyped_abstract_tree
  | UTInputHorzEmbeddedCodeText of string
  | UTInputHorzMacro        of (Range.t * ctrlseq_name) * untyped_macro_argument list

and untyped_macro_argument =
  | UTLateMacroArg  of untyped_abstract_tree
  | UTEarlyMacroArg of untyped_abstract_tree

and untyped_input_vert_element = Range.t * untyped_input_vert_element_main
  [@printer (fun fmt (_, utivmain) -> Format.fprintf fmt "%a" pp_untyped_input_vert_element_main utivmain)]

and untyped_input_vert_element_main =
  | UTInputVertEmbedded of untyped_abstract_tree * untyped_command_argument list
      [@printer (fun fmt (utast, lst) -> Format.fprintf fmt "BC:%a %a" pp_untyped_abstract_tree utast (Format.pp_print_list ~pp_sep pp_untyped_command_argument) lst)]
  | UTInputVertContent  of untyped_abstract_tree
  | UTInputVertMacro    of (Range.t * ctrlseq_name) * untyped_macro_argument list

and 'a untyped_path_component =
  | UTPathLineTo        of 'a
  | UTPathCubicBezierTo of untyped_abstract_tree * untyped_abstract_tree * 'a

and untyped_abstract_tree =
  Range.t * untyped_abstract_tree_main
    [@printer (fun fmt (_, utastmain) -> Format.fprintf fmt "%a" pp_untyped_abstract_tree_main utastmain)]

and untyped_abstract_tree_main =
(* -- basic value -- *)
  | UTUnitConstant
  | UTBooleanConstant      of bool
  | UTIntegerConstant      of int
  | UTFloatConstant        of float
  | UTLengthDescription    of float * length_unit_name
  | UTStringEmpty
  | UTStringConstant       of string
  | UTPositionedString     of input_position * string
(* -- inputs -- *)
  | UTInputHorz            of untyped_input_horz_element list
  | UTInputVert            of untyped_input_vert_element list
  | UTConcat               of untyped_abstract_tree * untyped_abstract_tree
  | UTLambdaHorz           of Range.t * var_name * untyped_abstract_tree
  | UTLambdaVert           of Range.t * var_name * untyped_abstract_tree
  | UTLambdaMath           of untyped_abstract_tree
(* -- horizontal box list -- *)
  | UTHorz                 of HorzBox.horz_box list
  | UTHorzConcat           of untyped_abstract_tree * untyped_abstract_tree
(* -- vertical box list -- *)
  | UTVert                 of HorzBox.vert_box list
  | UTVertConcat           of untyped_abstract_tree * untyped_abstract_tree
(* -- list value -- *)
  | UTListCons             of untyped_abstract_tree * untyped_abstract_tree
  | UTEndOfList
(* -- tuple value -- *)
  | UTTuple               of untyped_abstract_tree TupleList.t
(* -- record value -- *)
  | UTRecord               of (field_name * untyped_abstract_tree) list
  | UTAccessField          of untyped_abstract_tree * field_name
  | UTUpdateField          of untyped_abstract_tree * field_name * untyped_abstract_tree
(* -- fundamental -- *)
  | UTContentOf            of (module_name list) * var_name
  | UTApply                of (label ranged * untyped_abstract_tree) list * untyped_abstract_tree * untyped_abstract_tree
  | UTLetIn                of untyped_rec_or_nonrec * untyped_abstract_tree
  | UTIfThenElse           of untyped_abstract_tree * untyped_abstract_tree * untyped_abstract_tree
  | UTFunction             of (label ranged * var_name) list * untyped_pattern_tree * untyped_abstract_tree
  | UTOpenIn               of Range.t * module_name * untyped_abstract_tree
(* -- pattern match -- *)
  | UTPatternMatch         of untyped_abstract_tree * untyped_pattern_branch list
  | UTConstructor          of constructor_name * untyped_abstract_tree
  | UTOverwrite            of Range.t * var_name * untyped_abstract_tree
(* -- lightweight itemize -- *)
  | UTItemize              of untyped_itemize
(* -- math -- *)
  | UTMath                 of untyped_math
(* -- for lightweight command definition -- *)
  | UTLexHorz              of untyped_abstract_tree * untyped_abstract_tree
  | UTLexVert              of untyped_abstract_tree * untyped_abstract_tree
(* -- multi-stage constructs -- *)
  | UTNext                 of untyped_abstract_tree
  | UTPrev                 of untyped_abstract_tree

and constraints =
  (var_name * manual_kind) list

and untyped_itemize =
  | UTItem of untyped_abstract_tree * (untyped_itemize list)

and untyped_pattern_tree =
  Range.t * untyped_pattern_tree_main

and untyped_pattern_tree_main =
  | UTPIntegerConstant     of int
  | UTPBooleanConstant     of bool
  | UTPStringConstant      of string
  | UTPUnitConstant
  | UTPListCons            of untyped_pattern_tree * untyped_pattern_tree
  | UTPEndOfList
  | UTPTuple               of untyped_pattern_tree TupleList.t
  | UTPWildCard
  | UTPVariable            of var_name
  | UTPAsVariable          of var_name * untyped_pattern_tree
  | UTPConstructor         of constructor_name * untyped_pattern_tree

and untyped_pattern_branch =
  | UTPatternBranch     of untyped_pattern_tree * untyped_abstract_tree
  | UTPatternBranchWhen of untyped_pattern_tree * untyped_abstract_tree * untyped_abstract_tree

and untyped_unkinded_type_argument =
  Range.t * var_name

and untyped_type_argument =
  Range.t * var_name * manual_kind

and untyped_math =
  Range.t * untyped_math_main

and untyped_math_main =
  | UTMChars       of Uchar.t list
      [@printer (fun ppf uchs -> Format.fprintf ppf "UTMChars(_)")]
  | UTMSuperScript of untyped_math * bool * untyped_math
  | UTMSubScript   of untyped_math * bool * untyped_math
  | UTMCommand     of untyped_abstract_tree * untyped_command_argument list
  | UTMList        of untyped_math list
  | UTMEmbed       of untyped_abstract_tree

and untyped_command_argument =
  | UTMandatoryArgument of untyped_abstract_tree
  | UTOptionalArgument  of untyped_abstract_tree
  | UTOmission          of Range.t
[@@deriving show { with_path = false; }]

type untyped_letrec_pattern_branch =
  | UTLetRecPatternBranch of untyped_pattern_tree list * untyped_abstract_tree

type untyped_argument =
  | UTPatternArgument  of untyped_pattern_tree
  | UTOptionalArgument of Range.t * var_name

type untyped_let_pattern_binding =
  manual_type option * untyped_pattern_tree * untyped_argument list * untyped_abstract_tree

type 'a input_horz_element_scheme =
  | InputHorzText         of string
  | InputHorzEmbedded     of 'a
  | InputHorzContent      of 'a
  | InputHorzEmbeddedMath of 'a
  | InputHorzEmbeddedCodeText of string
[@@deriving show { with_path = false; }]

type 'a input_vert_element_scheme =
  | InputVertEmbedded of 'a
  | InputVertContent  of 'a
[@@deriving show { with_path = false; }]

type ('a, 'b) path_component_scheme =
  | PathLineTo        of 'a
  | PathCubicBezierTo of 'b * 'b * 'a
[@@deriving show { with_path = false; }]

type page_break_style =
  | SingleColumn
  | MultiColumn of length list
[@@deriving show { with_path = false; }]

type base_constant =
  | BCUnit
  | BCBool     of bool
  | BCInt      of int
  | BCFloat    of float
  | BCLength   of length
  | BCString   of string
  | BCRegExp   of Str.regexp
      [@printer (fun fmt _ -> Format.fprintf fmt "<regexp>")]
  | BCPath     of path list
      [@printer (fun fmt _ -> Format.fprintf fmt "<path>")]
  | BCPrePath  of PrePath.t
      [@printer (fun fmt _ -> Format.fprintf fmt "<pre-path>")]
  | BCImageKey of ImageInfo.key
      [@printer (fun fmt _ -> Format.fprintf fmt "<image-key>")]
  | BCHorz     of HorzBox.horz_box list
  | BCVert     of HorzBox.vert_box list
  | BCGraphics of (HorzBox.intermediate_horz_box list) GraphicD.element
      [@printer (fun fmt _ -> Format.fprintf fmt "<graphics>")]
  | BCTextModeContext of TextBackend.text_mode_context
  | BCDocument        of HorzBox.page_size * page_break_style * HorzBox.column_hook_func * HorzBox.column_hook_func * HorzBox.page_content_scheme_func * HorzBox.page_parts_scheme_func * HorzBox.vert_box list
  | BCInputPos        of input_position
[@@deriving show { with_path = false; }]

type code_binding =
  unit  (* TEMPORARY *)

type 'a letrec_binding_scheme =
  | LetRecBinding of EvalVarID.t * 'a pattern_branch_scheme

and letrec_binding =
  abstract_tree letrec_binding_scheme

and rec_or_nonrec =
  | Rec     of letrec_binding list
  | NonRec  of pattern_tree * abstract_tree
  | Mutable of EvalVarID.t * abstract_tree

and binding =
  | BindValue  of rec_or_nonrec
  | BindModule of ModuleID.t * binding list

and environment =
  location EvalVarIDMap.t * (syntactic_value StoreIDHashTable.t) ref
    [@printer (fun fmt _ -> Format.fprintf fmt "<env>")]

and location =
  syntactic_value ref

and vmenv =
  environment * (syntactic_value array) list

and compiled_input_horz_element =
  | CompiledInputHorzText         of string
  | CompiledInputHorzEmbedded     of instruction list
  | CompiledInputHorzContent      of instruction list
  | CompiledInputHorzEmbeddedMath of instruction list
  | CompiledInputHorzEmbeddedCodeText of string

and compiled_intermediate_input_horz_element =
  | CompiledImInputHorzText         of string
  | CompiledImInputHorzEmbedded     of instruction list
  | CompiledImInputHorzContent of compiled_intermediate_input_horz_element list * vmenv
  | CompiledImInputHorzEmbeddedMath of instruction list
  | CompiledImInputHorzEmbeddedCodeText of string

and compiled_input_vert_element =
  | CompiledInputVertEmbedded of instruction list
  | CompiledInputVertContent  of instruction list

and compiled_intermediate_input_vert_element =
  | CompiledImInputVertEmbedded of instruction list
  | CompiledImInputVertContent  of compiled_intermediate_input_vert_element list * vmenv

and ir_input_horz_element =
  | IRInputHorzText         of string
  | IRInputHorzEmbedded     of ir
  | IRInputHorzContent      of ir
  | IRInputHorzEmbeddedMath of ir
  | IRInputHorzEmbeddedCodeText of string

and ir_input_vert_element =
  | IRInputVertEmbedded of ir
  | IRInputVertContent  of ir

and varloc =
  | GlobalVar of location * EvalVarID.t * int ref
  | LocalVar  of int * int * EvalVarID.t * int ref

and ir =
  | IRConstant              of syntactic_value
  | IRTerminal
  | IRInputHorz             of ir_input_horz_element list
  | IRInputVert             of ir_input_vert_element list
  | IRRecord                of Assoc.key list * ir list
      [@printer (fun fmt _ -> Format.fprintf fmt "IRRecord(...)")]
  | IRAccessField           of ir * field_name
  | IRUpdateField           of ir * field_name * ir
  | IRLetRecIn              of (varloc * ir) list * ir
  | IRLetNonRecIn           of ir * ir_pattern_tree * ir
  | IRContentOf             of varloc
  | IRPersistent            of varloc
  | IRSymbolOf              of varloc
  | IRIfThenElse            of ir * ir * ir
  | IRFunction              of int * varloc LabelMap.t * ir_pattern_tree list * ir
  | IRApply                 of int * ir * ir list
  | IRApplyPrimitive        of instruction * int * ir list
  | IRApplyOptional         of ir * ir
  | IRApplyOmission         of ir
  | IRTuple                 of int * ir list
  | IRPatternMatch          of Range.t * ir * ir_pattern_branch list
  | IRNonValueConstructor   of constructor_name * ir
  | IRLetMutableIn          of varloc * ir * ir
  | IROverwrite             of varloc * ir
  | IRDereference           of ir
  | IRModule                of ir * ir

  | IRCodeCombinator        of (code_value list -> code_value) * int * ir list
  | IRCodeRecord            of Assoc.key list * ir list
      [@printer (fun fmt _ -> Format.fprintf fmt "IRCodeRecord(...)")]
  | IRCodeInputHorz         of (ir input_horz_element_scheme) list
  | IRCodeInputVert         of (ir input_vert_element_scheme) list
  | IRCodePatternMatch      of Range.t * ir * ir_pattern_branch list
  | IRCodeLetRecIn          of ir_letrec_binding list * ir
  | IRCodeLetNonRecIn       of ir_pattern_tree * ir * ir
  | IRCodeFunction          of varloc LabelMap.t * ir_pattern_tree * ir
  | IRCodeLetMutableIn      of varloc * ir * ir
  | IRCodeOverwrite         of varloc * ir
  | IRCodeModule            of ir * ir
  | IRCodeFinishHeaderFile
  | IRCodeFinishStruct

and 'a ir_letrec_binding_scheme =
  | IRLetRecBinding of varloc * 'a ir_pattern_branch_scheme

and ir_letrec_binding =
  ir ir_letrec_binding_scheme

and 'a ir_pattern_branch_scheme =
  | IRPatternBranch      of ir_pattern_tree * 'a
  | IRPatternBranchWhen  of ir_pattern_tree * 'a * 'a

and ir_pattern_branch =
  ir ir_pattern_branch_scheme

and ir_pattern_tree =
  | IRPUnitConstant
  | IRPBooleanConstant      of bool
  | IRPIntegerConstant      of int
  | IRPStringConstant       of string
  | IRPListCons             of ir_pattern_tree * ir_pattern_tree
  | IRPEndOfList
  | IRPTuple                of ir_pattern_tree TupleList.t
  | IRPWildCard
  | IRPVariable             of varloc
  | IRPAsVariable           of varloc * ir_pattern_tree
  | IRPConstructor          of constructor_name * ir_pattern_tree

and instruction =
  | OpAccessField of field_name
  | OpUpdateField of field_name
  | OpForward of int
  | OpApply of int
  | OpApplyT of int
  | OpApplyOptional
  | OpApplyOmission
  | OpBindGlobal of syntactic_value ref * EvalVarID.t * int
  | OpBindLocal of int * int * EvalVarID.t * int
  | OpBindClosuresRec of (varloc * instruction list) list
  | OpBranch of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpBranch(...)")]
  | OpBranchIf of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpBranchIf(...)")]
  | OpBranchIfNot of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpBranchIfNot(...)")]
  | OpLoadGlobal of syntactic_value ref * EvalVarID.t * int
      [@printer ((fun fmt (r, evid, refs) -> Format.fprintf fmt "OpLoadGlobal(%s)" (EvalVarID.show_direct evid)))]
  | OpLoadLocal of int * int * EvalVarID.t * int
  | OpDereference
      (* !! pdf, no-interp *)
  | OpDup
  | OpError of string
  | OpMakeConstructor of constructor_name
  | OpMakeRecord of Assoc.key list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpMakeRecord(...)")]
  | OpMakeTuple of int
  | OpPop
  | OpPush of syntactic_value
  | OpPushEnv
  | OpCheckStackTopBool of bool * instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopBool(...)")]
  | OpCheckStackTopCtor of constructor_name * instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopCtor(...)")]
  | OpCheckStackTopEndOfList of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopEndOfList(...)")]
  | OpCheckStackTopInt of int * instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopInt(...)")]
  | OpCheckStackTopListCons of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopListCons(...)")]
  | OpCheckStackTopStr of string * instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopStr(...)")]
  | OpCheckStackTopTupleCons of instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCheckStackTopTupleCons(...)")]
  | OpClosure of varloc LabelMap.t * int * int * instruction list
  | OpClosureInputHorz of compiled_input_horz_element list
  | OpClosureInputVert of compiled_input_vert_element list
  | OpBindLocationGlobal of syntactic_value ref * EvalVarID.t
  | OpBindLocationLocal of int * int * EvalVarID.t
  | OpUpdateGlobal of syntactic_value ref * EvalVarID.t
      [@printer (fun fmt _ -> Format.fprintf fmt "OpUpdateGlobal(...)")]
  | OpUpdateLocal of int * int * EvalVarID.t
      [@printer (fun fmt _ -> Format.fprintf fmt "OpUpdateLocal(...)")]
  | OpSel of instruction list * instruction list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpSel(...)")]

  | OpBackendMathList of int
      (* !! no-ircode *)

  | OpInsertArgs of syntactic_value list
  | OpApplyCodeCombinator of (code_value list -> code_value) * int
  | OpCodeMakeRecord of Assoc.key list
      [@printer (fun fmt _ -> Format.fprintf fmt "OpCodeMakeRecord(...)")]
  | OpCodeMathList of int
  | OpCodeMakeTuple of int
  | OpCodeMakeInputHorz of ((instruction list) input_horz_element_scheme) list
  | OpCodeMakeInputVert of ((instruction list) input_vert_element_scheme) list
  | OpCodePatternMatch  of Range.t * ((instruction list) ir_pattern_branch_scheme) list
  | OpCodeLetRec        of ((instruction list) ir_letrec_binding_scheme) list * instruction list
  | OpCodeLetNonRec     of ir_pattern_tree * instruction list * instruction list
  | OpCodeFunction      of varloc LabelMap.t * ir_pattern_tree * instruction list
  | OpCodeLetMutable    of varloc * instruction list * instruction list
  | OpCodeOverwrite     of instruction list
  | OpCodeModule        of instruction list * instruction list
  | OpCodeFinishHeaderFile
  | OpCodeFinishStruct
  | OpConvertSymbolToCode
#include "__insttype.gen.ml"

and intermediate_input_horz_element =
  | ImInputHorzText         of string
  | ImInputHorzEmbedded     of abstract_tree
  | ImInputHorzContent      of intermediate_input_horz_element list * environment
  | ImInputHorzEmbeddedMath of abstract_tree
  | ImInputHorzEmbeddedCodeText of string

and intermediate_input_vert_element =
  | ImInputVertEmbedded of abstract_tree
  | ImInputVertContent  of intermediate_input_vert_element list * environment

and syntactic_value =
  | Nil  (* -- just for brief use -- *)
  | BaseConstant of base_constant
  | Constructor  of constructor_name * syntactic_value
  | List         of syntactic_value list
  | Tuple        of syntactic_value list
  | RecordValue  of syntactic_value Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "<record-value>")]
  | Location     of StoreID.t
  | MathValue    of math list
  | Context      of input_context
  | CodeValue    of code_value
  | CodeSymbol   of CodeSymbol.t

  | EvaluatedEnvironment

(* -- for the naive interpreter, i.e. 'evaluator.cppo.ml' -- *)
  | Closure          of EvalVarID.t LabelMap.t * pattern_branch * environment
  | PrimitiveClosure of pattern_branch * environment * int * (abstract_tree list -> abstract_tree)
  | InputHorzClosure of intermediate_input_horz_element list * environment
  | InputVertClosure of intermediate_input_vert_element list * environment

(* -- for the SECD machine, i.e. 'vm.cppo.ml' -- *)
  | CompiledClosure          of varloc LabelMap.t * int * syntactic_value list * int * instruction list * vmenv
  | CompiledPrimitiveClosure of int * syntactic_value list * int * instruction list * vmenv * (abstract_tree list -> abstract_tree)
  | CompiledInputHorzClosure of compiled_intermediate_input_horz_element list * vmenv
  | CompiledInputVertClosure of compiled_intermediate_input_vert_element list * vmenv

and abstract_tree =
  | ASTBaseConstant       of base_constant
  | ASTEndOfList
  | ASTMath               of math list
  | FinishHeaderFile
  | FinishStruct
(* -- input texts -- *)
  | InputHorz             of input_horz_element list
  | InputVert             of input_vert_element list
(* -- record value -- *)
  | Record                of abstract_tree Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "Record(...)")]
  | AccessField           of abstract_tree * field_name
  | UpdateField           of abstract_tree * field_name * abstract_tree
(* -- fundamental -- *)
  | LetRecIn              of letrec_binding list * abstract_tree
  | LetNonRecIn           of pattern_tree * abstract_tree * abstract_tree
  | ContentOf             of Range.t * EvalVarID.t
  | Persistent            of Range.t * EvalVarID.t
  | IfThenElse            of abstract_tree * abstract_tree * abstract_tree
  | Function              of EvalVarID.t LabelMap.t * pattern_branch
  | Apply                 of abstract_tree LabelMap.t * abstract_tree * abstract_tree
(* -- pattern match -- *)
  | PatternMatch          of Range.t * abstract_tree * pattern_branch list
  | NonValueConstructor   of constructor_name * abstract_tree
(* -- imperative -- *)
  | LetMutableIn          of EvalVarID.t * abstract_tree * abstract_tree
  | Dereference           of abstract_tree
  | Overwrite             of EvalVarID.t * abstract_tree
(* -- module system -- *)
  | Module                of abstract_tree * abstract_tree
  | BackendMathList             of abstract_tree list
  | PrimitiveTuple        of abstract_tree TupleList.t
(* -- staging constructs -- *)
  | Next                  of abstract_tree
  | Prev                  of abstract_tree
#include "__attype.gen.ml"

and input_horz_element =
  abstract_tree input_horz_element_scheme

and input_vert_element =
  abstract_tree input_vert_element_scheme

and 'a path_component =
  ('a, abstract_tree) path_component_scheme

and 'a pattern_branch_scheme =
  | PatternBranch      of pattern_tree * 'a
  | PatternBranchWhen  of pattern_tree * 'a * 'a

and pattern_branch =
  abstract_tree pattern_branch_scheme

and pattern_tree =
  | PUnitConstant
  | PBooleanConstant      of bool
  | PIntegerConstant      of int
  | PStringConstant       of string
  | PListCons             of pattern_tree * pattern_tree
  | PEndOfList
  | PTuple                of pattern_tree TupleList.t
  | PWildCard
  | PVariable             of EvalVarID.t
  | PAsVariable           of EvalVarID.t * pattern_tree
  | PConstructor          of constructor_name * pattern_tree

and input_context =
  HorzBox.context_main * context_sub

and context_sub = {
  math_command : math_command_func;
  code_text_command : code_text_command_func;
  dummy : unit;
}

and math_command_func =
  | MathCommand of syntactic_value
      (* (input_context -> math list -> HorzBox.horz_box list) *)

and code_text_command_func =
  | DefaultCodeTextCommand
  | CodeTextCommand of syntactic_value

and math_element_main =
  | MathChar         of bool * Uchar.t list
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-char>")]
      (* --
         (1) whether it is a big operator
         (2) Unicode code point (currently singular)
         -- *)
  | MathCharWithKern of bool * Uchar.t list * HorzBox.math_char_kern_func * HorzBox.math_char_kern_func
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-char'>")]
      (* --
         (1) whether it is a big operator
         (2) Unicode code point (currently singular)
         (3) left-hand-side kerning function
         (4) right-hand-side kerning function
         --*)
  | MathEmbeddedText of (input_context -> HorzBox.horz_box list)

and math_element =
  | MathElement           of HorzBox.math_kind * math_element_main
  | MathVariantChar       of Uchar.t
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-variant-char>")]
  | MathVariantCharDirect of HorzBox.math_kind * bool * HorzBox.math_variant_style
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-variant-char-direct>")]
      (* --
         (1) math class
         (2) whether it is a big operator
         (3) Unicode code point for all math_char_class
         -- *)

and math_context_change =
  | MathChangeColor         of color
  | MathChangeMathCharClass of HorzBox.math_char_class

and math =
  | MathPure              of math_element
  | MathPullInScripts     of HorzBox.math_kind * HorzBox.math_kind * ((math list) option -> (math list) option -> math list)
  | MathChangeContext     of math_context_change * math list
  | MathGroup             of HorzBox.math_kind * HorzBox.math_kind * math list
  | MathSubscript         of math list * math list
  | MathSuperscript       of math list * math list
  | MathFraction          of math list * math list
  | MathRadicalWithDegree of math list * math list
  | MathRadical           of HorzBox.radical * math list
  | MathParen             of HorzBox.paren * HorzBox.paren * math list
  | MathParenWithMiddle   of HorzBox.paren * HorzBox.paren * HorzBox.paren * (math list) list
  | MathUpperLimit        of math list * math list
  | MathLowerLimit        of math list * math list

and code_value =
  | CdBaseConstant  of base_constant
  | CdEndOfList
  | CdMath          of math list
  | CdFinishHeaderFile
  | CdFinishStruct
  | CdInputHorz     of code_input_horz_element list
  | CdInputVert     of code_input_vert_element list
  | CdContentOf     of Range.t * CodeSymbol.t
  | CdPersistent    of Range.t * EvalVarID.t
  | CdLetRecIn      of code_letrec_binding list * code_value
  | CdLetNonRecIn   of code_pattern_tree * code_value * code_value
  | CdFunction      of CodeSymbol.t LabelMap.t * code_pattern_branch
  | CdApply         of code_value LabelMap.t * code_value * code_value
  | CdIfThenElse    of code_value * code_value * code_value
  | CdRecord        of code_value Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "CdRecord(...)")]
  | CdAccessField   of code_value * field_name
  | CdUpdateField   of code_value * field_name * code_value
  | CdLetMutableIn  of CodeSymbol.t * code_value * code_value
  | CdOverwrite     of CodeSymbol.t * code_value
  | CdDereference   of code_value
  | CdPatternMatch  of Range.t * code_value * code_pattern_branch list
  | CdConstructor   of constructor_name * code_value
  | CdTuple         of code_value TupleList.t
  | CdMathList      of code_value list
  | CdModule        of code_value * code_value
#include "__codetype.gen.ml"

and code_input_horz_element =
  code_value input_horz_element_scheme

and code_input_vert_element =
  code_value input_vert_element_scheme

and 'a code_path_component =
  ('a, code_value) path_component_scheme

and code_letrec_binding =
  | CdLetRecBinding of CodeSymbol.t * code_pattern_branch

and code_pattern_branch =
  | CdPatternBranch     of code_pattern_tree * code_value
  | CdPatternBranchWhen of code_pattern_tree * code_value * code_value

and code_pattern_tree =
  | CdPUnitConstant
  | CdPBooleanConstant      of bool
  | CdPIntegerConstant      of int
  | CdPStringConstant       of string
  | CdPListCons             of code_pattern_tree * code_pattern_tree
  | CdPEndOfList
  | CdPTuple                of code_pattern_tree TupleList.t
  | CdPWildCard
  | CdPVariable             of CodeSymbol.t
  | CdPAsVariable           of CodeSymbol.t * code_pattern_tree
  | CdPConstructor          of constructor_name * code_pattern_tree
[@@deriving show { with_path = false; }]

type 'a cycle =
  | Loop  of 'a
  | Cycle of 'a TupleList.t


module BoundIDHashTable = Hashtbl.Make(BoundID)

module FreeIDHashTable = Hashtbl.Make(FreeID)

module BoundIDMap = Map.Make(BoundID)

module FreeIDMap = Map.Make(FreeID)

module OpaqueIDMap = Map.Make(TypeID)

module ConstructorMap = Map.Make(String)

type constructor_branch_map = poly_type ConstructorMap.t


let get_range (rng, _) = rng


let add_to_environment (env : environment) (evid : EvalVarID.t) (rfast : location) : environment =
  let (valenv, stenvref) = env in
    (valenv |> EvalVarIDMap.add evid rfast, stenvref)


let find_in_environment (env : environment) (evid : EvalVarID.t) : location option =
  let (valenv, _) = env in
    valenv |> EvalVarIDMap.find_opt evid


let register_location (env : environment) (value : syntactic_value) : StoreID.t =
  let (_, stenvref) = env in
  let stid = StoreID.fresh () in
  StoreIDHashTable.add (!stenvref) stid value;
  stid


let update_location (env : environment) (stid : StoreID.t) (value : syntactic_value) : unit =
  let (_, stenvref) = env in
  let stenv = !stenvref in
  if StoreIDHashTable.mem stenv stid then
    StoreIDHashTable.replace stenv stid value
  else
    assert false


let find_location_value (env : environment) (stid : StoreID.t) : syntactic_value option =
  let (_, stenvref) = env in
  StoreIDHashTable.find_opt (!stenvref) stid


let map_input_horz f ihlst =
  ihlst |> List.map (function
  | InputHorzText(s)           -> InputHorzText(s)
  | InputHorzEmbedded(ast)     -> InputHorzEmbedded(f ast)
  | InputHorzContent(ast)      -> InputHorzContent(f ast)
  | InputHorzEmbeddedMath(ast) -> InputHorzEmbeddedMath(f ast)
  | InputHorzEmbeddedCodeText(s) -> InputHorzEmbeddedCodeText(s)
  )


let map_input_vert f ivlst =
  ivlst |> List.map (function
  | InputVertContent(ast)  -> InputVertContent(f ast)
  | InputVertEmbedded(ast) -> InputVertEmbedded(f ast)
  )


let map_path_component f g = function
  | PathLineTo(ast) ->
      PathLineTo(g ast)

  | PathCubicBezierTo(ast1, ast2, ast3) ->
      let v1 = f ast1 in
      let v2 = f ast2 in
      let v3 = g ast3 in
      PathCubicBezierTo(v1, v2, v3)


let rec unlift_code (code : code_value) : abstract_tree =
  let rec aux code =
    match code with
    | CdBaseConstant(bc)                   -> ASTBaseConstant(bc)
    | CdEndOfList                          -> ASTEndOfList
    | CdMath(mlst)                         -> ASTMath(mlst)
    | CdFinishHeaderFile                   -> FinishHeaderFile
    | CdFinishStruct                       -> FinishStruct
    | CdInputHorz(cdihlst)                 -> InputHorz(cdihlst |> map_input_horz aux)
    | CdInputVert(cdivlst)                 -> InputVert(cdivlst |> map_input_vert aux)
    | CdContentOf(rng, symb)               -> ContentOf(rng, CodeSymbol.unlift symb)
    | CdPersistent(rng, evid)              -> ContentOf(rng, evid)
    | CdLetRecIn(cdrecbinds, code1)        -> LetRecIn(List.map aux_letrec_binding cdrecbinds, aux code1)
    | CdLetNonRecIn(cdpat, code1, code2)   -> LetNonRecIn(aux_pattern cdpat, aux code1, aux code2)
    | CdFunction(symb_labmap, cdpatbr)     -> Function(symb_labmap |> LabelMap.map CodeSymbol.unlift, aux_pattern_branch cdpatbr)
    | CdApply(code_labmap, code1, code2)   -> Apply(code_labmap |> LabelMap.map aux, aux code1, aux code2)
    | CdIfThenElse(code1, code2, code3)    -> IfThenElse(aux code1, aux code2, aux code3)
    | CdRecord(cdasc)                      -> Record(Assoc.map_value aux cdasc)
    | CdAccessField(code1, fldnm)          -> AccessField(aux code1, fldnm)
    | CdUpdateField(code1, fldnm, code2)   -> UpdateField(aux code1, fldnm, aux code2)
    | CdLetMutableIn(symb, code1, code2)   -> LetMutableIn(CodeSymbol.unlift symb, aux code1, aux code2)
    | CdOverwrite(symb, code1)             -> Overwrite(CodeSymbol.unlift symb, aux code1)
    | CdDereference(code1)                 -> Dereference(aux code1)
    | CdPatternMatch(rng, code1, cdpatbrs) -> PatternMatch(rng, aux code1, List.map aux_pattern_branch cdpatbrs)
    | CdConstructor(constrnm, code1)       -> NonValueConstructor(constrnm, aux code1)
    | CdTuple(codes)                       -> PrimitiveTuple(TupleList.map aux codes)
    | CdMathList(codes)                    -> BackendMathList(List.map aux codes)
    | CdModule(code1, code2)               -> Module(aux code1, aux code2)
#include "__unliftcode.gen.ml"

  and aux_letrec_binding (CdLetRecBinding(symb, cdpatbr)) =
    LetRecBinding(CodeSymbol.unlift symb, aux_pattern_branch cdpatbr)

  and aux_pattern_branch = function
    | CdPatternBranch(cdpat, code)            -> PatternBranch(aux_pattern cdpat, aux code)
    | CdPatternBranchWhen(cdpat, code, codeB) -> PatternBranchWhen(aux_pattern cdpat, aux code, aux codeB)

  and aux_pattern = function
    | CdPUnitConstant             -> PUnitConstant
    | CdPBooleanConstant(b)       -> PBooleanConstant(b)
    | CdPIntegerConstant(n)       -> PIntegerConstant(n)
    | CdPStringConstant(s)        -> PStringConstant(s)
    | CdPListCons(cdpat1, cdpat2) -> PListCons(aux_pattern cdpat1, aux_pattern cdpat2)
    | CdPEndOfList                -> PEndOfList
    | CdPTuple(cdpats)            -> PTuple(TupleList.map aux_pattern cdpats)
    | CdPWildCard                 -> PWildCard
    | CdPVariable(symb)           -> PVariable(CodeSymbol.unlift symb)
    | CdPAsVariable(symb, cdpat)  -> PAsVariable(CodeSymbol.unlift symb, aux_pattern cdpat)
    | CdPConstructor(ctor, cdpat) -> PConstructor(ctor, aux_pattern cdpat)

  in
  aux code


let unlift_code_bindings (codebinds : code_binding list) : binding list =
  failwith "TODO: Types.unlift_code_bindings"


module MathContext
: sig
    type t
    val make : input_context -> t
    val context_for_text : t -> input_context
    val context_main : t -> HorzBox.context_main
    val convert_math_variant_char : input_context -> Uchar.t -> HorzBox.math_kind * Uchar.t
    val color : t -> color
    val set_color : color -> t -> t
    val enter_script : t -> t
    val math_char_class : t -> HorzBox.math_char_class
    val set_math_char_class : HorzBox.math_char_class -> t -> t
    val is_in_base_level : t -> bool
    val actual_font_size : t -> (HorzBox.math_font_abbrev -> FontFormat.math_decoder) -> length
    val base_font_size : t -> length
    val math_font_abbrev : t -> HorzBox.math_font_abbrev
  end
= struct
    type level =
      | BaseLevel
      | ScriptLevel
      | ScriptScriptLevel

    type t =
      {
        mc_font_abbrev    : HorzBox.math_font_abbrev;
        mc_base_font_size : length;
        mc_level_int      : int;
        mc_level          : level;
        context_for_text  : input_context;
      }

    let make (ictx : input_context) : t =
      let (ctx, _) = ictx in
        {
          mc_font_abbrev    = ctx.HorzBox.math_font;
          mc_base_font_size = ctx.HorzBox.font_size;
          mc_level_int      = 0;
          mc_level          = BaseLevel;
          context_for_text  = ictx;
        }

    let convert_math_variant_char ((ctx, _) : input_context) (uch : Uchar.t) =
      let open HorzBox in
      let mcclsmap = ctx.math_variant_char_map in
      let mccls = ctx.math_char_class in
      let mkmap = ctx.math_class_map in
      match mkmap |> HorzBox.MathClassMap.find_opt uch with
      | Some(uchaft, mk) ->
          (mk, uchaft)

      | None ->
          begin
            match mcclsmap |> HorzBox.MathVariantCharMap.find_opt (uch, mccls) with
            | Some((uchaft, mk)) -> (mk, uchaft)
            | None               -> (MathOrdinary, uch)
          end

    let context_for_text (mctx : t) =
      mctx.context_for_text
        (* temporary; maybe should update font size *)

    let context_main (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx

    let color (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx.HorzBox.text_color

    let set_color (color : color) (mctx : t) =
      let (ctx, v) = mctx.context_for_text in
      let ctxnew = { ctx with HorzBox.text_color = color; } in
        { mctx with context_for_text = (ctxnew, v); }

    let math_char_class (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx.HorzBox.math_char_class

    let set_math_char_class mccls (mctx : t) =
      let (ctx, v) = mctx.context_for_text in
      let ctxnew = { ctx with HorzBox.math_char_class = mccls } in
        { mctx with context_for_text = (ctxnew, v) }

    let enter_script mctx =
      let levnew = mctx.mc_level_int + 1 in
      match mctx.mc_level with
      | BaseLevel         -> { mctx with mc_level = ScriptLevel;       mc_level_int = levnew; }
      | ScriptLevel       -> { mctx with mc_level = ScriptScriptLevel; mc_level_int = levnew; }
      | ScriptScriptLevel -> { mctx with                               mc_level_int = levnew; }

    let is_in_base_level mctx =
      match mctx.mc_level with
      | BaseLevel -> true
      | _         -> false

    let actual_font_size mctx (mdf : HorzBox.math_font_abbrev -> FontFormat.math_decoder) =
      let bfsize = mctx.mc_base_font_size in
      let md = mdf mctx.mc_font_abbrev in
      let mc = FontFormat.get_math_constants md in
      match mctx.mc_level with
      | BaseLevel         -> bfsize
      | ScriptLevel       -> bfsize *% mc.FontFormat.script_scale_down
      | ScriptScriptLevel -> bfsize *% mc.FontFormat.script_script_scale_down

    let base_font_size mctx =
      mctx.mc_base_font_size

    let math_font_abbrev mctx =
      mctx.mc_font_abbrev

  end


type math_context = MathContext.t


(*

let string_of_record_type (type a) (type b) (f : (a, b) typ -> string) (asc : ((a, b) typ) Assoc.t) =
  let rec aux lst =
    match lst with
    | []                     -> " -- "
    | (fldnm, tystr) :: []   -> fldnm ^ " : " ^ (f tystr)
    | (fldnm, tystr) :: tail -> fldnm ^ " : " ^ (f tystr) ^ "; " ^ (aux tail)
  in
    "(|" ^ (aux (Assoc.to_list asc)) ^ "|)"


let string_of_kind (kd : kind) =
  match kd with
  | UniversalKind   -> "U"


let rec string_of_type_basic tvf orvf tystr : string =
  let iter = string_of_type_basic tvf orvf in
  let (rng, tymain) = tystr in
  let qstn = if Range.is_dummy rng then "%" else "" in
    match tymain with
    | BaseType(EnvType)     -> "env" ^ qstn
    | BaseType(UnitType)    -> "unit" ^ qstn
    | BaseType(BoolType)    -> "bool" ^ qstn
    | BaseType(IntType)     -> "int" ^ qstn
    | BaseType(FloatType)   -> "float" ^ qstn
    | BaseType(StringType)  -> "string" ^ qstn
    | BaseType(TextRowType) -> "inline-text" ^ qstn
    | BaseType(TextColType) -> "block-text" ^ qstn
    | BaseType(BoxRowType)  -> "inline-boxes" ^ qstn
    | BaseType(BoxColType)  -> "block-boxes" ^ qstn
    | BaseType(ContextType) -> "context" ^ qstn
    | BaseType(PrePathType) -> "pre-path" ^ qstn
    | BaseType(PathType)    -> "path" ^ qstn
    | BaseType(LengthType)  -> "length" ^ qstn
    | BaseType(GraphicsType) -> "graphics" ^ qstn
    | BaseType(ImageType)    -> "image" ^ qstn
    | BaseType(DocumentType) -> "document" ^ qstn
    | BaseType(MathType)     -> "math" ^ qstn
    | BaseType(RegExpType)   -> "regexp" ^ qstn
    | BaseType(TextInfoType) -> "text-info" ^ qstn
    | BaseType(InputPosType) -> "input-position" ^ qstn

    | DataType(tyargs, tyid) ->
        (string_of_type_argument_list_basic tvf orvf tyargs) ^ (TypeID.show tyid) (* temporary *) ^ "@" ^ qstn

    | FuncType(optrow, tydom, tycod) ->
        let stropts = string_of_option_row_basic tvf orvf optrow in
        let strdom = iter tydom in
        let strcod = iter tycod in
          stropts ^
          begin match tydom with
          | (_, FuncType(_, _, _)) -> "(" ^ strdom ^ ")"
          | _                      -> strdom
          end ^ " ->" ^ qstn ^ " " ^ strcod

    | ListType(tycont) ->
        let strcont = iter tycont in
        let (_, tycontmain) = tycont in
          begin match tycontmain with
          | FuncType(_, _, _)
          | ProductType(_)
          | ListType(_)
          | RefType(_)
          | DataType(_ :: _, _)
(*          | TypeSynonym(_ :: _, _, _) *)
              -> "(" ^ strcont ^ ")"
          | _ -> strcont
          end ^ " list" ^ qstn

    | RefType(tycont) ->
        let strcont = iter tycont in
        let (_, tycontmain) = tycont in
          begin match tycontmain with
          | FuncType(_, _, _)
          | ProductType(_)
          | ListType(_)
          | RefType(_)
          | DataType(_ :: _, _)
              -> "(" ^ strcont ^ ")"

          | _ -> strcont
          end ^ " ref" ^ qstn

    | CodeType(tysub) ->
        let strsub = iter tysub in
        let (_, tysubmain) = tysub in
        "&" ^ begin
          match tysubmain with
          | BaseType(_)
          | DataType([], _) -> strsub

          | _ -> "(" ^ strsub ^ ")"
        end

    | ProductType(tys) ->
        tys |> TupleList.to_list |> string_of_type_list_basic tvf orvf

    | TypeVariable(tvi) ->
        tvf qstn tvi

    | RecordType(asc) ->
        string_of_record_type iter asc

    | HorzCommandType(tylist) ->
        let slist = List.map (string_of_command_argument_type tvf orvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] horz-command"

    | VertCommandType(tylist)   ->
        let slist = List.map (string_of_command_argument_type tvf orvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] vert-command"

    | MathCommandType(tylist)   ->
        let slist = List.map (string_of_command_argument_type tvf orvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] math-command"


and string_of_option_row_basic tvf orvf = function
  | OptionRowEmpty -> ""

  | OptionRowVariable(orvi) -> orvf orvi

  | OptionRowCons(ty, tail) ->
      let strtysub = string_of_type_basic tvf orvf ty in
      let strty =
        let (_, tymain) = ty in
        match tymain with
        | FuncType(_, _, _)
        | ProductType(_)
        | ListType(_)
        | RefType(_)
        | DataType(_ :: _, _)
          -> "(" ^ strtysub ^ ")"

        | _ -> strtysub
      in
      strty ^ "?-> " ^ (string_of_option_row_basic tvf orvf tail)


and string_of_command_argument_type tvf orvf = function
  | MandatoryArgumentType(ty) -> string_of_type_basic tvf orvf ty
  | OptionalArgumentType(ty)  -> "(" ^ (string_of_type_basic tvf orvf ty) ^ ")?"


and string_of_type_argument_list_basic tvf orvf tyarglist =
  match tyarglist with
  | []           -> ""
  | head :: tail ->
      let strhd = string_of_type_basic tvf orvf head in
      let strtl = string_of_type_argument_list_basic tvf orvf tail in
      let (_, headmain) = head in
        begin
          match headmain with
          | FuncType(_, _, _)
          | ProductType(_)
          | ListType(_)
          | RefType(_)
          | DataType(_ :: _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end ^ " " ^ strtl


and string_of_type_list_basic tvf orvf tylist =
  match tylist with
  | []           -> ""
  | head :: []   ->
      let strhd = string_of_type_basic tvf orvf head in
      let (_, headmain) = head in
        begin
          match headmain with
          | ProductType(_)
          | FuncType(_, _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end
  | head :: tail ->
      let strhd = string_of_type_basic tvf orvf head in
      let strtl = string_of_type_list_basic tvf orvf tail in
      let (_, headmain) = head in
        begin
          match headmain with
          | ProductType(_)
          | FuncType(_, _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end ^ " * " ^ strtl


let rec tvf_mono qstn tv =
  match tv with
  | Updatable(tvuref) ->
      begin
        match !tvuref with
        | MonoLink(tyl)  -> "$(" ^ (string_of_mono_type_basic tyl) ^ ")"
        | MonoFree(tvid) -> "'" ^ (FreeID.show tvid) ^ qstn
      end

  | MustBeBound(mbbid) ->
      MustBeBoundID.show mbbid


and orvf_mono (UpdatableRow(orvref)) =
  match !orvref with
  | MonoORFree(orv)    -> (FreeRowID.show_direct orv) ^ "?-> "
  | MonoORLink(optrow) -> string_of_option_row_basic tvf_mono orvf_mono optrow


and string_of_mono_type_basic ty =
    string_of_type_basic tvf_mono orvf_mono ty


let rec string_of_poly_type_basic (Poly(pty)) =
  let tvf_poly qstn ptvi =
    match ptvi with
    | PolyBound(bid) ->
        "'#" ^ (BoundID.show bid) ^ qstn

    | PolyFree(tvref) -> tvf_mono qstn tvref
  in
  let ortvf orvi =
    match orvi with
    | PolyORFree(orvref) -> orvf_mono orvref
  in
    string_of_type_basic tvf_poly ortvf pty


let kind_type_arguments (uktyargs : untyped_unkinded_type_argument list) (constrntcons : constraints) : untyped_type_argument list =
  uktyargs |> List.map (fun (rng, tyvarnm) ->
    match List.assoc_opt tyvarnm constrntcons with
    | Some(mkd) -> (rng, tyvarnm, mkd)
    | None      -> (rng, tyvarnm, MUniversalKind)
  )

*)
