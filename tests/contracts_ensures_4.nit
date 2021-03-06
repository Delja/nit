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

# Check the result with the super call

class MyClass
	fun foo(x: Int): Bool
	is
		ensure(x > 0, result)
	do
		return true
	end
end

class MySubClass
	super MyClass

	redef fun foo(x: Int)
	is
		ensure(not result)
	do
		return super
	end
end

var first = new MyClass
first.foo(1)
var second = new MySubClass
second.foo(2) #Fail
