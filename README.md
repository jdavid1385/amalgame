# amalgame
This is the AMsterdam ALignment GenerAtion MEtatool (amalgame).
This open source tool has originally been developed as part of the EuropeanaConnect and PrestoPrime projects at VU University Amsterdam.


## Objective
amalgame provides a web-based interactive platform for creating, analyzing and evaluating vocabulary alignments.  It aims to support domain experts to make alignments interactively.  To realize this it focuses on simple alignment techniques which the user understands and knows how to use, and which are sufficiently fast to be used in an interactive session.  amalgame keeps track of all the provenance related information, so that mapping experiments can be replicated later, and other users can explore the context that played a role in creating the mappings.  amalgame is implemented by using common web technology on the client (e.g. HTML,CSS,AJAX and the YUI toolkit) and SWI-Prolog's ClioPatria platform on the server.

## Installation
Amalgame is a web application build as a package in the ClioPatria semantic web server. To install, make sure you have:

1. The latest development release of SWI Prolog, at least version 7.1.x. See http://www.swi-prolog.org/Download.html
2. ClioPatria itself, see http://cliopatria.swi-prolog.org/help/Download.html
3. Once you have your ClioPatria server up and running, just install amalgame as a cpack:

        :- cpack_install(amalgame).
4. Done!


## amalgame-specific terminology:

- **Correspondence** : We define a correspondence as a relationship between two concepts.  In amalgame, the key associated data-structure is the align/3 term, that encodes a series of claims (3rd argument) about the relationship between a source (1st argument) and target concept (2nd argument).  The claims can be objective observations (such as the observation that the prefLabels of both concepts are the same) or interpretations (such as the claim that both concepts refer to the same entity or that one has a skos:broadMatch relationship to the other). Note that align/3 always denotes a 1-1 relationship, you need multiple align/3 terms to represent N-M relationships.  In PROV terms, a correspondence is too fine grained to play a direct role in a PROV graph.  However, each correspondence is part of a mapping dataset, which is a PROV Entity with associated provenance information.  For each claim about two concepts, the align/3 term may record the evidence that was used to make or support that claim.

- **Mapping** : We define a mapping as a homogeneous set of correspondences. These are homogeneous in that they make similar type of claims about their source and target concept.  Because of its homogeneous nature, we hope that evaluating only a small random subset will give reliable insights into the quality of the entire mapping. In amalgame mappings are typically represented as a list of align/3 terms.  This list can be materialized as EDOAL triples in a single named graph.  In PROV terms such a named graph is a single Entity, and all correspondences it contains have the same provenance, e.g. they have all been generated by the same sequence of processing steps.  

- **Alignment** : An alignment in amalgame is a (typically) hetereogeneous set of correspondences between two vocabularies.  Typically, an alignment is made by merging all mappings of sufficient quality into a single data set.

- **Alignment strategy** : An alignment strategy is a recipee that defines how the mappings that constitute the alignment have to be made.  It defines for all mappings the amalgame alignment modules that can create them, and their inputs.  In addition to the mappings actually used in the final alignment (these mappings are typically marked with amalgame:status amalgame:final) strategies typically also define (amalgame:intermediate) mappings that are used as input for processes generating other mappings and mappings that are explicitly not used (e.g. for lack of quality) and have been marked with amalgame:discarded.  A strategy defines a striped dependency graph between mappings (which are subclasses of prov:Entities) and amalgame modules (which are subclasses of prov:Activities).  A strategy is also a prov:Plan.

- **Provenance graph** : The dependency graph of the alignment strategy can be seen as the backbone of a PROV provenance graph.  By executing such a strategy and recording the information that is specific to that execution, one can extend this backbone into a complete PROV graph.  Vice versa, if the PROV graph recording such an execution has been extended by amalgame's strategy vocabulary, the dependency graph that forms the backbone of the PROV graph can be re-used as an amalgame alignment strategy for another run. We model a provenance graph as a prov:Bundle.

## AMALGAME motivation.

In every alignment tool several trade trade-offs to be made. Below, we make these trade-offs explicit along with the design decisions we took in developing the AMALGAME framework. 

1. Generic versus specific
Most alignment tools are hybrid tools that combine multiple alignment techniques to create alignments.  When combining techniques one can use a fixed built-in combination or let the system decide at run-time what combination is best. In both cases the result is a highly generic system that can be directly employed on any data-set that meets the required specifications.  The price for being generic is that it is very hard to exploit vocabulary-specific knowledge into the alignment process.  We prefer a generic platform that consists of generic and plug-in modules that together can be combined into an alignment tool that is highly specific for a given alignment task.  We assume that the resulting alignments will be better at the expense of more (configuration) work that needs to be done by the user of the tool.

2. Deep, complex and slow versus shallow, simple and fast
Many alignment tools aim at discovering hard to find alignments in relatively small but complex (RDFS/OWL) ontologies.  When confronted with relatively large and simply structured (SKOS) vocabularies, these systems tend to run out of memory space or take too much time to complete the alignment.  We strive to build a platform that may only find the "easy" alignments, but can do this on large vocabularies sufficiently fast to allow the user to experiment with different configurations. 

Many systems are "black boxes" that output an alignment based on the two ontologies given as the input.  How exactly the output is derived from the input remains often unclear to the end user. This makes it hard for end users to predict, before the (often expensive) alignment process has been carried out, how well the system will perform on what parts of their vocabularies.  It also makes it hard for users to estimate, after the results have been generated, what the quality is of the potentially 100.000s of correspondences generated.  The confidence measure, a number between [0..1] that many systems generate for each correspondence, is in practice often hard to interpret and of little value when evaluating large alignments.  We aim at a system that generates a clear justification for every correspondence that it has found, a justification that is useful for ranking by machines but is also interpretable by the end-user.  In order to achieve a usable level of predictability and transparency, we refrain from using techniques that are too complex to explain, potentially at the loss of precision and recall.

The resulting key requirements for AMALGAME are thus:

- Scope: focus on SKOS i.s.o. OWL/RDFS subsumption hierarchies
- Scalable in space and time: system should be able to effectively align vocabularies > 100.000 concepts
- Configurable: the user of the system should be able to configure it based on knowledge about the specific vocabularies to be matched
- Predictable: users should be able to predict the outcome of alignment process
- Transparent: users should be able to understand why a concept has been or not been mapped
- Interactive: users should be able to run alignments interactively (via a web-based interface).

## TODO

- add merge/stratified overlap to builder

## Authors
- Jan Wielemaker
- Jacco van Ossenbruggen
- Michiel Hildebrand
- Victor de Boer 

LocalWords:  amalgame's prefLabels broadMatch versa
