# Copyright (c) 2012-2013 Hal Brodigan

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

CHRUBY_VERSION="0.3.9"
RUBIES=()

for dir in "$PREFIX/opt/rubies" "$HOME/.rubies"; do
	[[ -d "$dir" && -n "$(ls -A "$dir")" ]] && RUBIES+=("$dir"/*)
done
unset dir

function chruby_reset()
{
	[[ -z "$RUBY_ROOT" ]] && return

	PATH=":$PATH:"; PATH="${PATH//:$RUBY_ROOT\/bin:/:}"

	if (( $UID != 0 )); then
		[[ -n "$GEM_HOME" ]] && PATH="${PATH//:$GEM_HOME\/bin:/:}"
		[[ -n "$GEM_ROOT" ]] && PATH="${PATH//:$GEM_ROOT\/bin:/:}"

		GEM_PATH=":$GEM_PATH:"
		[[ -n "$GEM_HOME" ]] && GEM_PATH="${GEM_PATH//:$GEM_HOME:/:}"
		[[ -n "$GEM_ROOT" ]] && GEM_PATH="${GEM_PATH//:$GEM_ROOT:/:}"
		GEM_PATH="${GEM_PATH#:}"; GEM_PATH="${GEM_PATH%:}"
		unset GEM_ROOT GEM_HOME
		[[ -z "$GEM_PATH" ]] && unset GEM_PATH
	fi

	PATH="${PATH#:}"; PATH="${PATH%:}"
	unset RUBY_ROOT RUBY_ENGINE RUBY_VERSION RUBYOPT
	hash -r
}

function chruby_use()
{
	if [[ ! -x "$1/bin/ruby" ]]; then
		echo "chruby: $1/bin/ruby not executable" >&2
		return 1
	fi

	[[ -n "$RUBY_ROOT" ]] && chruby_reset

	export RUBY_ROOT="$1"
	export RUBYOPT="$2"
	export PATH="$RUBY_ROOT/bin:$PATH"

	eval "$("$RUBY_ROOT/bin/ruby" - <<EOF
puts "export RUBY_ENGINE=#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'};"
puts "export RUBY_VERSION=#{RUBY_VERSION};"
begin; require 'rubygems'; puts "export GEM_ROOT=#{Gem.default_dir.inspect};"; rescue LoadError; end
EOF
)"

	if (( $UID != 0 )); then
		export GEM_HOME="$HOME/.gem/$RUBY_ENGINE/$RUBY_VERSION"
		export GEM_PATH="$GEM_HOME${GEM_ROOT:+:$GEM_ROOT}${GEM_PATH:+:$GEM_PATH}"
		export PATH="$GEM_HOME/bin${GEM_ROOT:+:$GEM_ROOT/bin}:$PATH"
	fi
}

function chruby()
{
	case "$1" in
		-h|--help)
			echo "usage: chruby [RUBY|VERSION|system] [RUBYOPT...]"
			;;
		-V|--version)
			echo "chruby: $CHRUBY_VERSION"
			;;
		"")
			local dir star
			for dir in "${RUBIES[@]}"; do
				dir="${dir%%/}"
				if [[ "$dir" == "$RUBY_ROOT" ]]; then star="*"
				else                                  star=" "
				fi

				echo " $star ${dir##*/}"
			done
			;;
		system) chruby_reset ;;
		*)
			local dir match
			for dir in "${RUBIES[@]}"; do
				dir="${dir%%/}"
				case "${dir##*/}" in
					"$1")	match="$dir" && break ;;
					*"$1"*)	match="$dir" ;;
				esac
			done

			if [[ -z "$match" ]]; then
				echo "chruby: unknown Ruby: $1" >&2
				return 1
			fi

			shift
			chruby_use "$match" "$*"
			;;
	esac
}
