open Core.Std
open Async.Std
open Async_extra
open Cohttp
open Cohttp_async

type params = Ouija.params

type ('state) handler = body:Cohttp_async.Body.t ->
  Socket.Address.Inet.t ->
  'state ->
  params ->
  Request.t ->
  ('state * Server.response) Deferred.t with sexp_of

type ('state) context = {mutable state: 'state;
                         handler: 'state handler} with sexp_of

type ('state) t = {default: 'state;
                   get: 'state context Ouija.t sexp_opaque;
                   head: 'state context Ouija.t sexp_opaque;
                   delete: 'state context Ouija.t sexp_opaque;
                   post: 'state context Ouija.t sexp_opaque;
                   put: 'state context Ouija.t sexp_opaque;
                   patch: 'state context Ouija.t sexp_opaque;
                   options: 'state context Ouija.t sexp_opaque;
                   routing_error_handler: 'state context Option.t} with sexp_of

let insert_handler ouija route state handler =
  Ouija.insert ouija route {state; handler}

let get sys ~route ~init ~handler =
  {sys with get = insert_handler sys.get route init handler}

let list = get
let retrieve = get

let head sys ~route ~init ~handler =
  {sys with head = insert_handler sys.head route init handler}

let delete sys ~route ~init ~handler =
  {sys with delete = insert_handler sys.delete route init handler}

let post sys ~route ~init ~handler =
  {sys with post = insert_handler sys.post route init handler}

let create = post

let put sys ~route ~init ~handler =
  {sys with put = insert_handler sys.put route init handler}

let replace = put

let patch sys ~route ~init ~handler =
  {sys with patch = insert_handler sys.patch route init handler}

let options sys ~route ~init ~handler =
  {sys with options = insert_handler sys.options route init handler}

let set_routing_error_handler sys ~init ~handler =
  {sys with routing_error_handler = Some {state=init; handler}}

let init ~default = {default = default;
                     get = Ouija.init '/';
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
  | Some ctx ->
    ctx.handler ~body address ctx.state params req
    >>= fun (state', response) ->
    ctx.state <- state';
    return response
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
  | [] ->
    error_handler sys ~body:body address [] req
  | (params, ctx)::_ ->
    ctx.handler ~body:body address ctx.state params req
    >>= fun (state', response) ->
    ctx.state <- state';
    return response

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
