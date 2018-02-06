# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import tests
import model::module_compound

var graph = new ProjectGraph("foo")
var file = new FileCompound(graph)
var file_2 = new FileCompound(graph)
var bar_class = new ClassCompound(graph)
var baz_class = new ClassCompound(graph)
var a_ns = new Namespace(graph)
var b_ns = new Namespace(graph)
var c_ns = new Namespace(graph)
var d_ns = new Namespace(graph)
var buffer = new Buffer
var root_ns = graph.by_id[""].as(Namespace)
var location

file.name = "Bar.java"
file.model_id = "_Bar_8java"
location = new neo_doxygen::Location
location.path = "a/b/Bar.java"
file.location = location
file.declare_class("classa_b_bar", "a::b::Bar", "package")
file.declare_class("classbaz", "Baz", "")
file.declare_namespace("", "a::b")
file.doc.brief_description = "The first file."
file.put_in_graph

file_2.name = "Bar.java"
file_2.model_id = "_Bar_8java_2"
location = new neo_doxygen::Location
location.path = "Bar.java"
file_2.location = location
file_2.declare_namespace("namespacec", "c")
file_2.declare_namespace("", "d")
file_2.put_in_graph

bar_class.model_id = "classa_b_bar"
bar_class.name = "Bar"
location = new neo_doxygen::Location
location.path = "a/b/Bar.class"
location.line_start = 5
location.column_start = 1
location.line_end = 100
location.column_end = 10
bar_class.location = location
bar_class.put_in_graph

baz_class.model_id = "classbaz"
baz_class.name = "Baz"
location = new neo_doxygen::Location
location.path = "Baz.jar"
baz_class.location = location
baz_class.put_in_graph

root_ns.declare_namespace("", "a")
root_ns.declare_namespace("namespacec", "c")
root_ns.declare_namespace("", "d")

a_ns.name = "a"
a_ns.full_name = "a"
a_ns.declare_namespace("", "a::b")
a_ns.put_in_graph

b_ns.name = "b"
b_ns.full_name = "a::b"
b_ns.declare_class("classa_b_bar", "", "")
b_ns.put_in_graph

c_ns.model_id = "namespacec"
c_ns.name = "c"
c_ns.full_name = "c"
c_ns.put_in_graph

d_ns.model_id = "namespaced"
d_ns.name = "d"
d_ns.full_name = "d"
d_ns.put_in_graph

print "---===WITHOUT GLOBALS===---"
graph.put_edges
graph.debug buffer
print buffer

print "---===WITH GLOBALS===---"
buffer.clear
graph.add_global_modules
graph.put_edges
graph.debug buffer
print buffer
