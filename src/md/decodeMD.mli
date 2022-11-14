
open Types

module CodeNameMap : Map.S with type key = string

type command = Range.t * (module_name list * var_name)

type command_record = {
  document           : command;
  header_default     : string;

  paragraph          : command;
  hr                 : command;
  h1                 : command;
  h2                 : command;
  h3                 : command;
  h4                 : command;
  h5                 : command;
  h6                 : command;
  ul_inline          : command;
  ul_block           : command;
  ol_inline          : command;
  ol_block           : command;
  code_block_map     : command CodeNameMap.t;
  code_block_default : command;
  blockquote         : command;
  err_block          : command;

  emph               : command;
  bold               : command;
  hard_break         : command option;
  code_default       : command;
  url                : command;
  reference          : command;
  img                : command;
  embed_block        : command;
  err_inline         : command;
}

val decode : command_record -> string -> untyped_abstract_tree
