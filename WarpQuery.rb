#!/usr/bin/ruby -Ku
# -*- coding: utf-8 -*-

require 'pp'

# Warp Query Parser for Ruby
#
# @author Kyoji Osada at WARP-WG
# @copyright 2017 WARP-WG
# @license Apache-2.0
# @version 0.1.0
# @update 2018-04:23 UTC
class WarpQuery

	# constructor
	#
	# @param [Void]
	# @return [Void]
	def initialize
		@operators = [';', '&', '|', '^', '==', '!=', '><', '<<', '>>', '<>', '.ij.', '.lj.', '.rj.', '.cj.', '>=', '<=', '>', '<', '?=', ':=', '.ge.', '.le.', '.gt.', '.lt.', '%3E%3E', '%3C%3C', '%3E%3C', '%3C%3E', '%3E=', '%3C=', '%3E', '%3C', '=']
		@central_operators = ['==', '!=', '><', '<<', '>>', '<>', '>=', '<=', '>', '<', '?=', ':=', '=']
		@compare_operators = ['==', '!=', '>=', '<=', '>', '<', '?=']
		@logical_operators = ['&', '|', '^']
		@join_operators = ['><', '<<', '>>', '<>']
	end


	# decode Pion Query to Pion Object
	#
	# @param [String] Pion Query
	# @return [Array] Pion Object
	def decode(_query)

		# check Empty Query String
		if _query.blank? then
			return []
		end

		# form Query String for Parsing
		query_string = '&' + _query + ';'

		queries = []
		# for Proxy Parameters
		while true
			## check Curly Brackets
			if ! matches = query_string.match(/\A(?:|(.*?)([&|]))({.*?[^%]})(.*)\z/) then
				break
			end

			## to Semantics Variables
			all_match = matches[0]
			pre_match = matches[1]
			process = matches[2]
			proxy = matches[3]
			post_match = matches[4]

			## delete Curly Bracket
			proxy = proxy.sub(/\A{(.*)}\z/, '\1');

			## for Virtical Proxy Module
			if 0 === proxy.index('/') then
				location = 'self'
			## for Horizontal Proxy Module
			elsif matches = proxy.match(/\A(http(?:|s):\/\/.+?)\//i) then
				location = matches[1]
				proxy = proxy.gsub(/#{location}/, '')
			## for Others
			else
				raise 'The Proxy Parameters are having unknown URL scheme: ' + proxy
			end

			### to Objects
			queries << [
				process,
				location,
				'{}',
				proxy,
			]

			## reform Query String for Parsing
			query_string = pre_match + post_match
		end

		# escape Operators
		esc_operators = []
		@operators.each_with_index do |operator, i|
			esc_operators[i] = Regexp.escape(operator)
		end

		# form Operators Regex
		operators_regex = '\A(.*?)(' + esc_operators.join('|') + ')(.*?)\z'

		query_parts = []
		while true
			## matching Operators
			if ! matches = query_string.match(/#{operators_regex}/) then
				break;
			end

			## to Semantics Variables
			all_match = matches[0]
			operand = matches[1]
			operator = matches[2]
			post_match = matches[3]

			## from Alias Operators to Master Operators
			if operator == '.ge.' || operator == '%3E=' then
				operator = '>='
			elsif operator == '.le.' || operator == '%3C=' then
				operator = '<='
			elsif operator == '.gt.' || operator == '%3E' then
				operator = '>'
			elsif operator == '.lt.' || operator == '%3C' then
				operator = '<'
			elsif operator == '.ij.' || operator == '%3E%3C' then
				operator = '><'
			elsif operator == '.lj.' || operator == '%3C%3C' then
				operator = '<<'
			elsif operator == '.rj.' || operator == '%3E%3E' then
				operator = '>>'
			elsif operator == '.cj.' || operator == '%3C%3E' then
				operator = '<>'
			end

			## map to Query Parts
			if operand != '' then
				query_parts << operand
			end
			query_parts << operator

			## from Post Matcher to Query String
			query_string = post_match

		end

		# check Data-Type-Head Module
		data_type_id = query_parts.index('data-type')
		data_type = nil
		if (nil != data_type_id) && (query_parts[data_type_id + 1] == ':=') then
			data_type = query_parts[data_type_id + 2]
		end

		# map to Queries
		query_parts.each_with_index do |query_part, i|
			## not Central Operators
			if ! @central_operators.include?(query_part) then
				next
			end

			## to Semantics Variables
			logical_operator = query_parts[i - 2];
			left_operand = query_parts[i - 1];
			central_operator = query_part;
			right_operand = query_parts[i + 1];

			## for Data-Type-Head Module
			### for Strict Data Type
			if data_type == 'true' then
				regex = /\A%(?:22|27|["\'])(.*?)%(?:22|27|["\'])\z/
				### delete first and last quotes for String Data Type
				if right_operand.match(regex) then
					right_operand = right_operand.sub(regex, '\1')
				### for Not String Type
				else
					#### to Boolean
					if right_operand == 'true' then
						right_operand = true
					#### to Boolean
					elsif right_operand == 'false' then
						right_operand = false
					#### to Null
					elsif right_operand == 'null' then
						right_operand = nil
					#### to Integer
					elsif right_operand.match(/\A\d\z|\A[1-9]\d+\z/) then
						right_operand = right_operand.to_i
					#### to Float
					elsif right_operand.match(/\A\d\.\d+\z|\A[1-9]\d+\.\d+\z/) then
						right_operand = right_operand.to_f
					end
				end
			end

			## validate Left Operand
			if @operators.include?(left_operand) then
				raise 'The parameter is having invalid left operands: ' + _query
			end

			## validate Right Operand
			### to Empty String
			if @logical_operators.include?(right_operand) || right_operand == ';' then
				right_operand = ''
			### for Double NV Operators
			elsif @central_operators.include?(right_operand) then
				raise 'The parameter is having double comparing operators: ' + _query
			end

			## map to Queries
			### for Head Parameters
			if central_operator == ':=' then
				#### validate Logical Part
				if logical_operator != '&' then
					raise 'The Head Parameters must be a “and” logical operator: ' + _query
				end
			### for Assign Parameters
			elsif central_operator == '=' then
				#### validate Logical Part
				if logical_operator != '&' then
					raise 'The Assign Parameters must be a “&” logical operator: ' + _query
				end
			### for Join Parameters
			elsif @join_operators.include?(central_operator) then
				#### validate Logical Part
				if logical_operator != '&' then
					raise 'The Join Parameters must be a “&” logical operator: ' + _query
				end
			### for Search Parameters
			elsif @compare_operators.include?(central_operator) then
				#### validate Logical Part
				if ! @logical_operators.include?(logical_operator) then
					raise 'The Search Parameters are having invalid logical operators: ' + _query
				end
			## for Others
			else
				next
			end

			#### to Queries
			queries << [
				logical_operator,
				left_operand,
				central_operator,
				right_operand,
			]
		end

		# init Searches 1st Logical Operator
		queries[0][0] = ''

		# return
		return queries
	end


	# encode Pion Object to Pion Query
	#
	# @param [Array] Pion Object
	# @return [String] Pion Query
	def encode(_object)
		# check Empty Object
		# Notice: Check
		if _object.blank? then
			return ''
		end

		# drop First Logical Operator
		_object[0][0] = ''

		# check Data Type Flag
		data_type_flag = false
		_object.each_with_index do |list, i|
			list.each_with_index do |value, j|
				## for Not Data Type
				if value != 'data-type' then
					next
				end

				## for Data Type
				# Notice: Processing must be not breaked because there ware multiple the value of “data-type”.
				if _object[i][j + 2] == true then
					data_type_flag = true
				end
			end
		end

		# to Query String
		query = ''
		_object.each_with_index do |list, i|

			if list[2] == '{}' then
				list[1] = list[1] == 'self' ? '' : list[1]
				list[1] = '{' + list[1]
				list[2] = ''
				list[3] = list[3] + '}'
			end

			list.each_with_index do |value, j|
				## for Stric Data Type
				if data_type_flag then
					### for Value of Strint Type
					if j == 3 then
						if value.is_a?(String) then
							value = "'" + value + "'"
						end
					end
				end

				## for Value of Boolean and Null Type
				if j == 3 then
					if value == true then
						value = 'true'
					elsif value == false then
						value = 'false'
					elsif value == nil then
						value = 'null'
					end
				end

				### to Query String
				query += value
			end
		end

		# return
		return query
	end

end
