:- module(preloaded_matcher,[]).

:- use_module(library(semweb/rdf_db)).
:- use_module(library(amalgame/map)).
:- use_module(library(amalgame/vocabulary)).

:- public amalgame_module/1.
:- public matcher/4.
:- public parameter/4.

amalgame_module(amalgame:'SelectPreLoaded').

parameter(name, 'atom', 'no default',
	  'url of named mapping graph').

matcher(Source, Target, Mapping, Options) :-
	option(name(Graph), Options),
	findall(Correspondence,
		c_from_graph(Correspondence, Source, Target, Graph),
		Mapping).


c_from_graph(align(S,T,P), Source, Target, Graph) :-
	has_correspondence(align(S,T,P), Graph),
	vocab_member(S, Source),
	vocab_member(T, Target).



