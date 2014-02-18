open Async.Std

let read_form body =
  Cohttp_async.body_to_string body
  >>= fun body_str ->
  return (Uri.query_of_encoded body_str)

let require_or_bad_request ?(body = "") vopt ~f =
  match vopt with
  | Some v ->
     f v
  | None ->
     Cohttp_async.Server.respond_with_string ~code:`Bad_request body
