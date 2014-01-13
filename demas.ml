open Core.Std
open Async.Std
open Async_extra
open Cohttp
open Cohttp_async
open Sexplib.Std

type params = Ouija.params

type handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               Server.response Deferred.t with sexp_of

type t = {get: handler Ouija.t;
          head: handler Ouija.t;
          delete: handler Ouija.t;
          post: handler Ouija.t;
          put: handler Ouija.t;
          patch: handler Ouija.t;
          options: handler Ouija.t;
          routing_error_handler: handler option} with sexp_of

let get sys uri_spec handler =
  {sys with get = Ouija.insert_handler sys.get uri_spec handler}

let head sys uri_spec handler =
  {sys with head = Ouija.insert_handler sys.head uri_spec handler}

let delete sys uri_spec handler =
  {sys with delete = Ouija.insert_handler sys.delete uri_spec handler}

let post sys uri_spec handler =
  {sys with post = Ouija.insert_handler sys.post uri_spec handler}

let put sys uri_spec handler =
  {sys with put = Ouija.insert_handler sys.put uri_spec handler}

let patch sys uri_spec handler =
  {sys with patch = Ouija.insert_handler sys.patch uri_spec handler}

let options sys uri_spec handler =
  {sys with options = Ouija.insert_handler sys.patch uri_spec handler}

let set_routing_error_handler sys error_handler =
  {sys with routing_error_handler = Some error_handler}

let base_system = {get = Ouija.init '/';
                   head = Ouija.init '/';
                   delete = Ouija.init '/';
                   post = Ouija.init '/';
                   put = Ouija.init '/';
                   patch = Ouija.init '/';
                   options = Ouija.init '/';
                   routing_error_handler = None}


let default_error_handler ~body address req =
  ignore body;
  ignore address;
  ignore req;
  Server.respond_with_string ~headers:(Header.init ()) ~code:(`Code 404)
                             "Route not found"

let error_handler sys ~body address params req =
  match sys.routing_error_handler with
  | Some handler ->
     handler ~body address params req
  | None ->
     default_error_handler ~body address req

let get_node sys req =
  match Request.meth req with
  | `GET -> sys.get
  | `POST -> sys.post
  | `HEAD -> sys.head
  | `DELETE -> sys.delete
  | `PATCH -> sys.patch
  | `PUT -> sys.put
  | `OPTIONS -> sys.options

let server sys ~body address req =
  let uri = Uri.path (Request.uri req) in
  let node = get_node sys req in
  match Ouija.resolve_path node uri with
  | [] -> error_handler sys ~body address [] req
  | (params, handler)::_ -> handler ~body address params req

let listen_to_any port =
  Tcp.Where_to_listen.create
    ~socket_type:Socket.Type.tcp
    ~address:(Socket.Address.Inet.create_bind_any ~port:port)
    ~listening_on:(fun (`Inet (_, port)) -> port)

let listen_to_ip ip port =
  Tcp.Where_to_listen.create
    ~socket_type:Socket.Type.tcp
    ~address:(Socket.Address.Inet.create (Unix.Inet_addr.of_string ip)
                                         ~port:port)
    ~listening_on:(fun (`Inet (_, port)) -> port)

let serve ?listen_on
          ?(max_connections = 10)
          ?(max_pending_connections = 10)
          ?(on_handler_error = `Raise)
          system port =
  let listen_target = match listen_on with
    | Some ip -> listen_to_ip ip port
    | None -> listen_to_any port in
  Server.create ~max_connections
                ~max_pending_connections
                ~on_handler_error
                listen_target (server system)


let to_string system =
  Sexp.to_string (sexp_of_t system)
