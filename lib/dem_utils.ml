open Async.Std

let read_form body =
  Cohttp_async.Body.to_string body
  >>= fun body_str ->
  return (Uri.query_of_encoded body_str)
