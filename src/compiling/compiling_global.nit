# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2008 Jean Privat <jean@pryen.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Compute and generate tables for classes and modules.
package compiling_global

#import compiling_base
private import compiling_methods
private import syntax

# Something that store color of table elements
class ColorContext
	attr _colors: HashMap[TableElt, Int] = null

	# The color of a table element.
	meth color(e: TableElt): Int
	do
		return _colors[e]
	end

	# Is a table element already colored?
	meth has_color(e: TableElt): Bool
	do
		return _colors != null and _colors.has_key(e)
	end

	# Assign a color to a table element.
	meth color=(e: TableElt, c: Int)
	do
		if _colors == null then _colors = new HashMap[TableElt, Int]
		_colors[e] = c
		var idx = c
		for i in [0..e.length[ do
			_colors[e.item(i)] = idx
			idx = idx + 1
		end
	end
end

# All information and results of the global analysis.
class GlobalAnalysis
special ColorContext
	# Associate global classes to compiled classes
	readable attr _compiled_classes: HashMap[MMGlobalClass, CompiledClass] = new HashMap[MMGlobalClass, CompiledClass]

	# The main module of the program globally analysed
	readable attr _module: MMModule

	# FIXME: do something better.
	readable writable attr _max_class_table_length: Int

	init(module: MMSrcModule)
	do
		_module = module
	end
end

class GlobalCompilerVisitor
special CompilerVisitor
	# The global analysis result
	readable attr _global_analysis: GlobalAnalysis
	init(m: MMSrcModule, tc: ToolContext, ga: GlobalAnalysis)
	do
		super(m, tc)
		_global_analysis = ga
	end
end

# A compiled class is a class in a program
class CompiledClass
special ColorContext
	# The corresponding local class in the main module of the prgram
	readable attr _local_class: MMLocalClass

	# The identifier of the class
	readable writable attr _id: Int

	# The full class table of the class
	readable attr _class_table: Array[TableElt] = new Array[TableElt]

	# The full instance table of the class
	readable attr _instance_table: Array[TableElt] = new Array[TableElt]

	# The proper class table part (no superclasses but all refinements)
	readable attr _class_layout: TableEltComposite = new TableEltComposite(self)

	# The proper instance table part (no superclasses but all refinements)
	readable attr _instance_layout: TableEltComposite = new TableEltComposite(self)

	init(c: MMLocalClass) do _local_class = c
end

redef class MMSrcLocalClass
	# The table element of the subtype check
	readable attr _class_color_pos: TableEltClassColor

	# The proper local class table part (nor superclasses nor refinments)
	readable attr _class_layout: Array[TableElt] = new Array[TableElt]

	# The proper local instance table part (nor superclasses nor refinments)
	readable attr _instance_layout: Array[TableElt] = new Array[TableElt]

	# Build the local layout of the class and feed the module table
	meth build_layout_in(tc: ToolContext, module_table: Array[ModuleTableElt])
	do
		var clt = _class_layout
		var ilt = _instance_layout

		if global.intro == self then
			module_table.add(new TableEltClassId(self))
			_class_color_pos = new TableEltClassColor(self)
			module_table.add(_class_color_pos)
			clt.add(new TableEltClassInitTable(self))
		end
		for p in src_local_properties do
			var pg = p.global
			if pg.intro == p then
				if p isa MMSrcAttribute then
					ilt.add(new TableEltAttr(p))
				else if p isa MMSrcMethod then
					clt.add(new TableEltMeth(p))
				end
			end
			if p isa MMSrcMethod and p.need_super then
				clt.add(new TableEltSuper(p))
			end
		end

		if not ilt.is_empty then
			var teg = new ModuleTableEltGroup
			teg.elements.append(ilt)
			module_table.add(teg)
		end

		if not clt.is_empty then
			var teg = new ModuleTableEltGroup
			teg.elements.append(clt)
			module_table.add(teg)
		end
	end
end

redef class MMSrcModule
	# The local table of the module (refers things introduced in the module)
	attr _local_table: Array[ModuleTableElt] = new Array[ModuleTableElt]

	# Builds the local tables and local classes layouts
	meth local_analysis(tc: ToolContext)
	do
		for c in src_local_classes do
			c.build_layout_in(tc, _local_table)
		end
	end

	# Do the complete global analysis
	meth global_analysis(cctx: ToolContext): GlobalAnalysis
	do
		#print "Do the complete global analysis"
		var ga = new GlobalAnalysis(self)
		var smallest_classes = new Array[MMLocalClass]
		var global_properties = new HashSet[MMGlobalProperty]
		var ctab = new Array[TableElt]
		var itab = new Array[TableElt]

		ctab.add(new TableEltClassSelfId)
		itab.add(new TableEltVftPointer)

		var pclassid = -1
		var classid = 3

		# We have to work on ALL the classes of the module
		var classes = new Array[MMLocalClass]
		for c in local_classes do
			c.compute_super_classes
			classes.add(c)
		end
		(new ClassSorter).sort(classes)

		for c in classes do
			# Finish processing the class (if invisible)
			c.compute_ancestors
			c.inherit_global_properties

			# Associate a CompiledClass to the class
			var cc = new CompiledClass(c)
			ga.compiled_classes[c.global] = cc

			# Assign a unique class identifier
			# (negative are for primitive classes)
			var gc = c.global
			var bm = gc.module
			if c.primitive_info != null then
				cc.id = pclassid
				pclassid = pclassid - 4
			else
				cc.id = classid
				classid = classid + 4
			end

			# Register is the class is a leaf
			if c.cshe.direct_smallers.is_empty then
				smallest_classes.add(c)
			end

			# Store the colortableelt in the class table pool
			var bc = c.global.intro
			assert bc isa MMSrcLocalClass
			ctab.add(bc.class_color_pos)
		end

		# Compute core and crown classes for colorization
		var crown_classes = new HashSet[MMLocalClass]
		var core_classes = new HashSet[MMLocalClass]
		for c in smallest_classes do
			while c.cshe.direct_greaters.length == 1 do
				c = c.cshe.direct_greaters.first
			end
			crown_classes.add(c)
			core_classes.add_all(c.cshe.greaters_and_self)
		end
		#print("nbclasses: {classes.length} leaves: {smallest_classes.length} crown: {crown_classes.length} core: {core_classes.length}")

		# Colorize core color for typechecks
		colorize(ga, ctab, crown_classes, 0)

		# Compute tables for typechecks
		var maxcolor = 0
		for c in classes do
			var cc = ga.compiled_classes[c.global]
			if core_classes.has(c) then
				# For core classes, just build the table
				build_tables_in(cc.class_table, ga, c, ctab)
				if maxcolor < cc.class_table.length then maxcolor = cc.class_table.length
			else
				# For other classes, it's easier: just append to the parent tables
				var sc = c.cshe.direct_greaters.first
				var scc = ga.compiled_classes[sc.global]
				assert cc.class_table.is_empty
				cc.class_table.add_all(scc.class_table)
				var bc = c.global.intro
				assert bc isa MMSrcLocalClass
				var colpos = bc.class_color_pos
				var colposcolor = cc.class_table.length
				ga.color(colpos) = colposcolor
				cc.class_table.add(colpos)
				if maxcolor < colposcolor then maxcolor = colposcolor
			end
		end
		ga.max_class_table_length = maxcolor + 1

		# Fill class table and instance tables pools
		for c in classes do
			var cc = ga.compiled_classes[c.global]
			var cte = cc.class_layout
			var ite = cc.instance_layout
			for sc in c.crhe.greaters_and_self do
				if sc isa MMSrcLocalClass then
					cte.add(sc, sc.class_layout)
					ite.add(sc, sc.instance_layout)
				end
			end

			if core_classes.has(c) then
				if cte.length > 0 then
					ctab.add(cte)
				end
				if ite.length > 0 then
					itab.add(ite)
				end
			end
		end

		# Colorize all elements in pools tables
		colorize(ga, ctab, crown_classes, maxcolor+1)
		colorize(ga, itab, crown_classes, 0)

		# Build class and instance tables now things are colored
		ga.max_class_table_length = 0
		for c in classes do
			var cc = ga.compiled_classes[c.global]
			if core_classes.has(c) then
				# For core classes, just build the table
				build_tables_in(cc.class_table, ga, c, ctab)
				build_tables_in(cc.instance_table, ga, c, itab)
			else
				# For other classes, it's easier: just append to the parent tables
				var sc = c.cshe.direct_greaters.first
				var scc = ga.compiled_classes[sc.global]
				cc.class_table.clear
				cc.class_table.add_all(scc.class_table)
				var bc = c.global.intro
				assert bc isa MMSrcLocalClass
				var colpos = bc.class_color_pos
				cc.class_table[ga.color(colpos)] = colpos
				while cc.class_table.length <= maxcolor do
					cc.class_table.add(null)
				end
				append_to_table(ga, cc.class_table, cc.class_layout)
				assert cc.instance_table.is_empty
				cc.instance_table.add_all(scc.instance_table)
				append_to_table(ga, cc.instance_table, cc.instance_layout)
			end
		end

		return ga
	end

	private meth append_to_table(cc: ColorContext, table: Array[TableElt], cmp: TableEltComposite)
	do
		for j in [0..cmp.length[ do
			var e = cmp.item(j)
			cc.color(e) = table.length
			table.add(e)
		end
	end

	private meth build_tables_in(table: Array[TableElt], ga: GlobalAnalysis, c: MMLocalClass, elts: Array[TableElt])
	do
		var tab = new HashMap[Int, TableElt]
		var len = 0
		for e in elts do
			if e.is_related_to(c) then
				var col = ga.color(e)
				var l = col + e.length
				tab[col] = e
				if len < l then
					len = l
				end
			end
		end
		var i = 0
		while i < len do
			if tab.has_key(i) then
				var e = tab[i]
				for j in [0..e.length[ do
					table[i] = e.item(j)
					i = i + 1
				end
			else
				table[i] = null
				i = i + 1
			end
		end
	end

	# Perform coloring
	meth colorize(ga: GlobalAnalysis, elts: Array[TableElt], classes: Collection[MMLocalClass], startcolor: Int)
	do
		var colors = new HashMap[Int, Array[TableElt]]
		var rel_classes = new Array[MMLocalClass]
		for e in elts do
			var color = -1
			var len = e.length
			if ga.has_color(e) then
				color = ga.color(e)
			else
				rel_classes.clear
				for c in classes do
					if e.is_related_to(c) then
						rel_classes.add(c)
					end
				end
				var trycolor = startcolor
				while trycolor != color do
					color = trycolor
					for c in rel_classes do
						var idx = 0
						while idx < len do
							if colors.has_key(trycolor + idx) and not free_color(colors[trycolor + idx], c) then
								trycolor = trycolor + idx + 1
								idx = 0
							else
								idx = idx + 1
							end
						end
					end
				end
				ga.color(e) = color
			end
			for idx in [0..len[ do
				if colors.has_key(color + idx) then
					colors[color + idx].add(e)
				else
					colors[color + idx] = [e]
				end
			end
		end
	end

	private meth free_color(es: Array[TableElt], c: MMLocalClass): Bool
	do
		for e2 in es do
			if e2.is_related_to(c) then
				return false
			end
		end
		return true
	end

	# Compile module and class tables
	meth compile_tables_to_c(v: GlobalCompilerVisitor)
	do
		for m in mhe.greaters_and_self do
			assert m isa MMSrcModule
			m.compile_local_table_to_c(v)
		end

		for c in local_classes do
			c.compile_tables_to_c(v)
		end
		var s = new Buffer.from("classtable_t TAG2VFT[4] = \{NULL")
		for t in ["Int","Char","Bool"] do
			if has_global_class_named(t.to_symbol) then
				s.append(", (const classtable_t)VFT_{t}")
			else
				s.append(", NULL")
			end
		end
		s.append("};")
		v.add_instr(s.to_s)
	end

	# Declare class table (for _sep.h)
	meth declare_class_tables_to_c(v: GlobalCompilerVisitor)
	do
		for c in local_classes do
			if c.global.module == self then
				c.declare_tables_to_c(v)
			end
		end
	end

	# Compile main part (for _table.c)
	meth compile_main_part(v: GlobalCompilerVisitor)
	do
		v.add_instr("int main(int argc, char **argv) \{")
		v.indent
		v.add_instr("prepare_signals();")
		v.add_instr("glob_argc = argc; glob_argv = argv;")
		var sysname = once "Sys".to_symbol
		if not has_global_class_named(sysname) then
			print("No main")
		else
			var sys = class_by_name(sysname)
			# var initm = sys.select_method(once "init".to_symbol)
			var mainm = sys.select_method(once "main".to_symbol)
			if mainm == null then
				print("No main")
			else
				#v.add_instr("G_sys = NEW_{initm.cname}();")
				v.add_instr("G_sys = NEW_Sys();")
				v.add_instr("{mainm.cname}(G_sys);")
			end
		end
		v.add_instr("return 0;")
		v.unindent
		v.add_instr("}")
	end

	# Compile sep files
	meth compile_mod_to_c(v: GlobalCompilerVisitor)
	do
		v.add_decl("extern const char *LOCATE_{name};")
		if not v.tc.global then
			v.add_decl("extern const int SFT_{name}[];")
		end
		var i = 0
		for e in _local_table do
			var value: String
			if v.tc.global then
				value = "{e.value(v.global_analysis)}"
			else
				value = "SFT_{name}[{i}]"
				i = i + 1
			end
			e.compile_macros(v, value)
		end
		for c in src_local_classes do
			for pg in c.global_properties do
				var p = c[pg]
				if p.local_class == c then
					p.compile_property_to_c(v)
				end
				if pg.is_init_for(c) then
					# Declare constructors
					var params = new Array[String]
					for i in [0..p.signature.arity[ do
						params.add("val_t p{i}")
					end
					v.add_decl("val_t NEW_{c}_{p.global.intro.cname}({params.join(", ")});")
				end
			end
		end
	end

	# Compile module file for the current module
	meth compile_local_table_to_c(v: GlobalCompilerVisitor)
	do
		v.add_instr("const char *LOCATE_{name} = \"{filename}\";")

		if v.tc.global or _local_table.is_empty then
			return
		end

		v.add_instr("const int SFT_{name}[{_local_table.length}] = \{")
		v.indent
		for e in _local_table do
			v.add_instr(e.value(v.global_analysis) + ",")
		end
		v.unindent
		v.add_instr("\};")
	end
end

###############################################################################

# An element of a class, an instance or a module table
abstract class AbsTableElt
	# Compile the macro needed to use the element and other related elements
	meth compile_macros(v: GlobalCompilerVisitor, value: String) is abstract
end

# An element of a class or an instance table
# Such an elements represent method function pointers, attribute values, etc.
abstract class TableElt
special AbsTableElt
	# Is the element conflict to class `c' (used for coloring)
	meth is_related_to(c: MMLocalClass): Bool is abstract

	# Number of sub-elements. 1 if none
	meth length: Int do return 1

	# Access the ith subelement.
	meth item(i: Int): TableElt do return self

	# Return the value of the element for a given class
	meth compile_to_c(v: GlobalCompilerVisitor, c: MMLocalClass): String is abstract
end

# An element of a module table
# Such an elements represent colors or identifiers
abstract class ModuleTableElt
special AbsTableElt
	# Return the value of the element once the global analisys is performed
	meth value(ga: GlobalAnalysis): String is abstract
end

# An element of a module table that represents a group of TableElt defined in the same local class
class ModuleTableEltGroup
special ModuleTableElt
	readable attr _elements: Array[TableElt] = new Array[TableElt]

	redef meth value(ga) do return "{ga.color(_elements.first)} /* Group of ? */"
	redef meth compile_macros(v, value)
	do
		var i = 0
		for e in _elements do
			e.compile_macros(v, "{value} + {i}")
			i += 1
		end
	end
end

# An element that represents a class property
abstract class TableEltProp
special TableElt
	attr _property: MMLocalProperty

	init(p: MMLocalProperty)
	do
		_property = p
	end
end

# An element that represents a function pointer to a global method
class TableEltMeth
special TableEltProp
	redef meth compile_macros(v, value)
	do
		var pg = _property.global
		v.add_decl("#define {pg.meth_call}(recv) (({pg.intro.cname}_t)CALL((recv), ({value})))")
	end

	redef meth compile_to_c(v, c)
	do
		var p = c[_property.global]
		return p.cname
	end
end

# An element that represents a function pointer to the super method of a local method
class TableEltSuper
special TableEltProp
	redef meth compile_macros(v, value)
	do
		var p = _property
		v.add_decl("#define {p.super_meth_call}(recv) (({p.cname}_t)CALL((recv), ({value})))")
	end

	redef meth compile_to_c(v, c)
	do
		var pc = _property.local_class
		var g = _property.global
		var lin = c.che.linear_extension
		var found = false
		for s in lin do
			#print "{c.module}::{c} for {pc.module}::{pc}::{_property} try {s.module}:{s}"
			if s == pc then
				found = true
			else if found and c.che < s then
				if s.has_global_property(g) then
					#print "found {s.module}::{s}::{p}"
					return s[g].cname
				end
			end
		end
		assert false
		return null
	end
end

# An element that represents the value stored for a global attribute
class TableEltAttr
special TableEltProp
	redef meth compile_macros(v, value)
	do
		var pg = _property.global
		v.add_decl("#define {pg.attr_access}(recv) ATTR(recv, ({value}))")
	end

	redef meth compile_to_c(v, c)
	do
		var ga = v.global_analysis
		var p = c[_property.global]
		return "/* {ga.color(self)}: Attribute {c}::{p} */"
	end
end

# An element representing a class information
class AbsTableEltClass
special AbsTableElt
	# The local class where the information comes from
	attr _local_class: MMLocalClass

	init(c: MMLocalClass)
	do
		_local_class = c
	end

	# The C macro name refering the value
	meth symbol: String is abstract

	redef meth compile_macros(v, value)
	do
		v.add_decl("#define {symbol} ({value})")
	end
end

# An element of a class table representing a class information
class TableEltClass
special TableElt
special AbsTableEltClass
	redef meth is_related_to(c)
	do
		var bc = c.module[_local_class.global]
		return c.cshe <= bc
	end
end

# An element representing the id of a class in a module table
class TableEltClassId
special ModuleTableElt
special AbsTableEltClass
	redef meth symbol do return _local_class.global.id_id

	redef meth value(ga)
	do
		return "{ga.compiled_classes[_local_class.global].id} /* Id of {_local_class} */"
	end
end

# An element representing the constructor marker position in a class table
class TableEltClassInitTable
special TableEltClass
	redef meth symbol do return _local_class.global.init_table_pos_id

	redef meth compile_to_c(v, c)
	do
		var ga = v.global_analysis
		var cc = ga.compiled_classes[_local_class.global]
		var linext = c.cshe.reverse_linear_extension
		var i = 0
		while linext[i].global != _local_class.global do
			i += 1
		end
		return "{i} /* {ga.color(self)}: {c} < {cc.local_class}: superclass init_table position */"
	end
end

# An element used for a cast
# Note: this element is both a TableElt and a ModuleTableElt.
# At the TableElt offset, there is the id of the super-class
# At the ModuleTableElt offset, there is the TableElt offset (ie. the color of the super-class).
class TableEltClassColor
special TableEltClass
special ModuleTableElt
	redef meth symbol do return _local_class.global.color_id

	redef meth value(ga)
	do
		return "{ga.color(self)} /* Color of {_local_class} */"
	end

	redef meth compile_to_c(v, c)
	do
		var ga = v.global_analysis
		var cc = ga.compiled_classes[_local_class.global]
		return "{cc.id} /* {ga.color(self)}: {c} < {cc.local_class}: superclass typecheck marker */"
	end
end

# A Group of elements introduced in the same global-class that are colored together
class TableEltComposite
special TableElt
	attr _table: Array[TableElt]
	attr _cc: CompiledClass
	attr _offsets: HashMap[MMLocalClass, Int]
	redef meth length do return _table.length
	redef meth is_related_to(c) do return c.cshe <= _cc.local_class

	meth add(c: MMLocalClass, tab: Array[TableElt])
	do
		_offsets[c] = _table.length
		_table.append(tab)
	end

	redef meth item(i) do return _table[i]

	redef meth compile_to_c(v, c) do abort

	init(cc: CompiledClass)
	do
		_cc = cc
		_table = new Array[TableElt]
		_offsets = new HashMap[MMLocalClass, Int]
	end
end

# The element that represent the class id
class TableEltClassSelfId
special TableElt
	redef meth is_related_to(c) do return true
	redef meth compile_to_c(v, c)
	do
		var ga = v.global_analysis
		return "{v.global_analysis.compiled_classes[c.global].id} /* {ga.color(self)}: Identity */"
	end
end

# The element that
class TableEltVftPointer
special TableElt
	redef meth is_related_to(c) do return true
	redef meth compile_to_c(v, c)
	do
		var ga = v.global_analysis
		return "/* {ga.color(self)}: Pointer to the classtable */"
	end
end

###############################################################################

# Used to sort local class in a deterministic total order
# The total order superset the class refinement and the class specialisation relations
class ClassSorter
special AbstractSorter[MMLocalClass]
	redef meth compare(a, b) do return a.compare(b)
	init do end
end

redef class MMLocalClass
	# Comparaison in a total order that superset the class refinement and the class specialisation relations
	meth compare(b: MMLocalClass): Int
	do
		var a = self
		if a == b then
			return 0
		else if a.module.mhe < b.module then
			return 1
		else if b.module.mhe < a.module then
			return -1
		end
		var ar = a.cshe.rank
		var br = b.cshe.rank
		if ar > br then
			return 1
		else if br > ar then
			return -1
		else
			return b.name.to_s <=> a.name.to_s
		end
	end

	# Declaration and macros related to the class table
	meth declare_tables_to_c(v: GlobalCompilerVisitor)
	do
		v.add_decl("")
		var pi = primitive_info
		v.add_decl("extern const classtable_elt_t VFT_{name}[];")
		if pi == null then
			# v.add_decl("val_t NEW_{name}(void);")
		else if not pi.tagged then
			var t = pi.cname
			var tbox = "struct TBOX_{name}"
			v.add_decl("{tbox} \{ const classtable_elt_t * vft; {t} val;};")
			v.add_decl("val_t BOX_{name}({t} val);")
			v.add_decl("#define UNBOX_{name}(x) ((({tbox} *)(VAL2OBJ(x)))->val)")
		end
	end

	# Compilation of table and new (or box)
	meth compile_tables_to_c(v: GlobalCompilerVisitor)
	do
		var cc = v.global_analysis.compiled_classes[self.global]
		var ctab = cc.class_table
		var clen = ctab.length
		if v.global_analysis.max_class_table_length > ctab.length then
			clen = v.global_analysis.max_class_table_length
		end

		v.add_instr("const classtable_elt_t VFT_{name}[{clen}] = \{")
		v.indent
		for e in ctab do
			if e == null then
				v.add_instr("\{0} /* Class Hole :( */,")
			else
				v.add_instr("\{(bigint) {e.compile_to_c(v, self)}},")
			end
		end
		if clen > ctab.length then
			v.add_instr("\{0},"*(clen-ctab.length))
		end
		v.unindent
		v.add_instr("};")
		var itab = cc.instance_table
		for e in itab do
			if e == null then
				v.add_instr("/* Instance Hole :( */")
			else
				v.add_instr(e.compile_to_c(v, self))
			end
		end

		var pi = primitive_info
		if pi == null then
			v.cfc = new CFunctionContext(v)
			v.nmc = new NitMethodContext(null)
			var s = "val_t NEW_{name}(void)"
			v.add_instr(s + " \{")
			v.indent
			var ctx_old = v.ctx
			v.ctx = new CContext

			var self_var = new ParamVariable(null, null)
			var self_var_cname = v.cfc.register_variable(self_var)
			v.nmc.method_params = [self_var]

			v.add_instr("obj_t obj;")
			v.add_instr("obj = alloc(sizeof(val_t) * {itab.length});")
			v.add_instr("obj->vft = (classtable_elt_t*)VFT_{name};")
			v.add_assignment(self_var_cname, "OBJ2VAL(obj)")

			for g in global_properties do
				var p = self[g]
				var t = p.signature.return_type
				if p isa MMAttribute and t != null then
					# FIXME: Not compatible with sep compilation
					assert p isa MMSrcAttribute
					var np = p.node
					assert np isa AAttrPropdef
					var ne = np.n_expr
					if ne != null then
						var e = ne.compile_expr(v)
						v.add_instr("{p.global.attr_access}(obj) = {e};")
					else
						var pi = t.local_class.primitive_info
						if pi != null and pi.tagged then
							var default = t.default_cvalue
							v.add_instr("{p.global.attr_access}(obj) = {default};")
						end
					end
				end
			end
			v.add_instr("return OBJ2VAL(obj);")
			v.cfc.generate_var_decls
			ctx_old.append(v.ctx)
			v.ctx = ctx_old
			v.unindent
			v.add_instr("}")

			var init_table_size = cshe.greaters.length + 1
			var init_table_decl = "int init_table[{init_table_size}] = \{0{", 0" * (init_table_size-1)}};"

			for g in global_properties do
				var p = self[g]
				# FIXME skip invisible constructors
				if not p.global.is_init_for(self) then continue
				var params = new Array[String]
				var args = ["self"]
				for i in [0..p.signature.arity[ do
					params.add("val_t p{i}")
					args.add("p{i}")
				end
				args.add("init_table")
				var s = "val_t NEW_{self}_{p.global.intro.cname}({params.join(", ")}) \{"
				v.add_instr(s)
				v.indent
				v.add_instr(init_table_decl)
				v.add_instr("val_t self = NEW_{name}();")
				v.add_instr("{p.cname}({args.join(", ")});")
				v.add_instr("return self;")
				v.unindent
				v.add_instr("}")
			end
		else if not pi.tagged then
			var t = pi.cname
			var tbox = "struct TBOX_{name}"
			v.add_instr("val_t BOX_{name}({t} val) \{")
			v.indent
			v.add_instr("{tbox} *box = ({tbox}*)alloc(sizeof({tbox}));")
			v.add_instr("box->vft = VFT_{name};")
			v.add_instr("box->val = val;")
			v.add_instr("return OBJ2VAL(box);")
			v.unindent
			v.add_instr("}")
		end
	end
end

