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

module model_api

import web_base
import highlight

# Specific handler for nitweb API.
abstract class APIHandler
	super ModelHandler

	# The JSON API does not filter anything by default.
	#
	# So we can cache the model view.
	var view: ModelView is lazy do
		var view = new ModelView(model)
		view.min_visibility = private_visibility
		view.include_fictive = true
		view.include_empty_doc = true
		view.include_attribute = true
		view.include_test_suite = true
		return view
	end

	# Try to load the mentity from uri with `/:id`.
	#
	# Send 400 if `:id` is null.
	# Send 404 if no entity is found.
	# Return null in both cases.
	fun mentity_from_uri(req: HttpRequest, res: HttpResponse): nullable MEntity do
		var id = req.param("id")
		if id == null then
			res.error 400
			return null
		end
		var mentity = find_mentity(view, id)
		if mentity == null then
			res.error 404
		end
		return mentity
	end
end

# Group all api handlers in one router.
class APIRouter
	super Router

	# Model to pass to handlers.
	var model: Model

	# ModelBuilder to pass to handlers.
	var modelbuilder: ModelBuilder

	# Mainmodule to pass to handlers.
	var mainmodule: MModule

	init do
		use("/list", new APIList(model, mainmodule))
		use("/search", new APISearch(model, mainmodule))
		use("/random", new APIRandom(model, mainmodule))
	end
end

# Search mentities from a query string.
#
# Example: `GET /search?q=Arr`
class APISearch
	super APIHandler

	redef fun get(req, res) do
		var q = req.string_arg("q")
		if q == null then
			res.error 400
			return
		end
		var arr = new JsonArray
		for mentity in view.mentities do
			if mentity.name.has_prefix(q) then arr.add mentity
		end
		res.json arr
	end
end

# List all mentities.
#
# MEntities can be filtered on their kind using the `k` parameter.
# Allowed kinds are `package`, `group`, `module`, `class`, `classdef`, `property`, `propdef`.
#
# List size can be limited with the `n` parameter.
#
# Example: `GET /list?k=module?n=10`
class APIList
	super APIHandler

	# List mentities depending on the `k` kind parameter.
	fun list_mentities(req: HttpRequest): Array[MEntity] do
		var k = req.string_arg("k")
		var mentities = new Array[MEntity]
		if k == "package" then
			for mentity in view.mpackages do mentities.add mentity
		else if k == "group" then
			for mentity in view.mgroups do mentities.add mentity
		else if k == "module" then
			for mentity in view.mmodules do mentities.add mentity
		else if k == "class" then
			for mentity in view.mclasses do mentities.add mentity
		else if k == "classdef" then
			for mentity in view.mclassdefs do mentities.add mentity
		else if k == "property" then
			for mentity in view.mproperties do mentities.add mentity
		else if k == "propdef" then
			for mentity in view.mpropdefs do mentities.add mentity
		else
			for mentity in view.mentities do mentities.add mentity
		end
		return mentities
	end

	# Limit mentities depending on the `n` parameter.
	fun limit_mentities(req: HttpRequest, mentities: Array[MEntity]): Array[MEntity] do
		var n = req.int_arg("n")
		if n != null then
			return mentities.sub(0, n)
		end
		return mentities
	end

	redef fun get(req, res) do
		var mentities = list_mentities(req)
		mentities = limit_mentities(req, mentities)
		var arr = new JsonArray
		for mentity in mentities do arr.add mentity
		res.json arr
	end
end

# Return a random list of MEntities.
#
# Example: `GET /random?n=10&k=module`
class APIRandom
	super APIList

	# Randomize mentities order.
	fun randomize_mentities(req: HttpRequest, mentities: Array[MEntity]): Array[MEntity] do
		var res = mentities.to_a
		res.shuffle
		return res
	end

	redef fun get(req, res) do
		var mentities = list_mentities(req)
		mentities = limit_mentities(req, mentities)
		mentities = randomize_mentities(req, mentities)
		var arr = new JsonArray
		for mentity in mentities do arr.add mentity
		res.json arr
	end
end
