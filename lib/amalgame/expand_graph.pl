:- module(expand_graph,
	  [ expand_mapping/2,
	    expand_vocab/2,
	    flush_expand_cache/0,
	    flush_expand_cache/1     % +Id
	  ]).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(http/http_parameters)).
:- use_module(library(amalgame/amalgame_modules)).
:- use_module(library(amalgame/map)).

:- dynamic
	expand_cache/2.

:- setting(cache_time, integer, 1,
	   'Minimum execution time to cache results').

%%	expand_mapping(+Id, -Mapping:[align(s,t,prov)]) is det.
%
%	Generate the Mapping.
%
%	@param Id is a URI of Mapping

expand_mapping(Id, Mapping) :-
	expand_cache(Id, Mapping),
	!,
	debug_mapping_expand(cache, Id, Mapping).
expand_mapping(Id, Mapping) :-
	rdf_has(Id, opmv:wasGeneratedBy, Process, OutputType),
	expand(Id, Process, Result),
   	select_result_mapping(Result, OutputType, Mapping),
	debug_mapping_expand(Process, Id, Mapping).

%%	expand_vocab(+Id, -Concepts) is det.
%
%	Generate the Vocab.
%	@param Id is URI of a conceptscheme or an identifier for a set
%	of concepts derived by a vocabulary process,

expand_vocab(Id, Vocab) :-
	expand_cache(Id, Vocab),
	!.
expand_vocab(Id, Vocab) :-
	rdf_has(Id, opmv:wasGeneratedBy, Process),
	!,
 	expand(Id, Process, Vocab).
expand_vocab(Vocab, Vocab) :-
	rdf(Vocab, rdf:type, skos:'ConceptScheme').


%%	expand(+Id, +Process, -Result)
%
%	Expands Id to generate Result by executing Process.
%
%	Results are cached when execution tim eof process takes longer
%	then setting(cache_time).

expand(Id, Process, Result) :-
	rdf(Process, rdf:type, Type),
	amalgame_module_id(Type, Module),
	process_options(Process, Module, Options),
	thread_self(Me),
        thread_statistics(Me, cputime, T0),
	exec_amalgame_process(Type, Process, Module, Result, Options),
	thread_statistics(Me, cputime, T1),
        Time is T1 - T0,
	cache_expand_result(Time, Result, Id).

cache_expand_result(ExecTime, Result, Id) :-
	setting(cache_time, CacheTime),
	ExecTime > CacheTime,
	!,
	assert(expand_cache(Id, Result)).
cache_expand_result(_, _, _).

%%	flush_expand_cache(+Id)
%
%	Retract all cached mappings.

flush_expand_cache :-
	flush_expand_cache(_).
flush_expand_cache(Id) :-
	retractall(expand_cache(Id, _)).


%%	exec_amalgame_process(+Type, +Process, +Module, -Result,
%%	+Options)
%
%	Result is generated by executing Process of type Type.
%
%	@error existence_error(mapping_process)

exec_amalgame_process(Type, Process, Module, Mapping, Options) :-
	rdfs_subclass_of(Type, amalgame:'Matcher'),
	!,
 	rdf(Process, amalgame:source, SourceId),
	rdf(Process, amalgame:target, TargetId),
	expand_vocab(SourceId, Source),
	expand_vocab(TargetId, Target),
	call(Module:matcher, Source, Target, Mapping0, Options),
 	merge_provenance(Mapping0, Mapping).
exec_amalgame_process(Type, Process, Module, Mapping, Options) :-
	rdfs_subclass_of(Type, amalgame:'MatchFilter'),
	!,
	rdf(Process, amalgame:input, InputId),
	expand_mapping(InputId, MappingIn),
	call(Module:filter, MappingIn, Mapping0, Options),
	merge_provenance(Mapping0, Mapping).
exec_amalgame_process(Class, Process, Module, Result, Options) :-
	rdfs_subclass_of(Class, amalgame:'MappingSelecter'),
	!,
	Result = select(Selected, Discarded, Undecided),
 	rdf(Process, amalgame:input, InputId),
	expand_mapping(InputId, MappingIn),
  	call(Module:selecter, MappingIn, Selected, Discarded, Undecided, Options).
exec_amalgame_process(Class, Process, Module, VocabOut, Options) :-
	rdfs_subclass_of(Class, amalgame:'VocabSelecter'),
	!,
  	rdf(Process, amalgame:input, InputId),
	expand_vocab(InputId, VocabIn),
  	call(Module:source_select, VocabIn, VocabOut, Options).
exec_amalgame_process(Class, Process, Module, Result, Options) :-
	rdfs_subclass_of(Class, amalgame:'Merger'),
	!,

	findall(Input, rdf(Process, amalgame:input, Input), Inputs),
	maplist(expand_mapping, Inputs, Expanded),
	call(Module:merger, Expanded, Result, Options).
exec_amalgame_process(Class, Process, Module, Result, Options) :-
	rdfs_subclass_of(Class, amalgame:'VocSelecter'),
        !,
        option(type(SourceOrTarget), Options, source),
        (   SourceOrTarget = source
        ->  ExcludeOption = exclude_sources(Exclude)
        ;   ExcludeOption = exclude_targets(Exclude)
        ),
        rdf(Process, amalgame:exclude, ExcludeId),
        (   rdf(Process, amalgame:source, SourceId)
        ->  Input = scheme(SourceId),
            rdf(Process, amalgame:target, TargetId),
            TargetOption=targetvoc(TargetId)
        ;   rdf(Process, amalgame:input, InputId),
            expand_mapping(InputId, Input),
            TargetOption=noop(none)
        ),
        expand_mapping(ExcludeId, Exclude),
	call(Module:concept_selecter(Input, Result, [ExcludeOption,TargetOption])).
exec_amalgame_process(Class, Process, _, _, _) :-
	throw(error(existence_error(mapping_process, [Class, Process]), _)).


%%	select_result_mapping(+ProcessResult, +OutputType, -Mapping)
%
%	Mapping is part of ProcessResult as defined by OutputType.
%
%	@param OutputType is an RDF property
%	@error existence_error(mapping_select)

select_result_mapping(Mapping, P, Mapping) :-
	is_list(Mapping),
	rdf_equal(opmv:wasGeneratedBy, P),
	!.
select_result_mapping(select(Selected, Discarded, Undecided), OutputType, Mapping) :-
	!,
	(   rdf_equal(amalgame:selectedBy, OutputType)
	->  Mapping = Selected
	;   rdf_equal(amalgame:discardedBy, OutputType)
	->  Mapping = Discarded
	;   rdf_equal(amalgame:untouchedBy, OutputType)
	->  Mapping = Undecided
	).
select_result_mapping(_, OutputType, _) :-
	throw(error(existence_error(mapping_selector, OutputType), _)).


%%	process_options(+Process, +Module, -Options)
%
%	Options are the instantiated parameters for Module based on the
%	parameters string in Process.

process_options(Process, Module, Options) :-
	rdf(Process, amalgame:parameters, literal(ParamString)),
	!,
	module_options(Module, Options, Parameters),
	parse_url_search(ParamString, Search),
	Request = [search(Search)] ,
	http_parameters(Request, Parameters).
process_options(_, _, []).


%%	module_options(+Module, -Options, -Parameters)
%
%	Options  are  all  option  clauses    defined   for  Module.
%	Parameters is a specification list for http_parameters/3.
%	Module:parameter is called as:
%
%	    parameter(Name, Properties, Description)
%
%	Name is the name of the	the option, The Properties are as
%	supported by http_parameters/3.	Description is used by the help
%	system.

module_options(Module, Options, Parameters) :-
	findall(O-P,
		( call(Module:parameter, Name, Type, Default, _Description),
		  O =.. [Name, Value],
		  P =.. [Name, Value, [Type, default(Default)]]
		),
		Pairs),
	pairs_keys_values(Pairs, Options, Parameters).


debug_mapping_expand(Process, Id, Mapping) :-
	debug(ag_expand),
	!,
	length(Mapping, Count),
	(   Process == cache
	->  debug(ag_expand, 'Mapping ~p (~w) taken from cache',
	      [Id, Count])
	;   debug(ag_expand, 'Mapping ~p (~w) generated by process ~p',
	      [Id, Process, Count])
	).
debug_mapping_expand(_, _, _).
