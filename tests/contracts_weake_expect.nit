# This file is part of NIT ( http://www.nitlanguage.org ).
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

# Test the weakening of an expect contract

class MyClass

	fun foo(x: Int)
	is
		expect(x == 1)
	do
		print "Execution of `MyClass.foo` with x equal {x}"
	end
end

class MySubClass
	super MyClass

	redef fun foo(x: Int)
	is
		expect(x == 2)
	do
		print "Execution of `MySubClass.foo` with x equal {x}"
	end
end

var first = new MyClass
first.foo(1)
var second = new MySubClass
second.foo(1)
second.foo(2)
second.foo(3)
