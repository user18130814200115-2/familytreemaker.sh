#!/bin/sh

#MIT License
#
#Copyright (c) 2021 user18130814200115-2
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

file="$1"

GetArguments(){
    sed "$file" -e 's/[][ ]//g' -e 's/(.*)//g' | tr '\n' ';'
    sed "$file" -e 's/^    //g'\
	-e 's/[][]//g'\
	-e 's/(F/[style=filled;fillcolor=bisque;/'\
	-e 's/(M/[style=filled;fillcolor=azure2;/'\
	-e 's/,/label=/g' -e 's/;)/;label=)/' |\
	sed -E 's/^([^[]*)(.*)label=(.*)\)/\1\2label=\1\\n\3]/g' |\
	sed -E 's/label=(.*)label=.*\\n([^]]*)]/label=\2\\n\1]/' |\
	sed -e 's/;)/]/' -e 's/[^]]$/&[]/' -e :a -e '/ .*\[/s/ //;ta' |\
	sed -E 's/label=([^]]*)/label=\"\1\"/'
}

GetHouseholds() {
    # We do a multi-line grep (with pcregrep) on the file
    # This will output all member of a household (parents and children) followed by the string [HOUSEHOLD]
    rawgrep=$(pcregrep -Mo "^[A-z].*\n^[A-z].*\n(^    .*\n)*" $file)
    households=$(printf "%s\n\n" "$rawgrep" | sed 's/[][]//g' | sed 's/^$/[HOUSEHOLD]/g' | sed 's/([^)]*)//g' | sed 's/ //g')
    regex=$(printf "%s\n\n" "$rawgrep" | sed 's/^$/[HOUSEHOLD]/g' | grep "^    \\|\[HOUSEHOLD\]" | sed 's/[ ]*([^)]*)//' | sed 's/[A-z]$/&\\\\|/' | sed 's/^    /\^/' | tr -d "\n" | sed 's/\[HOUSEHOLD\]\\\\|/\n/g' | sed 's/\\\\|$//')
    index=0
    printf "%s;" $households | sed 's/\[HOUSEHOLD\]/\n/g' | { while read household; do
	lineindex=$((index +1))
	HandleHousehold "${household#;}" "$index" "$(printf "%s" "$regex" | sed "${lineindex}q;d")"
	index=$((index + 1))
    done
    wait
    }
}

HandleHousehold() {
    # Parents
    h=h
    div=sub
    parents="{rank=same;\
$(printf "%s\n" "$1" |\
cut -d ';' -f '1,2' --output-delimiter " -> h$2 -> ")\
[weight=10]}\nh$2[shape=point;width=0;height=0]\n"
    # Get The children
    children=$(printf "%s\n" "$1" | cut -d ";" -f "3-" --output-delimiter "\n")
    # Loop over the children
    printf "%b" $children | { index=0; while read child; do
	#Sub-Household-Settings
	shs="$shs$h$2$div$index[shape=point;width=0;height=0]\n"
	#Edges between Sub-Households
	sh="$sh$h$2$div$index -> "
	#Edges from Sub-Household to Corresponding Child
	sh2c="$sh2c$h$2$div$index -> $child[weight=15]\n"
	index=$((index + 1))
    done
    # Calculate to which sub-household we connect the parent's household 
    [ -z "$children" ] || h2sh="h$2 -> $h$2$div$((index /2))\n"
    # Check if the kids have partners (to determine weight)
    [ $(printf "grep -c \"%s\" $file\n" "$3" | sh) -eq 0 ] && weight=1 || weight=-1
    # Make sure all the sub-households are vertically aligned AND that there is not trailing ->
    [ $index -gt 1 ] && sh="{rank=same;${sh% -> }[weight=$weight]}\n" || sh=""
    # Now print the whole thing
    #This done instead of printing at each step to allow for parallel processing
    printf "$parents$shs$sh$sh2c$h2sh"
    }
}
GetFloating() {
    raw=$(tail -n1 "$file" | grep "^#")
    printf "\n${raw#\#}"
}
# Start the Graph
one=$(GetArguments &)
two=$(GetHouseholds &)
three=$(GetFloating)
wait
# Print the graph
printf "digraph {node [shape=box];edge [dir=none];rankdir=LR;constraint=false\n%s}\n" "$one$two$three"
