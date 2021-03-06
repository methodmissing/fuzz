#!/usr/bin/env ruby
# vim: noet

$spec = "../../spec/token.rb"


module Fuzz
	module Token
		class Base
      ENCODING = "utf-8".freeze
      BLANK_STRING = ''.freeze
      UNDERSCORE = '_'.freeze

			def self.defined_types
				subclasses = []
				base = Fuzz::Token::Base
				ObjectSpace.each_object(Class) do |klass|
					if klass.ancestors.include?(base) and klass != base
						subclasses.push(klass)
					end
				end
			end
			
			
			attr_reader :title, :options
			
			def initialize(title=nil, options={})
				@title = title
				
				# if this token class has predefined
				# options, then store them overridden
				# by the given options
				if self.class.const_defined?(:Options)
					@options = self.class.const_get(:Options).merge(options)
				
				# otherwise, just store the
				# options as they were given
				else
					@options = options
				end

				# this class serves no purpose
				# by itself, because it will
				# never match anything.
				if self.class == Fuzz::Token::Base
					raise RuntimeError, "Fuzz::Token cannot be " +\
					"instantiated directly. Use a subclass instead"
				end
			end
			
			# Returns an identifier for this token based upon
			# the name, which is safe to use as a Hash key, by
			# stripping non-alphanumerics and converting spaces
			# to underscores. (Technically, any string (or Object)
			# is safe to use as a Hash key, but it's ugly, and
			# this is not.)
			# 
			#   SampleToken.new("Age of Child").name => :age_of_child
			#   SampleToken.new("It's a Weird Token Name!").name => :its_a_weird_token_name
			#
			def name
				@name ||= title.downcase.gsub(/\s+/, UNDERSCORE).gsub(/[^a-z0-9_]/i, BLANK_STRING).to_sym
			end


			# Returns the pattern (a Regex) matched by this
			# class, or raises RuntimeError if none is available.
			def pattern
				raise RuntimeError.new("#{self.class} has no pattern")\
					unless self.class.const_defined?(:Pattern)

				# ruby doesn't consider the class body of
				# subclasses to be in this scope. weird.
				pat = self.class.const_get(:Pattern)

				# If the pattern contains no captures, wrap
				# it in parenthesis to capture the whole
				# thing. This is vanity, so we can omit
				# the parenthesis from the Patterns of
				# simple Token subclasses.
				pat = "(#{pat})"\
					unless pat.index "("

				# build the patten wedged between delimiters,
				# to avoid matching within other token bodies
				del = "(#{Fuzz::Delimiter})"
				
				# wrap the pattern in delimiters,
				# to avoid matching within fields
				rx = del + pat + del
				
				# if this token must be the first or last in a string
				# (to aid loose tokens like Letters or Numbers),  patch
				# the regex. we leave the delimiters, to catch any
				# leading or trailing junk characters
				rx = '\A' + rx if @options[:first]
				rx = rx +'\Z'  if @options[:last]
					
				# return a regex object to match
				# incoming strings against
				Regexp.compile(rx.force_encoding(ENCODING), Regexp::IGNORECASE )
			end

      alias :real_pattern :pattern
      def pattern
        @pattern ||= real_pattern
      end

			def match(str)
				# perform the initial match by comparing
				# the string with this classes regex, and
				# abort if nothing matches
				md = str.match(pattern)
				return nil unless md
				
				# wrap the return value in Fuzz::Match, to
				# provide much more useful access than the
				# raw MatchData from the regex
				fm = Fuzz::Match.new(self, md)
				
				# before returning, validate the match,
				# to give the token the opportunity to
				# reject it based on more semantic
				# constraints (number range, etc)
				accept?(fm) ? fm : nil
			end
			
			
			# Returns the "normalized" result of the given
			# strings captured by this class's Pattern by
			# the _match_ method, excluding delimiters.
			# 
			# This method provides a boring default behavior,
			# which is to return nil for no captures, String
			# for a single capture, or Array for multiple.
			# Most subclasses should overload this, to return a
			# more semantic value (like a DateTime, Weight, etc)
			#
			#   t = SampleToken.new("My Token")
			#   t.normalize("beta", "gamma") => ["beta", "gamma"]
			#   t.normalize("alpha") => "alpha"
			#   t.normalize => nil
			#
			def normalize(*captures)
				if captures.length == 0
					return nil
				
				elsif captures.length == 1
					return captures[0]
				
				# default: return as-is, and leave for
				# the receiver to deal with. tokens doing
				# this should probably overload this method.
				else; return captures; end
			end
			
			
			# Returns the "humanized" version of the same value
			# output by the _normalize_ method, for a friendlier
			# way to present the value to users.
			#
			# As default, this method just calls _to_s_ on the
			# output of the _normalize_ method, but should be
			# overridden by most tokens.
			def humanize(normalized)
				normalized.to_s
			end
			
			
			# Returns a boolean value which indicates whether the
			# Fuzz::Match object given is acceptable. This allows
			# subclasses to impose stricter rules on matches, such
			# as checking a username exists, matching numbers only
			# within a predefined range, etc.
			def accept?(fuzz_match)
				true
			end


			def extract(str)

				# attempt to match the token against _str_
				# via Base#match, and abort it it failed
				fm = match(str)
				return nil unless fm
				m = fm.match_data

				# return the Fuzz::Match and _str_ with the matched
				# token replace by Fuzz::Replacement, to continue parsing
				join = ((!m.pre_match.empty? && !m.post_match.empty?) ? Fuzz::Replacement : BLANK_STRING)
				[fm, "#{m.pre_match}#{join}#{m.post_match}"]
			end


			def extract!(str)
        str.force_encoding(ENCODING)
				# call Token#extract first,
				# and abort it if failed
				ext = extract(str)
				return nil unless ext

				# update the argument (the BANG warns
				# of the danger of this operation...),
				# and return the Fuzz::Match
				str.replace(ext[1])
				ext[0]
			end
		end
	end
end
