:- module(skosmatcher,
	  [skos_find_candidates/4 % +SourceConcept, +SourceScheme, +TargetScheme, +Options, -Results
	  ]
	 ).

:- use_module(library(count)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdf_portray)).
:- use_module(library(amalgame/edoal)).
:- use_module(levenshtein).

%%	skos_find_candidates(+C, +S, +Options, -Result) is semidet.
%
%	Find all correspondences candidates for for SKOS concept C
%	from SKOS scheme S. Result is an RDF graph in (extended) EDOAL format
%
%	Options include:
%	* candidate_matchers(M): list of matcher to use, defaults to
%	[labelmatch]
%	* lang(Lang): only match labels with given language tag
%	* case_sensitive(boolean): defaults to false
%	* sourcelabel(URI): defaults to rdfs:label
%       * targetlabel(URI): defaults to rdfs:label
%	* include_qualifier(boolean): if false, exclude anything after (
%

skos_find_candidates(Source, SourceScheme, TargetScheme, Options):-
	ground(Source),
	ground(TargetScheme),
	ground(Options),

	findall(Target,
		find_candidate(Source, TargetScheme, Target, Options),
		Targets),
	sort(Targets, TargetsUnique),
	forall(member(Target, TargetsUnique),
	       (   find_label_match_methods(Source, Target, Methods, [scheme1(SourceScheme), scheme2(TargetScheme)|Options]),
		   (   Methods \= []
		   ->  assert_cell(Source, Target, [method(Methods)|Options])
		   ;   true
		   )
	       )
	      ).


% VIC: this version does not consider bracket-denoted qualifiers
find_candidate(Source, TargetScheme, Target, Options) :-
	option(include_qualifier(InclQualifier), Options, true ),
	option(candidate_matchers(Matchers), Options, [labelmatch]),
	memberchk(labelmatch, Matchers),
	option(language(Lang1),Options, _),
	option(matchacross_lang(MatchAcross), Options, _),
	option(case_sensitive(CaseSensitive), Options, false),
	rdf_equal(rdfs:label, DefaultProp),
	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),

	(   InclQualifier == true
	->  rdf_has(Source, MatchProp1, literal(lang(Lang1, Label1)))
	;   rdf_has(Source, MatchProp1, literal(lang(Lang1, LabelQual))),
	    remove_qualifier(LabelQual,Label1)),

	% If we can't match across languages, set target language to source language
	(   CaseSensitive == true
	->  rdf_has(Target, MatchProp2, literal(lang(TargetLang,Label1)))
	;   rdf_has(Target, MatchProp2, literal(exact(Label1),lang(TargetLang, _Label2)))
	),
	(   MatchAcross == false
	->  nonvar(TargetLang),
	    lang_matches(TargetLang, Lang1)
	;   true
	),
	rdf_has(Target, skos:inScheme, TargetScheme).

find_candidate(Source, TargetScheme, Target, Options) :-
	option(candidate_matchers(Matchers), Options),
	memberchk(stringdist, Matchers),
	option(language(Lang),Options, _),
	rdf_equal(rdfs:label, DefaultProp),
	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),
	option(prefixdepth(PrefLen), Options, 2),

	rdf_has(Source, MatchProp1, literal(lang(Lang1, Label1))),
	lang_matches(Lang1, Lang),
	sub_atom(Label1,0,PrefLen,_,Prefix),
	rdf_has(Target, MatchProp2, literal(prefix(Prefix), lang(Lang2,_Label2))),
	rdf_has(Target, skos:inScheme, TargetScheme),
	lang_matches(Lang2, Lang).


%%	find_label_match_methods(+Source, +Target, -Methods, +Options)
%%	is det.
%
%	True if Methods is the list of all label match methods to match
%	Source and Target.

find_label_match_methods(Source, Target, Methods, Options) :-
	findall(Method,
		find_label_match_method(Source, Target, Method, Options),
		Methods
	       ).

%%	find_label_match_method(?Source, ?Target, Method:atom) is
%%	nondet.
%
%	True if Source and Target share at least one pair that matches.
%	Details about this match are encoded in Method

find_label_match_method(Source, Target, Method, Options):-
	rdf_equal(rdfs:label, DefaultProp),
	option(include_qualifier(true), Options),
	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),
	option(matchacross_lang(MatchAcross), Options, _),
	option(language(SourceLang),Options, _),
	rdf_has(Source, MatchProp1, literal(lang(SourceLang, Label1)), RealLabel1Predicate),

        % If we can't match across languages, set target language to source language
	(   MatchAcross == false
	->  TargetLang = SourceLang
	;   true),

	rdf_has(Target, MatchProp2, literal(exact(Label1),lang(TargetLang, Label2)), RealLabel2Predicate),
	option(scheme1(Voc1), Options),
	option(scheme2(Voc2), Options),
	label_occurences(Voc1, MatchProp1, Label1, Count1),
	label_occurences(Voc2, MatchProp2, Label2, Count2),
	format(atom(Method), 'exact ~w/~w (~p:~w@~w,~p:~w@~w)',
	       [Count1, Count2,
		RealLabel1Predicate, Label1, SourceLang,
		RealLabel2Predicate, Label2, TargetLang]).


% This version is for the include_qualifier=false option
%
find_label_match_method(Source, Target, Method, Options):-
	rdf_equal(rdfs:label, DefaultProp),
	option(include_qualifier(false), Options),
	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),
	rdf_has(Source, MatchProp1, literal(lang(SourceLang, LabelQual)), RealLabel1Predicate),
	remove_qualifier(LabelQual,Label1),
	rdf_has(Target, MatchProp2, literal(exact(Label1),lang(TargetLang, Label2)), RealLabel2Predicate),
	option(scheme1(Voc1), Options),
	option(scheme2(Voc2), Options),
	label_occurences(Voc1, MatchProp1, Label1, Count1),
	label_occurences(Voc2, MatchProp2, Label2, Count2),
	format(atom(Method), 'exact qual ~w/~w (~p:~w@~w,~p:~w@~w)',
	       [Count1, Count2,
		RealLabel1Predicate, Label1, SourceLang,
		RealLabel2Predicate, Label2, TargetLang]).











% This version of asserts a match when the
% Levenshtein distance between two labels is less than a maximum
% (retrieved from stringdist_setting/2). For reasons of scalability,
% only labels with a common prefix of a certain length (also a parameter
% retrieved from stringdist_setting/2) are considered.

find_label_match_method(Source, Target, Method, Options):-
	option(candidate_matchers(Matchers), Options),
	memberchk(stringdist, Matchers),
	rdf_equal(rdfs:label, DefaultProp),
	option(sourcelabel(MatchProp1), Options, DefaultProp),
	option(targetlabel(MatchProp2), Options, DefaultProp),
	rdf_has(Source, MatchProp1, literal(lang(SourceLang, Label1)), RealLabel1Predicate),
	rdf_has(Target, MatchProp2, literal(lang(TargetLang, Label2)), RealLabel2Predicate),
	max_stringdist(Label1, Label2, 1),
	format(atom(Method), 'dist<2 (~p:~w@~w,~p:~w@~w)', [RealLabel1Predicate, Label1, SourceLang,RealLabel2Predicate, Label2, TargetLang]).

label_occurences(Voc, Prop, Label, Count) :-
        answer_count(Alt,
                    (   rdf_has(Alt, Prop, literal(lang(_,Label))),
			rdf_has(Alt, skos:inScheme, Voc)
                    ),
                    100,
                    Count).

% succeeds if Label1 and Label2 have a levenshtein distance of
% Maxdist or less after a normalization step where whitespaces and
% punctuation is removed.

max_stringdist(Label1, Label2, MaxDist):-
	labnorm(Label1, L1N),
      	labnorm(Label2, L2N),
	levenshtein(L1N,L2N,Dist),!,
	Dist =< MaxDist,!.

% Label1=Label2 case is already taken care of by running exact match
% always before the levenshtein distance ...
% max_stringdist(Label1, Label2, _MaxDist):-
% Label1 = Label2.

labnorm(L,LN):-
	downcase_atom(L, LD),
	atom_chars(LD, LC),
	delete(LC, ' ',  LC1),
	delete(LC1, ',',  LC2),
	delete(LC2, '.',  LC3),
	delete(LC3, '-',  Lchars),
	atom_chars(LN,Lchars),!.

% Removes the qualifier (space-bracket-rest suffix)
remove_qualifier(LabelQual,Label1):-
	atom_concat(Label1,B,LabelQual),
	atom_concat(' (',_B1,B),!.
remove_qualifier(L,L).
