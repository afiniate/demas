open Core.Std
open Async.Std

(**
 * Read www-form-encoded string
 *)
val read_form: Cohttp_async.Body.t ->
               (string * string list) list Deferred.t
