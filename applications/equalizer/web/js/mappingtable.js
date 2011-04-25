YUI.add('mappingtable', function(Y) {
	
	var Lang = Y.Lang,
		Node = Y.Node,
		Widget = Y.Widget;
	
	var NODE_SOURCE_INFO = Y.one("#sourceinfo"),
		NODE_TARGET_INFO = Y.one("#targetinfo");
	
	function MappingTable(config) {
		MappingTable.superclass.constructor.apply(this, arguments);
	}
	MappingTable.NAME = "mappingtable";
	MappingTable.ATTRS = {
		srcNode: {
			value: null
		},
		rows: {
			value:100,
			validator:function(val) {
				return Lang.isNumber(val);
			}
		},
		mapping: {
			value: null
		},
		datasource: {
			value: null
		},
		infoserver: {
			value:"/amalgame/private/resourcecontext"
		}
	};
	
	Y.extend(MappingTable, Y.Base, {
		initializer: function(config) {
			var instance = this,
				content = this.get("srcNode");
			
			this.table = new Y.DataTable.Base({
				columnset:[{key:"source",
					       formatter:this.formatResource,
					       sortable:true
					      },
					      {key:"relation",
					       formatter:this.formatResource,
					       sortable:true
					      },
					      {key:"target",
					       formatter:this.formatResource,
					       sortable:true
					      }],
				plugins: [ Y.Plugin.DataTableSort ]
			})
			.render(content.appendChild(Node.create(
				'<div class="table"></div>'
			)));

			this.paginator = new Y.Paginator({
				rowsPerPage:this.get("rows"),
				template: '{FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink}',
				firstPageLinkLabel:'|&lt;',
				previousPageLinkLabel: '&lt;',
				nextPageLinkLabel: '&gt;',
				lastPageLinkLabel: '&gt;|'
			})
			.render(content.appendChild(Node.create(
				'<div class="paginator"></div>'
			)));
			this.paginator.on("changeRequest", function(state) {
				this.setPage(state.page, true);
				instance.load({offset:state.recordOffset}, true);
			});
			
			// get new data if mapping is changed
			this.after('mappingChange', this.load, this);
			this.table.on('tbodyCellClick', this._onRowSelect, this);
		},
		
		load : function(conf, recordsOnly) {
			var mapping = this.get("mapping"),
				datasource = this.get("datasource"),
				table = this.table,
				paginator = this.paginator;

			var callback = 	{
				success: function(o) {
					var records = o.response.results,
						total = o.response.meta.totalNumberOfResults;
					
					if(!recordsOnly) {
						paginator.setPage(1, true);
						paginator.setTotalRecords(total, true);
					}
					table.set("recordset", records);
				}
			};
				
			if(mapping) {
				conf = conf ? conf : {};
				conf.url = mapping;
				//infobox.set("waiting", true);
				datasource.sendRequest({
					request:'?'+Y.QueryString.stringify(conf),
					callback:callback
				})
			}	
		},
				
		formatResource : function(o) {
			var label = o.value ? o.value.label : "";
     		return "<div class=resource>"+label+"</div>";
		},
		
		_onRowSelect : function(e) {
			console.log(e);
			var row = e.currentTarget.get("parentNode"),
         	records = this.table.get("recordset"),
         	current = records.getRecord( row.get("id")),
	 		source = current.getValue("source").uri,
	 		target = current.getValue("target").uri;
			console.log(source, target);
			
			var add = (e.ctrlKey||e.metaKey) ? true : false;
			
			if(!add) {
	  			Y.all(".yui3-datatable tr").removeClass("yui3-datatable-selected");
	  			this.selected = {};
     		};
     		row.addClass("yui3-datatable-selected");
			
			if(!this.selected[source]) {
				this._fetchInfo(source, NODE_SOURCE_INFO, add);
     		}
			if(!this.selected[target]) {
	  			this._fetchInfo(target, NODE_TARGET_INFO, add);
     		}
    		this.selected[source] = true;
     		this.selected[target] = true;
		},
		
		_fetchInfo : function(uri, target, add) {
			var server = this.get("infoserver");
			Y.io(server, {
				data:{uri:uri},
				on:{success:function(e,o) {
     					if(add) { target.append(o.responseText) }
     					else { target.setContent(o.responseText) }
						target.all(".moretoggle").on("click", function(e) {
   							p = e.currentTarget.get("parentNode");
   							p.all(".moretoggle").toggleClass("hidden");
   							p.one(".morelist").toggleClass("hidden");
						})
					}
				}
			});
		}
		
	});
	
	Y.MappingTable = MappingTable;
	
}, '0.0.1', { requires: ['node,event','gallery-paginator','datatable','datatable-sort']});