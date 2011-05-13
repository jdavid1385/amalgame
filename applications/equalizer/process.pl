:- module(eq_process,
	  []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(semweb/rdf_label)).
:- use_module(user(user_db)).
:- use_module(library(amalgame/expand_graph)).
:- use_module(eq_util).
:- use_module(stats).

:- setting(precompute_mapping, boolean, true,
	   'When true mappings are computed in the background').

:- http_handler(amalgame(data/addprocess), http_add_process, []).
:- http_handler(amalgame(date/updatenode), http_update_node, []).
:- http_handler(amalgame(date/deletenode), http_delete_node, []).

:- rdf_meta
	new_output(r, r,r,r),
	output_type(r,r).

http_add_process(Request) :-
	authorized(write(default, _)),
	http_parameters(Request,
			[ input(Input,
				[uri,
				 optional(true),
				 description('URI of input mapping')]),
			  source(Source,
				 [uri,
				  optional(true),
				  description('URI of the source')]),
			  target(Target,
				 [uri,
				  optional(true),
				  description('URI of the target')]),
			  exclude(Excludes,
				  [uri,
				   zero_or_more,
				   description('List of mappings to exclude')]),
			  process(Process,
				  [uri,
				   description('URI of the process')]),
			  alignment(Alignment,
				    [uri,
				     description('URI of the alignment graph to which the process is added')]),
			  update(Update,
				 [boolean, default(false),
				  descrption('When set to true process is updated with new parameters')])
			],
			[form_data(Params0)]),
	subtract(Params0, [input=_,source=_,target=_,process=_,alignment=_,exclude=_,update=_], Params),
	(   Update == true
	->  update_process(Process, Alignment, Params)
	;   ((nonvar(Source), nonvar(Target)) ; nonvar(Input))
	->  new_process(Process, Alignment, Source, Target, Input, Excludes, Params)
	;   true
	),
 	js_alignment_nodes(Alignment, Nodes),
	reply_json(json([nodes=json(Nodes)])).


%%	update_process(+Process, +Alignment, +Params)
%
%	Update the parameters of Process.
%
%	@TBD only removed cached results that depend on Process.

update_process(Process, Graph, Params) :-
	clean_dependent_cache(Process),
	uri_query_components(Search, Params),
	rdf_transaction((rdf_retractall(Process, amalgame:parameters, _),
			 rdf_assert(Process, amalgame:parameters, literal(Search), Graph)
			)).

clean_dependent_cache(_Process) :-
	flush_mapping_stats_cache.

%%	new_process(Process, +Alignment, ?Source, ?Target, ?Input,
%%	?Excludes, +Params)
%
%	Create new amalgame process.

new_process(Process, Alignment, Source, Target, Input, Excludes, Params) :-
	rdf_bnode(URI),
	rdf_transaction((
			 assert_process(URI, Process, Alignment, Params),
			 assert_user_provenance(URI, Alignment),
			 assert_input(URI, Alignment, Source, Target, Input),
			 assert_output(URI, Process, Alignment),
			 assert_excludes(Excludes, URI, Alignment)
			)).

assert_input(Process, Graph, Source, Target, _Input) :-
 	nonvar(Source),
	nonvar(Target),
	!,
	rdf_assert(Process, amalgame:source, Source, Graph),
	rdf_assert(Process, amalgame:target, Target, Graph).
assert_input(Process, Graph, _Source, _Target, Input) :-
 	rdf_assert(Process, amalgame:input, Input, Graph).

assert_excludes([], _, _).
assert_excludes([URI|URIs], Process, Graph) :-
	rdf_assert(Process, amalgame:exclude, URI, Graph),
	assert_excludes(URIs, Process, Graph).

assert_process(Process, Type, Graph, Params) :-
	process_label(Type, Label),
	uri_query_components(Search, Params),
 	rdf_assert(Process, rdf:type, Type, Graph),
	rdf_assert(Process, rdfs:label, Label, Graph),
	rdf_assert(Process, amalgame:parameters, literal(Search), Graph).

assert_output(Process, Type, Graph) :-
	rdfs_subclass_of(Type, amalgame:'MappingSelecter'),
	!,
	rdf_equal(amalgame:'Mapping', OutputClass),
	new_output(OutputClass, Process, amalgame:selectedBy, Graph),
	new_output(OutputClass, Process, amalgame:discardedBy, Graph),
	new_output(OutputClass, Process, amalgame:undecidedBy, Graph).
assert_output(Process, Type, Graph) :-
	output_type(Type, OutputClass),
	new_output(OutputClass, Process, opmv:wasGeneratedBy, Graph).

new_output(Type, Process, P, Graph) :-
	rdf_bnode(OutputURI),
	rdf_assert(OutputURI, rdf:type, Type, Graph),
        rdf_assert(OutputURI, P, Process, Graph),
	(   setting(precompute_mapping, true)
	->  debug(eq, 'precompute ~w', [OutputURI]),
	    thread_create(expand_mapping(OutputURI, _), _,
			  [ detached(true) ])
	;   true
	).

output_type(ProcessType, skos:'ConceptScheme') :-
	rdfs_subclass_of(ProcessType, amalgame:'VocabSelecter'),
	!.
output_type(_ProcessType, amalgame:'Mapping').


process_label(P, Lit) :-
	(   rdf_label(P, L)
	->  Lit = L
	;   rdf_global_id(_:Local, P),
	    Lit = literal(Local)
	).



%%	http_update_node(+Request)
%
%	Change properties of a URI in Alignment and return the new
%	nodes in Alignment.

http_update_node(Request) :-
	authorized(write(default, _)),
	http_parameters(Request,
			[ alignment(Alignment,
				    [uri,
				     description('URI of alignment')
				    ]),
			  uri(URI,
				[uri,
 				 description('URI of input resource')]),
			  label(Label,
				 [optional(true), description('New label')]),
			  status(Status,
				 [uri, optional(true), description('New status')])
 			]),
	rdf_transaction(update_node_props([label=Label, status=Status], URI, Alignment)),
  	js_alignment_nodes(Alignment, Nodes),
	reply_json(json([nodes=json(Nodes)])).

update_node_props([], _, _).
update_node_props([Type=Value|Ts], URI, Alignment) :-
	(   nonvar(Value)
	->  update_node_prop(Type, Value, URI, Alignment)
	;   true
	),
	update_node_props(Ts, URI, Alignment).

update_node_prop(label, Label, URI, Alignment) :-
	rdf_retractall(URI, rdfs:label, _),
	rdf_assert(URI, rdfs:label, literal(Label), Alignment).
update_node_prop(status, Status, URI, Alignment) :-
	rdf_retractall(URI, amalgame:status, _),
	rdf_assert(URI, amalgame:status, Status, Alignment).


%%	http_delete_node(+Request)
%
%	delete URI in Alignment and all that are connected to it and
%	return the new nodes in Alignment.

http_delete_node(Request) :-
	authorized(write(default, _)),
	http_parameters(Request,
			[ alignment(Alignment,
				    [uri,
				     description('URI of alignment')
				    ]),
			  uri(URI,
				[uri,
 				 description('URI of input resource')])
  			]),
 	rdf_transaction((process_retract(URI, Alignment),
			 node_retract(URI, Alignment)
			)),
   	js_alignment_nodes(Alignment, Nodes),
	reply_json(json([nodes=json(Nodes)])).

node_retract(URI, Alignment) :-
	rdf_retractall(URI, _, _, Alignment),
 	forall(rdf(S,_,URI,Alignment),
	       node_retract(S, Alignment)).

process_retract(URI, Alignment) :-
	rdf_has(URI, opmv:wasGeneratedBy, P),
	findall(S, rdf_has(S, opmv:wasGeneratedBy, P), [URI]),
	!,
	rdf_retractall(P, _, _, Alignment).
process_retract(_, _).




