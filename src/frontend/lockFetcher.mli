
open MyUtil
open PackageSystemBase

type error =
  | FailedToFetchTarball of {
      lock_name     : lock_name;
      exit_status   : int;
      fetch_command : string;
    }
  | FailedToExtractTarball of {
      lock_name          : lock_name;
      exit_status        : int;
      extraction_command : string;
    }

val main :
  wget_command:string ->
  tar_command:string ->
  cache_directory:abs_path ->
  implementation_spec -> (unit, error) result
