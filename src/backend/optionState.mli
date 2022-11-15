
open MyUtil

type output_mode =
  | PdfMode
  | TextMode of string list

type build_state = {
  input_file             : abs_path;
  output_file            : abs_path option;
  output_mode            : output_mode;
  page_number_limit      : int;
  debug_show_bbox        : bool;
  debug_show_space       : bool;
  debug_show_block_bbox  : bool;
  debug_show_block_space : bool;
  debug_show_overfull    : bool;
  type_check_only        : bool;
  bytecomp               : bool;
}

type command_state =
  | BuildState of build_state
  | SolveState

type state = {
  command_state      : command_state;
  extra_config_paths : (string list) option;
  show_full_path     : bool;
  no_default_config  : bool;
}

val set : state -> unit

val get : unit -> state

val get_input_file              : unit -> abs_path
val get_output_file             : unit -> abs_path option
val get_extra_config_paths      : unit -> string list option
val get_output_mode             : unit -> output_mode
val get_page_number_limit       : unit -> int
val does_show_full_path         : unit -> bool
val does_debug_show_bbox        : unit -> bool
val does_debug_show_space       : unit -> bool
val does_debug_show_block_bbox  : unit -> bool
val does_debug_show_block_space : unit -> bool
val does_debug_show_overfull    : unit -> bool
val is_type_check_only          : unit -> bool
val is_bytecomp_mode            : unit -> bool
val use_no_default_config       : unit -> bool

val job_directory : unit -> string

val is_text_mode : unit -> bool
