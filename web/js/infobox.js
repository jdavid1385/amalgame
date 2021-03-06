YUI.add('infobox', function(Y) {

	var Lang = Y.Lang,
		Node = Y.Node;

	var NODE_INFO = Y.one("#infocontent"),
		NODE_PROPS = Y.one("#properties"),
		NODE_DELETE = Y.one("#delete"),
		NODE_EVAL = Y.one("#evaluate"),
		NODE_UPDATE = Y.one("#update"),
		NODE_HINT = Y.one("#hint"),
		NODE_TYPE = Y.one("#type"),
		NODE_URI = Y.one("#uri"),
		NODE_NAMESPACE = Y.one("#namespace"),
		NODE_NAMESPACE_ROW = Y.one("#publish_ns"),
		NODE_LABEL = Y.one("#label"),
		NODE_ABBREV = Y.one("#abbrev"),
		NODE_COMMENT = Y.one("#comment"),
		NODE_STATUS_ROW = Y.one("#statusrow"),
		NODE_STATUS = Y.one("#status"),
		NODE_REL = Y.one("#default_relation"),
		NODE_REL_ROW = Y.one("#relationrow");

	function InfoBox(config) {
		InfoBox.superclass.constructor.apply(this, arguments);
	}
	InfoBox.NAME = "infobox";
	InfoBox.ATTRS = {
		srcNode: {
			value: null
		},
		loading: {
			value:false,
			validator:function(val) {
				return Lang.isBoolean(val);
			}
		},
		readonly: {
			value: true
		},
		lastAction: {
			     value: null
			     },
		strategy: {
			value: null
		},
		paths : {
			value: null
		},
		nodes : {
			value: null
		},
		focus: {
			value: null
		}
	};

	Y.extend(InfoBox, Y.Base, {

		initializer : function(config) {
			var content = this.get("srcNode"),
				focus = this.get("focus"),
				nodes = this.get("nodes");

			this.bd = content.one('.bd');
			this.loadingNode = content.one('.loading');
			this.emptyNode = content.one('.empty');
			this.bd.addClass("hidden");

			NODE_DELETE.on("click", this._onNodeDelete, this);
			NODE_UPDATE.on("click", this._onNodeUpdate, this);
			NODE_EVAL.on("click", this._onNodeEvaluate, this);

			this.after('focusChange', this.syncUI, this);
			this.on('loadingChange', this._onLoadingChange, this);

			this.syncUI();
		},

		syncUI : function() {
			var oSelf = this,
				paths = this.get("paths"),
				focus = this.get("focus"),
				strategy = this.get("strategy");

			// update the node properties that we already have
			this._setProperties(focus);

			// fetch new info
			this.set("loading", true);
			Y.io(paths.info, {
				data: {
					'url':focus.uri,
					'strategy':strategy
				},
				on:{
					success:function(e,r) {
						NODE_PROPS.setContent(r.responseText);
						oSelf._updateParameters();
						oSelf.set("loading", false);
						Y.all('.compute_deep_stats').on('click', oSelf._onDeepStats, oSelf);
					}
				}
			});

			// fetch a hint
			if (!this.get("readonly")) {
				this._createHint()
			};
		},

		_onLoadingChange : function (o) {
			if(o.newVal) {
				NODE_INFO.addClass("hidden");
				this.loadingNode.removeClass("hidden");
			} else {
				this.loadingNode.addClass("hidden");
				NODE_INFO.removeClass("hidden");
			}
		},

		_onNodeUpdate : function() {
			var sel = this.get("focus"),
				uri = sel.uri,
				namespace = NODE_NAMESPACE.get("value"),
				label = NODE_LABEL.get("value"),
				comment = NODE_COMMENT.get("value"),
				abbrev = NODE_ABBREV.get("value"),
				status = NODE_STATUS.get("options")
					.item(NODE_STATUS.get("selectedIndex")).get("value");

				relation = NODE_REL.get("options")
					.item(NODE_REL.get("selectedIndex")).get("value");

			var data = {
				uri:uri,
				label:label,
				abbrev:abbrev,
				publish_ns:namespace,
				status:status,
				default_relation:relation,
				comment:comment
			};
			this.set("lastAction", "nodeUpdate");
			Y.log("update node: "+uri);
			this.fire("nodeUpdate", {data:data});
		},

		_onNodeDelete : function() {
			var uri = this.get("focus").uri;
			this.set("lastAction", "nodeDelete");
			Y.log("delete node: "+uri);
			this.fire("deleteNode", {uri:uri});
			// this component does not update itself on nodeDelete,
			// instead this is done via the nodesChange handler
		},

		_onNodeEvaluate : function() {
			var uri = this.get("focus").uri;
			this.set("lastAction", "nodeEvaluate");
			Y.log("evaluate node: "+uri);
			this.fire("evaluate", {data:{focus:uri}});
		},

		_onExecHint : function(e, data, event) {
			Y.log('execute "'+event+'" hint with data:');
			Y.log(data);
			this.fire(event, {data: data});
		},

		_onDeepStats : function(e) {
				 e.currentTarget.set('innerHTML', 'computing statistics ...');
				 var voc = this.get("focus").uri;
				 var paths = this.get("paths");
				 var strategy = this.get("strategy");
				 var oSelf = this;
				 Y.io(paths.deep_voc_stats, {
							  data: {
								url:voc,
								strategy:strategy
								},
							  on: {
							      success:function(e,r) {
								// should cleanup deep stats handler here ...
								  oSelf.syncUI();
							      }
							      }
							  });

		 },

		_setProperties : function(focus) {
			var strategy = this.get("strategy"),
				content = this.get("srcNode");

			if(focus) {
				var uri = focus.uri,
					link = focus.link||uri,
					local = focus.local||uri,
					label = focus.label||uri,
					type = focus.type||"",
					comment = focus.comment||"",
					abbrev = focus.abbrev||"?",
					namespace = focus.namespace||"",
					status = focus.status || "",
					relation = focus.default_relation || "",
					sec_inputs = focus.secondary_inputs|| [];

				this.emptyNode.addClass("hidden");
				NODE_DELETE.removeAttribute("disabled");
				NODE_LABEL.set("value", label);
				NODE_COMMENT.set("value", comment);
				NODE_ABBREV.set("value", abbrev);
				Y.one('#namespace').set("value", namespace);
				NODE_TYPE.setContent(type);
				NODE_URI.setContent('<a href="'+link+'">'+local+'</a>');

				// the status and relation rows only shown for mappings:
				if(type=="mapping") {
					NODE_STATUS_ROW.removeClass("hidden")
					NODE_REL_ROW.removeClass("hidden")
					Node.getDOMNode(NODE_STATUS).selectedIndex =
							  NODE_STATUS.get('options')
							    .indexOf(NODE_STATUS.one("option[value='"+status+"']"));
					Node.getDOMNode(NODE_REL).selectedIndex =
							  NODE_REL.get('options')
							    .indexOf(NODE_REL.one("option[value='"+relation+"']"));
				} else {
					NODE_STATUS_ROW.addClass("hidden")
					NODE_REL_ROW.addClass("hidden")
				}

				// more mapping only things:
				if (type == "mapping") {
					NODE_EVAL.setContent("evaluate");
					NODE_EVAL.removeClass("hidden");
					NODE_ABBREV.removeClass("hidden");
					Y.all('span.abbrev').removeClass("hidden");
				} else {
					NODE_EVAL.addClass("hidden");
					NODE_ABBREV.addClass("hidden");
					Y.all('span.abbrev').addClass("hidden");
				}

				if(type =='alignment' || type=='strategy') {
					NODE_NAMESPACE_ROW.removeClass("hidden");
					NODE_DELETE.setAttribute("disabled", true);
				} else if (this.get('readonly')) { 
					NODE_NAMESPACE_ROW.removeClass("hidden");
					NODE_DELETE.setAttribute("disabled", true);
				} else if (status.search('reference') > -1) {
					NODE_DELETE.setAttribute("disabled", true);
					NODE_EVAL.setContent("manual edit");
				}

				// hide the parameter form submit button in case we are not a process
				if(type==="process") {
					content.one('.control-submit').removeClass("hidden");
				} else {
					content.one('.control-submit').addClass("hidden");
				}
				this.bd.removeClass("hidden");
			} else {
				this.emptyNode.removeClass("hidden");
			}
		},

		_createHint : function() {
				var oSelf = this;
				var focus = this.get("focus").uri
				NODE_HINT.setContent('Loading next hint, please wait...');
				Y.io(this.get("paths").hint,
				     {
				     data: {
					   strategy: this.get("strategy"),
					   lastAction: this.get("lastAction"),
					   focus: focus
					   },
				     on: {success: function(e,o)
						   {
						     var r = Y.JSON.parse(o.responseText);
						     Y.log('Create hint:');
						     Y.log(r);
						     if (r.text) {
						       NODE_HINT.setContent(r.text);
						     } else {
						       NODE_HINT.setContent('No hints available at this point');
						     }
						     if (r.data) {
						       NODE_HINT.appendChild('&nbsp;');
						       NODE_HINT.appendChild('(<a id="exec_hint">just do it</a>)');
						       // FixMe! can we put the handler once on initialization?
						       Y.one('#exec_hint').on("click", oSelf._onExecHint, oSelf, r.data, r.event);
						     }
						   }
					 }
				     }
			   );
		 },

		_updateParameters : function() {
			var paramnode = this.get("srcNode").one('.parameters'),
				sec_inputs = this.get("focus").secondary_inputs || [];

			if (paramnode && sec_inputs.length > 0) {
			  paramnode.prepend(this.formatMappingList(sec_inputs));
			  paramnode.prepend('<div>Additional input mappings:</div>');
			}
		},

		formatMappingList : function(focus) {
			var HTML = "";
			var nodes = this.get("nodes");
			for (var uri in nodes) {
				var m = nodes[uri];
				if (m.label == m.local) {
					label = m.label;
				} else {
					label = m.label + ' (' + m.local +')';
				}
				if(m.type == "mapping") {
					var index = focus.indexOf(uri);
					var checked = (index == -1)?'':'checked';
					HTML += '<div><input type="checkbox" name="secondary_input" value="'
					+uri+'" ' +checked +' class="' + checked +'">'
					+'<span>'+m.abbrev+':'+label+'</span></div>';
				}
			}
			return HTML;
		}
	});

	Y.InfoBox = InfoBox;

}, '0.0.1', { requires: ['node','event','io','querystring-stringify-simple']});
