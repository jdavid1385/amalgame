:- module(ag_exec_process, [
			    exec_amalgame_process/7,
			    select_result_mapping/4
			   ]).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(amalgame/expand_graph)).
:- use_module(library(amalgame/map)).
:- use_module(library(ag_modules/map_merger)).

:- multifile
	exec_amalgame_process/7,
	select_result_mapping/4.

%%	select_result_mapping(+Id, +Result, +OutputType, -Mapping)
%
%	Mapping is part of (process) Result as defined by OutputType.
%
%	@param OutputType is an RDF property
%	@error existence_error(mapping_select)

select_result_mapping(_Id, mapspec(mapping(Mapping)), P, Mapping) :-
	is_list(Mapping),
	rdf_equal(amalgame:wasGeneratedBy, P).

select_result_mapping(_Id, mapspec(select(Selected, Discarded, Undecided)), OutputType, Mapping) :-
	!,
	(   rdf_equal(amalgame:selectedBy, OutputType)
	->  Mapping = Selected
	;   rdf_equal(amalgame:discardedBy, OutputType)
	->  Mapping = Discarded
	;   rdf_equal(amalgame:undecidedBy, OutputType)
	->  Mapping = Undecided
	;   throw(error(existence_error(mapping_selector, OutputType), _))
	).

select_result_mapping(Id, mapspec(overlap(List)), P, Mapping) :-
	!,
	rdf_equal(amalgame:wasGeneratedBy, P),
	(   member(Id-Mapping, List)
	->  true
	;   Mapping=[]
	).

collect_snd_input(Process, Strategy, SecInput):-
	findall(S, rdf(Process, amalgame:secondary_input, S), SecInputs),
	maplist(expand_node(Strategy), SecInputs, SecInputNF),
	merger(SecInputNF, SecInput, []).

%%	exec_amalgame_process(+Type,+Process,+Strategy,+Module,-Result,-Time,+Options)
%
%
%	Result is generated by executing Process of Type
%	in Strategy. This is to provide amalgame with a uniform interface to
%	all modules. This predicate is multifile so it is easy to add
%	new modules with different input/output parameters.
%
%       @error existence_error(mapping_process)

exec_amalgame_process(Type, Process, Strategy, Module, MapSpec, Time, Options) :-
	rdfs_subclass_of(Type, amalgame:'Matcher'),
	!,
	collect_snd_input(Process, Strategy, SecInput),
	(   rdf(Process, amalgame:source, SourceId, Strategy),
	    rdf(Process, amalgame:target, TargetId, Strategy)
	->  expand_node(Strategy, SourceId, Source),
	    expand_node(Strategy, TargetId, Target),
	    timed_call(Module:matcher(Source, Target, Mapping0, [snd_input(SecInput)|Options]), Time)
	;   rdf(Process, amalgame:input, InputId)
	->  expand_node(Strategy, InputId, MappingIn),
	    timed_call(Module:filter(MappingIn, Mapping0, [snd_input(SecInput)|Options]), Time)
	),
	merge_provenance(Mapping0, Mapping),
	MapSpec = mapspec(mapping(Mapping)).
exec_amalgame_process(Class, Process, Strategy, Module, MapSpec, Time, Options) :-
	rdfs_subclass_of(Class, amalgame:'MappingSelecter'),
	!,
	MapSpec = mapspec(select(Selected, Discarded, Undecided)),
	once(rdf(Process, amalgame:input, InputId, Strategy)),
	expand_node(Strategy, InputId, MappingIn),
	timed_call(Module:selecter(MappingIn, Selected, Discarded, Undecided, Options), Time).
exec_amalgame_process(Class, Process, Strategy, Module, MapSpec, Time, Options) :-
	rdfs_subclass_of(Class, amalgame:'MapMerger'),
	!,
	findall(Input, rdf(Process, amalgame:input, Input, Strategy), Inputs),
	maplist(expand_node(Strategy), Inputs, Expanded),
	timed_call(Module:merger(Expanded, Result, Options), Time),
	MapSpec = mapspec(mapping(Result)).
exec_amalgame_process(Class, Process, Strategy, Module, MapSpec, Time, Options) :-
	rdfs_subclass_of(Class, amalgame:'OverlapComponent'),
	!,
	findall(Input, rdf(Process, amalgame:input, Input, Strategy), Inputs),
	% We need the ids, not the values in most analyzers
	timed_call(Module:analyzer(Inputs, Process, Strategy, Result, Options), Time),
	MapSpec = mapspec(Result). % Result = overlap([..]).

exec_amalgame_process(Class, Process, Strategy, Module, Result, Time, Options) :-
	rdfs_subclass_of(Class, amalgame:'VocExclude'),
	rdf(NewVocab, amalgame:wasGeneratedBy, Process, Strategy),
	NewVocOption = new_scheme(NewVocab),
	!,
	once(rdf(Process, amalgame:input, Input, Strategy)),
	expand_node(Strategy, Input, Vocab),
	findall(S, rdf_has(Process, amalgame:secondary_input, S), Ss),
	maplist(expand_node(Strategy), Ss, Expanded),
	append(Expanded, Mapping),
	timed_call(Module:exclude(Vocab, Mapping, Result, [NewVocOption|Options]), Time).


exec_amalgame_process(Class, Process, Strategy, Module, Result, Time, Options) :-
	rdfs_subclass_of(Class, amalgame:'VocabSelecter'),
	!,
	once(rdf(Process, amalgame:input, Input, Strategy)),
	expand_node(Strategy, Input, Vocab),
	timed_call(Module:selecter(Vocab, Result, Options), Time).


exec_amalgame_process(Class, Process,_,_, _, _, _) :-
	throw(error(existence_error(mapping_process, [Class, Process]), _)).

timed_call(Goal, Time) :-
	thread_self(Me),
        thread_statistics(Me, cputime, T0),
	call(Goal),
	thread_statistics(Me, cputime, T1),
        Time is T1 - T0.

